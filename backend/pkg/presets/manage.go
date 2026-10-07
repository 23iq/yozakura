package presets

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"
)

// trashKeep is how long deleted presets stay restorable.
const trashKeep = 7 * 24 * time.Hour

// Trashed is a deleted user preset that can be restored.
type Trashed struct {
	ID      string    `json:"id"`
	Name    string    `json:"name"`
	Deleted time.Time `json:"deleted"`
}

func (m *Manager) trashDir() string { return filepath.Join(m.StateDir, "presets", "trash") }

// Rename renames a user preset (the active marker and an edit session
// follow it).
func (m *Manager) Rename(oldName, newName string) (Preset, error) {
	unlock, lerr := m.lock()
	if lerr != nil {
		return Preset{}, lerr
	}
	defer unlock()
	p, err := m.findUser(oldName)
	if err != nil {
		return p, err
	}
	if err := m.checkNewName(newName); err != nil {
		return p, err
	}
	if newName == p.Name {
		return p, nil
	}
	dst := filepath.Join(m.UserDir, newName)
	if _, err := os.Stat(dst); err == nil && !strings.EqualFold(newName, p.Name) {
		return p, fmt.Errorf("preset %q already exists", newName)
	}
	if err := os.Rename(p.Path, dst); err != nil {
		return p, err
	}
	if m.marker() == p.Name {
		if err := m.setActive(newName); err != nil {
			return p, err
		}
	}
	if s, _ := m.Session(EditSession); s != nil && s.Preset == p.Name {
		s.Preset = newName
		if err := m.writeSession(s); err != nil {
			return p, err
		}
	}
	return m.Find(newName)
}

// Delete moves a user preset to the trash and returns its restore id.
func (m *Manager) Delete(name string) (Trashed, error) {
	unlock, lerr := m.lock()
	if lerr != nil {
		return Trashed{}, lerr
	}
	defer unlock()
	p, err := m.findUser(name)
	if err != nil {
		return Trashed{}, err
	}
	if s, _ := m.Session(EditSession); s != nil && s.Preset == p.Name {
		return Trashed{}, fmt.Errorf("preset %q is being edited; finish or cancel the edit first", p.Name)
	}
	if m.StateDir == "" {
		return Trashed{}, fmt.Errorf("no state directory for the trash")
	}
	m.purgeTrash()
	now := time.Now()
	t := Trashed{ID: strconv.FormatInt(now.UnixNano(), 36), Name: p.Name, Deleted: now}
	dst := filepath.Join(m.trashDir(), t.ID, p.Name)
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return t, err
	}
	if err := os.Rename(p.Path, dst); err != nil {
		return t, err
	}
	if m.marker() == p.Name {
		_ = m.setActive("")
	}
	return t, nil
}

// Trash lists restorable deleted presets, newest first.
func (m *Manager) Trash() []Trashed {
	entries, err := os.ReadDir(m.trashDir())
	if err != nil {
		return []Trashed{}
	}
	out := []Trashed{}
	for _, e := range entries {
		inner, err := os.ReadDir(filepath.Join(m.trashDir(), e.Name()))
		if err != nil || len(inner) != 1 {
			continue
		}
		ns, err := strconv.ParseInt(e.Name(), 36, 64)
		if err != nil {
			continue
		}
		out = append(out, Trashed{ID: e.Name(), Name: inner[0].Name(), Deleted: time.Unix(0, ns)})
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Deleted.After(out[j].Deleted) })
	return out
}

// Restore brings a deleted preset back (by id, or the newest one of a name).
func (m *Manager) Restore(idOrName string) (Preset, error) {
	unlock, lerr := m.lock()
	if lerr != nil {
		return Preset{}, lerr
	}
	defer unlock()
	for _, t := range m.Trash() {
		if t.ID != idOrName && t.Name != idOrName {
			continue
		}
		dst := filepath.Join(m.UserDir, t.Name)
		if _, err := os.Stat(dst); err == nil {
			return Preset{}, fmt.Errorf("a preset named %q exists again; rename it first", t.Name)
		}
		if err := os.MkdirAll(m.UserDir, 0o755); err != nil {
			return Preset{}, err
		}
		if err := os.Rename(filepath.Join(m.trashDir(), t.ID, t.Name), dst); err != nil {
			return Preset{}, err
		}
		_ = os.Remove(filepath.Join(m.trashDir(), t.ID))
		return m.Find(t.Name)
	}
	return Preset{}, fmt.Errorf("nothing to restore for %q", idOrName)
}

func (m *Manager) purgeTrash() {
	for _, t := range m.Trash() {
		if time.Since(t.Deleted) > trashKeep {
			_ = os.RemoveAll(filepath.Join(m.trashDir(), t.ID))
		}
	}
}

// Duplicate copies any preset (built-in or user) to a new user preset;
// an empty name picks "<name> copy", "<name> copy 2", ...
func (m *Manager) Duplicate(src, name string) (Preset, error) {
	unlock, lerr := m.lock()
	if lerr != nil {
		return Preset{}, lerr
	}
	defer unlock()
	p, err := m.Find(src)
	if err != nil {
		return p, err
	}
	if name == "" {
		name = m.UniqueName(p.Name + " copy")
	}
	if err := m.checkNewName(name); err != nil {
		return Preset{}, err
	}
	files, err := m.dirFiles(p.Path)
	if err != nil {
		return Preset{}, err
	}
	if ref, ok, _ := ReadSetRef(p.Path); ok {
		files[setDomain] = encodeSetRef(ref) // the copy keeps naming its parts
	}
	inf, _ := readInfo(p.Path)
	inf.Author, inf.AuthorURL = "User", ""
	if inf.Description == "" || p.Official {
		inf.Description = strings.TrimSpace("Based on " + p.Name + ". " + inf.Description)
	}
	return m.write(name, files, inf, false)
}

// UniqueName returns base, or base followed by the first free number.
func (m *Manager) UniqueName(base string) string {
	taken := map[string]bool{}
	for _, p := range m.List() {
		taken[strings.ToLower(p.Name)] = true
	}
	if !taken[strings.ToLower(base)] {
		return base
	}
	for i := 2; ; i++ {
		n := fmt.Sprintf("%s %d", base, i)
		if !taken[strings.ToLower(n)] {
			return n
		}
	}
}

// SetInfo changes a user preset's description and/or author (nil = keep).
func (m *Manager) SetInfo(name string, description, author *string) (Preset, error) {
	unlock, lerr := m.lock()
	if lerr != nil {
		return Preset{}, lerr
	}
	defer unlock()
	p, err := m.findUser(name)
	if err != nil {
		return p, err
	}
	inf, _ := readInfo(p.Path)
	if description != nil {
		inf.Description = strings.TrimSpace(*description)
	}
	if author != nil {
		inf.Author = strings.TrimSpace(*author)
	}
	if err := writeInfo(p.Path, inf); err != nil {
		return p, err
	}
	return m.Find(p.Name)
}
