package presets

import (
	"fmt"
	"os"
	"time"
)

// PreviewSession is a live preview (the preset switcher's hover): the
// first preview backs up the live config, later ones apply on top of it,
// and Revert brings the backed-up look back. A real Apply ends it.
const PreviewSession = "preview"

// previewTarget is what a preview applies: a set or a part.
type previewTarget struct {
	name    string
	part    string // part kind; "" for a set
	domains []string
	apply   func() error
}

// Preview applies a preset for a look, keeping the config from before the
// first preview of a chain so Revert can restore it.
func (m *Manager) Preview(name string) (*Session, error) {
	return m.preview(func() (previewTarget, error) {
		p, err := m.Find(name)
		return previewTarget{name: p.Name, domains: p.Domains, apply: func() error {
			_, _, err := m.apply(p.Name)
			return err
		}}, err
	})
}

// preview runs a preview step (sets and parts share the session).
func (m *Manager) preview(resolve func() (previewTarget, error)) (*Session, error) {
	unlock, err := m.lock()
	if err != nil {
		return nil, err
	}
	defer unlock()
	if m.StateDir == "" {
		return nil, fmt.Errorf("no state directory for preset previews")
	}
	t, err := resolve()
	if err != nil {
		return nil, err
	}
	s, err := m.Session(PreviewSession)
	if err != nil {
		return nil, err
	}
	first := s == nil
	if first {
		for _, k := range []string{TrySession, EditSession} {
			if other, _ := m.Session(k); other != nil {
				return nil, fmt.Errorf("a preset %s of %q is in progress; finish it first", k, other.Preset)
			}
		}
		s = m.newSession(PreviewSession, "")
		if _, err := m.Export(Current, m.backupFile(PreviewSession)); err != nil {
			return nil, fmt.Errorf("backing up the live config: %w", err)
		}
	}
	s.Preset, s.Part = t.name, t.part
	for _, d := range t.domains {
		if d == WallpaperDomain || !m.Cat.HasDomain(d) || contains(s.Created, d) {
			continue
		}
		if _, err := os.Stat(m.Store.File(d)); os.IsNotExist(err) {
			s.Created = append(s.Created, d)
		}
	}
	if err := m.writeSession(s); err != nil {
		return nil, err
	}
	if err := t.apply(); err != nil {
		if first {
			_ = m.revert(s)
			m.dropSession(PreviewSession)
		}
		return nil, err
	}
	return s, nil
}

// newSession starts a session record with what a revert restores.
func (m *Manager) newSession(kind, preset string) *Session {
	parts := m.CurrentParts()
	return &Session{Kind: kind, Preset: preset, PrevActive: m.Active(), Started: time.Now(),
		PrevColorPreset: m.colorPreset(), PrevParts: &parts}
}

// Revert ends a preview and restores the look from before it. It reports
// whether a preview was running; none is not an error.
func (m *Manager) Revert() (bool, error) {
	unlock, err := m.lock()
	if err != nil {
		return false, err
	}
	defer unlock()
	s, err := m.Session(PreviewSession)
	if err != nil || s == nil {
		return false, err
	}
	if err := m.revert(s); err != nil {
		return true, err
	}
	m.dropSession(PreviewSession)
	return true, nil
}

func (m *Manager) dropSession(kind string) {
	_ = os.Remove(m.backupFile(kind))
	_ = os.Remove(m.sessionFile(kind))
}
