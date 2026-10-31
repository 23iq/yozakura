package presets

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"
)

// Status is the active preset against the live config: which settings the
// user changed since it was applied (what "Save to current preset" stores).
type Status struct {
	Active   string `json:"active"` // "" when no preset is active
	Official bool   `json:"official"`
	Owned    bool   `json:"owned"` // a user preset: Save updates it in place
	// Changes are the keys whose live value (A) differs from the preset (B).
	Changed int    `json:"changed"`
	Changes []Diff `json:"changes"`
	// Session names a try/edit/preview in progress (the live config is
	// then not the user's: nothing is saved).
	Session string `json:"session,omitempty"`
}

// Status compares the live config with the active preset over the domains
// the preset holds: every key for a whole snapshot, only the keys it names
// for a partial one. Followed and machine-local keys never count.
func (m *Manager) Status() (Status, error) {
	st := Status{Changes: []Diff{}}
	for _, k := range []string{TrySession, EditSession, PreviewSession} {
		if s, _ := m.Session(k); s != nil {
			st.Session = k
			break
		}
	}
	name := m.Active()
	if name == "" {
		return st, nil
	}
	p, err := m.Find(name)
	if err != nil {
		return st, nil
	}
	st.Active, st.Official, st.Owned = p.Name, p.Official, !p.Official
	changes, err := m.changesAgainst(p)
	if err != nil {
		return st, err
	}
	st.Changes, st.Changed = changes, len(changes)
	return st, nil
}

func (m *Manager) changesAgainst(p Preset) ([]Diff, error) {
	raw, err := m.dirFiles(p.Path)
	if err != nil {
		return nil, err
	}
	presetDocs := map[string]any{}
	for d, data := range raw {
		if !m.knownDomain(d) {
			continue
		}
		var v any
		if err := json.Unmarshal(data, &v); err != nil {
			return nil, fmt.Errorf("%s/%s.json: %w", p.Path, d, err)
		}
		presetDocs[d] = v
	}
	live, err := m.Documents(Current)
	if err != nil {
		return nil, err
	}
	var domains []string
	for d := range presetDocs {
		if _, ok := live[d]; d == WallpaperDomain && !ok {
			continue // no live scheme file: nothing to compare
		}
		domains = append(domains, d)
	}
	sort.Strings(domains)
	whole := m.wholeSnapshot(p)
	defined := m.definedKeys(raw, p.Follows)
	followed := map[string]bool{}
	for _, f := range p.Follows {
		followed[f] = true
	}
	out := []Diff{}
	for _, diff := range m.compareDocs(live, presetDocs, domains) {
		parts := strings.SplitN(diff.Key, ".", 3)
		if len(parts) < 2 || followed[parts[0]+"."+parts[1]] {
			continue
		}
		if !whole && parts[0] != WallpaperDomain && !defined[parts[0]][parts[1]] {
			continue
		}
		out = append(out, diff)
	}
	return out, nil
}

// SaveCurrent stores the live config into the active user preset (a whole
// snapshot takes its domains whole, a partial one only the keys it names)
// and returns an id for UndoSave. Built-in presets are read-only.
func (m *Manager) SaveCurrent() (Preset, string, error) {
	unlock, err := m.lock()
	if err != nil {
		return Preset{}, "", err
	}
	defer unlock()
	st, err := m.Status()
	if err != nil {
		return Preset{}, "", err
	}
	switch {
	case st.Session != "":
		return Preset{}, "", fmt.Errorf("a preset %s is in progress; finish it first", st.Session)
	case st.Active == "":
		return Preset{}, "", fmt.Errorf("no preset is active; save the look as a new preset")
	case st.Official:
		return Preset{}, "", fmt.Errorf("%q is a built-in preset and read-only; save it as a new preset", st.Active)
	}
	p, err := m.findUser(st.Active)
	if err != nil {
		return p, "", err
	}
	id, err := m.keepVersion(p)
	if err != nil {
		return p, "", fmt.Errorf("keeping the previous version: %w", err)
	}
	if m.wholeSnapshot(p) {
		p, err = m.update(p.Name, nil)
	} else {
		p, err = m.updateNamed(p)
	}
	if err != nil {
		return p, id, err
	}
	return p, id, m.notePreset(p)
}

// SaveCurrentAs saves the live config as a new user preset and makes it
// the active one (the "Save as new preset" of a built-in).
func (m *Manager) SaveCurrentAs(name string) (Preset, error) {
	p, err := m.Save(name, nil, false)
	if err != nil {
		return p, err
	}
	unlock, err := m.lock()
	if err != nil {
		return p, err
	}
	defer unlock()
	if err := m.setActive(p.Name); err != nil {
		return p, err
	}
	p.Active = true
	return p, m.notePreset(p)
}

