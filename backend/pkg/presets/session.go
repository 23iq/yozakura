package presets

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"time"

	"yozakura/backend/pkg/catalog"
)

// Session kinds. A trial applies a preset for a while and reverts unless
// kept; an edit applies a user preset so every settings page edits it live,
// then saves the live config back into the preset and restores the look
// the user had before.
const (
	TrySession  = "try"
	EditSession = "edit"
)

// Session is an in-progress trial or edit. The live config at its start
// is kept in a bundle next to it.
type Session struct {
	Kind       string    `json:"kind"`
	Preset     string    `json:"preset"`
	PrevActive string    `json:"prevActive"`
	Started    time.Time `json:"started"`
	Created    []string  `json:"created,omitempty"` // live files the preset added (removed on revert)
	// PrevColorPreset is the static color preset active before the session
	// (applying a scheme drops it; a revert brings it back).
	PrevColorPreset string `json:"prevColorPreset,omitempty"`
	// PrevParts are the part markers before the session (nil: older record).
	PrevParts *SetRef `json:"prevParts,omitempty"`
	// Part is the kind of the previewed part ("" when Preset is a set).
	Part string `json:"part,omitempty"`
}

func (m *Manager) sessionFile(kind string) string {
	return filepath.Join(m.StateDir, "presets", kind+".json")
}

func (m *Manager) backupFile(kind string) string {
	return filepath.Join(m.StateDir, "presets", kind+"-backup.json")
}

// Session returns the session of a kind, nil when none is running.
func (m *Manager) Session(kind string) (*Session, error) {
	if m.StateDir == "" {
		return nil, nil
	}
	data, err := os.ReadFile(m.sessionFile(kind))
	if os.IsNotExist(err) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	var s Session
	if err := json.Unmarshal(data, &s); err != nil {
		return nil, fmt.Errorf("%s: %w", m.sessionFile(kind), err)
	}
	return &s, nil
}

func (m *Manager) writeSession(s *Session) error {
	data, _ := json.MarshalIndent(s, "", "  ")
	return writeAtomic(m.sessionFile(s.Kind), append(data, '\n'))
}

// Begin starts a trial or an edit of a preset: the live config is backed
// up, then the preset is applied. Only user presets can be edited.
func (m *Manager) Begin(kind, name string) (*Session, []catalog.Problem, error) {
	unlock, err := m.lock()
	if err != nil {
		return nil, nil, err
	}
	defer unlock()
	return m.begin(kind, name)
}

func (m *Manager) begin(kind, name string) (*Session, []catalog.Problem, error) {
	if kind != TrySession && kind != EditSession {
		return nil, nil, fmt.Errorf("unknown session kind %q", kind)
	}
	if m.StateDir == "" {
		return nil, nil, fmt.Errorf("no state directory for preset sessions")
	}
	// A preview is transient (a hover, or left over by a crash): starting a
	// trial or an edit puts the look from before it back and goes on.
	if s, _ := m.Session(PreviewSession); s != nil {
		if err := m.revert(s); err != nil {
			return nil, nil, fmt.Errorf("ending the preview first: %w", err)
		}
		m.dropSession(PreviewSession)
	}
	for _, k := range []string{TrySession, EditSession} {
		if s, _ := m.Session(k); s != nil {
			return nil, nil, fmt.Errorf("a preset %s of %q is in progress; finish it first", k, s.Preset)
		}
	}
	var p Preset
	var err error
	if kind == EditSession {
		p, err = m.findUser(name)
	} else {
		p, err = m.Find(name)
	}
	if err != nil {
		return nil, nil, err
	}
	s := m.newSession(kind, p.Name)
	for _, d := range p.Domains {
		if d == WallpaperDomain || !m.Cat.HasDomain(d) {
			continue
		}
		if _, err := os.Stat(m.Store.File(d)); os.IsNotExist(err) {
			s.Created = append(s.Created, d)
		}
	}
	if _, err := m.Export(Current, m.backupFile(kind)); err != nil {
		return nil, nil, fmt.Errorf("backing up the live config: %w", err)
	}
	if err := m.backupApplied(kind); err != nil {
		return nil, nil, err
	}
	if err := m.writeSession(s); err != nil {
		return nil, nil, err
	}
	_, problems, err := m.apply(p.Name)
	if err != nil {
		_ = m.revert(s)
		_ = os.Remove(m.backupFile(kind))
		_ = os.Remove(m.sessionFile(kind))
		return nil, problems, err
	}
	return s, problems, nil
}

// End finishes a session. keep leaves the preset applied; otherwise the
// live config from before the session comes back. For an edit, save first
// stores the live config into the preset (the files it holds).
func (m *Manager) End(kind string, keep, save bool) (*Session, error) {
	unlock, err := m.lock()
	if err != nil {
		return nil, err
	}
	defer unlock()
	return m.end(kind, keep, save)
}

func (m *Manager) end(kind string, keep, save bool) (*Session, error) {
	s, err := m.Session(kind)
	if err != nil {
		return nil, err
	}
	if s == nil {
		return nil, fmt.Errorf("no preset %s in progress", kind)
	}
	if save && kind == EditSession {
		extra, err := m.editedDomains(s)
		if err != nil {
			return s, fmt.Errorf("saving into %q: %w", s.Preset, err)
		}
		if _, err := m.update(s.Preset, extra); err != nil {
			return s, fmt.Errorf("saving into %q: %w", s.Preset, err)
		}
	}
	if keep {
		if err := m.setActive(s.Preset); err != nil {
			return s, err
		}
	} else if err := m.revert(s); err != nil {
		return s, err
	}
	_ = os.Remove(m.backupFile(kind))
	_ = os.Remove(m.appliedBackup(kind))
	return s, os.Remove(m.sessionFile(kind))
}

// editedDomains lists what an edit session saves: the domains the preset
// holds plus any other one whose live config differs from the backup (a
// setting edited on a page the preset has no file for, like the desktop).
func (m *Manager) editedDomains(s *Session) ([]string, error) {
	p, err := m.findUser(s.Preset)
	if err != nil {
		return nil, err
	}
	domains := append([]string{}, p.Domains...)
	live, err := m.Documents(Current)
	if err != nil {
		return nil, err
	}
	backup, err := m.Documents(m.backupFile(s.Kind))
	if err != nil {
		return nil, fmt.Errorf("reading the backup: %w", err)
	}
	for d := range live {
		if contains(domains, d) {
			continue
		}
		if _, had := backup[d]; !had || len(m.compareDocs(live, backup, []string{d})) > 0 {
			domains = append(domains, d)
		}
	}
	sort.Strings(domains)
	return domains, nil
}

// revert restores the live config backed up when the session began.
func (m *Manager) revert(s *Session) error {
	raw, err := m.rawDocuments(m.backupFile(s.Kind))
	if err != nil {
		return fmt.Errorf("reading the backup: %w", err)
	}
	if _, err := m.applyFiles(raw, false); err != nil {
		return err
	}
	for _, d := range s.Created {
		if _, ok := raw[d]; !ok {
			_ = os.Remove(m.Store.File(d))
		}
	}
	if err := m.restoreApplied(s.Kind); err != nil {
		return err
	}
	if err := m.restoreColorPreset(s.PrevColorPreset); err != nil {
		return err
	}
	if s.PrevParts != nil {
		if err := m.setCurrentParts(*s.PrevParts); err != nil {
			return err
		}
	}
	return m.setActive(s.PrevActive)
}