// notePreset records the live values of a preset's keys as written by it:
// they are the preset's now (saved into it), not leftovers of the user.
func (m *Manager) notePreset(p Preset) error {
	raw, err := m.dirFiles(p.Path)
	if err != nil {
		return err
	}
	return m.noteApplied(p.Name, m.definedKeys(raw, p.Follows))
}

// updateNamed writes the live values of the keys a partial preset names
// into its own files (they are merged over its parts last).
func (m *Manager) updateNamed(p Preset) (Preset, error) {
	raw, err := m.dirFiles(p.Path)
	if err != nil {
		return p, err
	}
	for d, keys := range m.definedKeys(raw, p.Follows) {
		live := m.liveTop(d)
		if live == nil {
			continue
		}
		doc, err := decodeObject(raw[d])
		if err != nil || doc == nil {
			return p, fmt.Errorf("%s/%s.json: %v", p.Path, d, err)
		}
		for k := range keys {
			if v, ok := live[k]; ok {
				doc.Set(k, v)
			}
		}
		data, err := marshalDoc(doc)
		if err != nil {
			return p, err
		}
		if err := writeAtomic(filepath.Join(p.Path, d+".json"), data); err != nil {
			return p, err
		}
	}
	if _, ok := raw[WallpaperDomain]; ok {
		if doc := m.currentWallpaper(); doc != nil {
			if err := writeAtomic(filepath.Join(p.Path, WallpaperDomain+".json"), doc); err != nil {
				return p, err
			}
		}
	}
	return m.Find(p.Name)
}

// Saved versions: SaveCurrent keeps the preset as it was, so the settings
// toast can undo it.

const versionsKeep = 5

func (m *Manager) versionsDir() string { return filepath.Join(m.StateDir, "presets", "versions") }

// keepVersion copies a user preset directory aside and returns its id.
func (m *Manager) keepVersion(p Preset) (string, error) {
	if m.StateDir == "" {
		return "", nil
	}
	m.purgeVersions()
	id := strconv.FormatInt(time.Now().UnixNano(), 36)
	dst := filepath.Join(m.versionsDir(), id, p.Name)
	if err := copyFlatDir(p.Path, dst); err != nil {
		return "", err
	}
	return id, nil
}

// UndoSave puts back the preset version kept by SaveCurrent.
func (m *Manager) UndoSave(id string) (Preset, error) {
	unlock, err := m.lock()
	if err != nil {
		return Preset{}, err
	}
	defer unlock()
	if id == "" || filepath.Base(id) != id || strings.HasPrefix(id, ".") {
		return Preset{}, fmt.Errorf("invalid version id %q", id)
	}
	dir := filepath.Join(m.versionsDir(), id)
	entries, err := os.ReadDir(dir)
	if err != nil || len(entries) != 1 {
		return Preset{}, fmt.Errorf("no saved version %q", id)
	}
	name := entries[0].Name()
	p, err := m.findUser(name)
	if err != nil {
		return p, err
	}
	staging, err := os.MkdirTemp(m.UserDir, "."+name+".undo-")
	if err != nil {
		return p, err
	}
	defer os.RemoveAll(staging)
	if err := os.Chmod(staging, 0o755); err != nil {
		return p, err
	}
	if err := copyFlatDir(filepath.Join(dir, name), staging); err != nil {
		return p, err
	}
	if err := swapDir(staging, p.Path, true); err != nil {
		return p, err
	}
	_ = os.RemoveAll(dir)
	if p, err = m.Find(name); err != nil {
		return p, err
	}
	return p, m.notePreset(p)
}

// purgeVersions keeps the newest versionsKeep versions.
func (m *Manager) purgeVersions() {
	entries, err := os.ReadDir(m.versionsDir())
	if err != nil {
		return
	}
	var ids []string
	for _, e := range entries {
		if e.IsDir() {
			ids = append(ids, e.Name())
		}
	}
	sort.Strings(ids) // base36 nanoseconds of equal length sort by time
	for len(ids) >= versionsKeep {
		_ = os.RemoveAll(filepath.Join(m.versionsDir(), ids[0]))
		ids = ids[1:]
	}
}

// copyFlatDir copies the regular files of src into dst (created).
func copyFlatDir(src, dst string) error {
	entries, err := os.ReadDir(src)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(dst, 0o755); err != nil {
		return err
	}
	for _, e := range entries {
		if !e.Type().IsRegular() {
			continue
		}
		data, err := os.ReadFile(filepath.Join(src, e.Name()))
		if err != nil {
			return err
		}
		if err := writeAtomic(filepath.Join(dst, e.Name()), data); err != nil {
			return err
		}
	}
	return nil
}
