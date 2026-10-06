// Package presets manages theme/layout presets on disk: a preset is a
// directory of config domain files (bar.json, theme.json, ...) plus an
// optional info.json and wallpaper.json (the matugen scheme), either built
// in (<shell>/assets/presets/<Name>/) or the user's
// ($XDG_CONFIG_HOME/<app>/presets/<Name>/). The CLI (`yozakura preset`),
// the MCP tools and the settings window's preset studio all go through this
// package, so they behave identically.
package presets

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"golang.org/x/sys/unix"

	"yozakura/backend/pkg/catalog"
	"yozakura/backend/pkg/fsutil"
)

// Excluded domains are never saved into or loaded from a preset (machine
// specific or private): catalog.LocalDomains.
var Excluded = catalog.LocalDomains

// Current names the live config wherever a preset name is accepted.
const Current = "current"

// Defaults names the built-in defaults (every key at its default value).
const Defaults = "defaults"

// DefaultPreset is the built-in preset a stale active marker falls back to
// (e.g. one naming a preset that was removed from the shell).
const DefaultPreset = "Yozakura Default"

// Preset is one preset directory.
type Preset struct {
	Name        string `json:"name"`
	Path        string `json:"path"`
	Official    bool   `json:"official"`
	Active      bool   `json:"active"`
	Author      string `json:"author,omitempty"`
	AuthorURL   string `json:"authorUrl,omitempty"`
	Description string `json:"description,omitempty"`
	// Follows are keys the preset leaves to the user: applying it keeps
	// their live values (e.g. theme.lightMode for a light/dark preset).
	Follows  []string       `json:"follows,omitempty"`
	Domains  []string       `json:"domains"`
	Shadowed bool           `json:"shadowed,omitempty"` // a user preset named like a built-in (rename it to use it)
	Tags     []string       `json:"tags"`
	Hash     string         `json:"hash"`
	Look     map[string]any `json:"look,omitempty"`
}

// Manager reads and writes presets.
type Manager struct {
	Cat         *catalog.Catalog
	Store       *catalog.Store
	UserDir     string // $XDG_CONFIG_HOME/<app>/presets
	OfficialDir string // <shell>/assets/presets
	// WallpaperFile is <cache>/wallpapers.json, where the shell keeps the
	// matugen scheme (the "wallpaper" pseudo-domain). Empty: not handled.
	WallpaperFile string
	// StateDir keeps trial/edit sessions and deleted presets (undo).
	StateDir string
}

// ActiveFile is the marker the shell reads (PresetsService.activePresetFile).
func (m *Manager) ActiveFile() string { return filepath.Join(m.UserDir, "active_preset") }

// Active returns the name of the last applied preset. A marker naming a
// preset that no longer exists (a removed built-in, a preset deleted by
// hand) resolves to DefaultPreset; no marker means no preset is active.
func (m *Manager) Active() string {
	name := m.marker()
	switch {
	case name == "" || m.exists(name):
		return name
	case m.exists(DefaultPreset):
		return DefaultPreset
	}
	return ""
}

// marker is the raw name in the active marker (the preset may be gone).
func (m *Manager) marker() string {
	data, err := os.ReadFile(m.ActiveFile())
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(data))
}

// exists reports whether a built-in or user preset directory named name
// holds at least one domain file (what List would show).
func (m *Manager) exists(name string) bool {
	if filepath.Base(name) != name || strings.HasPrefix(name, ".") {
		return false
	}
	for _, dir := range []string{m.OfficialDir, m.UserDir} {
		if dir != "" && len(domainsIn(filepath.Join(dir, name))) > 0 {
			return true
		}
	}
	return false
}

func (m *Manager) setActive(name string) error {
	if name == "" {
		if err := os.Remove(m.ActiveFile()); err != nil && !os.IsNotExist(err) {
			return err
		}
		return nil
	}
	return writeAtomic(m.ActiveFile(), []byte(name+"\n"))
}

// List returns official presets first, then the user's, each by name.
func (m *Manager) List() []Preset {
	active := m.Active()
	var out []Preset
	for _, root := range []struct {
		dir      string
		official bool
	}{{m.OfficialDir, true}, {m.UserDir, false}} {
		if root.dir == "" {
			continue
		}
		entries, err := os.ReadDir(root.dir)
		if err != nil {
			continue
		}
		var group []Preset
		for _, e := range entries {
			if !e.IsDir() || strings.HasPrefix(e.Name(), ".") {
				continue
			}
			p := Preset{Name: e.Name(), Path: filepath.Join(root.dir, e.Name()), Official: root.official, Author: "Unknown"}
			p.Domains = domainsIn(p.Path)
			if len(p.Domains) == 0 {
				continue
			}
			if info, ok := readInfo(p.Path); ok {
				if info.Author != "" {
					p.Author = info.Author
				}
				p.AuthorURL = info.AuthorURL
				p.Description = info.Description
				p.Follows = info.Follows
			}
			p.Active = p.Name == active
			p.Hash = hashDir(p.Path, p.Domains)
			p.Tags = []string{}
			group = append(group, p)
		}
		sort.Slice(group, func(i, j int) bool { return strings.ToLower(group[i].Name) < strings.ToLower(group[j].Name) })
		out = append(out, group...)
	}
	official := map[string]bool{}
	for _, p := range out {
		if p.Official {
			official[strings.ToLower(p.Name)] = true
		}
	}
	for i := range out {
		if !out[i].Official && official[strings.ToLower(out[i].Name)] {
			out[i].Shadowed = true
			out[i].Active = false
		}
	}
	return out
}

// WithLooks fills Tags and Look of each preset (reads every domain file).
func (m *Manager) WithLooks(list []Preset) []Preset {
	for i := range list {
		docs, err := m.Documents(list[i].Path)
		if err != nil {
			continue
		}
		list[i].Look = m.LookOf(docs)
		list[i].Tags = TagsOf(list[i].Look)
	}
	return list
}

func domainsIn(dir string) []string {
	files, _ := filepath.Glob(filepath.Join(dir, "*.json"))
	var out []string
	for _, f := range files {
		d := strings.TrimSuffix(filepath.Base(f), ".json")
		if d == "info" || Excluded[d] {
			continue
		}
		out = append(out, d)
	}
	sort.Strings(out)
	return out
}

type info struct {
	Author      string   `json:"author"`
	AuthorURL   string   `json:"authorUrl"`
	Description string   `json:"description,omitempty"`
	Follows     []string `json:"follows,omitempty"`
}

func readInfo(dir string) (info, bool) {
	data, err := os.ReadFile(filepath.Join(dir, "info.json"))
	if err != nil {
		return info{}, false
	}
	var i info
	return i, json.Unmarshal(data, &i) == nil
}

func writeInfo(dir string, inf info) error {
	data, _ := json.MarshalIndent(inf, "", "    ")
	return writeAtomic(filepath.Join(dir, "info.json"), append(data, '\n'))
}

// Find resolves a name like the shell does (first exact match, official
// first), then case-insensitively.
func (m *Manager) Find(name string) (Preset, error) {
	all := m.List()
	for _, p := range all {
		if p.Name == name {
			return p, nil
		}
	}
	for _, p := range all {
		if strings.EqualFold(p.Name, name) {
			return p, nil
		}
	}
	names := make([]string, len(all))
	for i, p := range all {
		names[i] = p.Name
	}
	return Preset{}, fmt.Errorf("no preset %q (presets: %s)", name, strings.Join(names, ", "))
}

// findUser resolves a user preset (also one shadowed by a built-in of the
// same name, so it can be renamed or deleted); built-ins are read-only.
func (m *Manager) findUser(name string) (Preset, error) {
	all := m.List()
	for _, exact := range []bool{true, false} {
		for _, p := range all {
			if !p.Official && (p.Name == name || (!exact && strings.EqualFold(p.Name, name))) {
				return p, nil
			}
		}
	}
	p, err := m.Find(name)
	if err != nil {
		return p, err
	}
	if p.Official {
		return p, fmt.Errorf("%q is a built-in preset and read-only; duplicate it to edit", p.Name)
	}
	return p, nil
}

// Documents reads the domain files of a preset, "current" (the live
// config files), "defaults", a preset directory or an exported bundle file.
func (m *Manager) Documents(ref string) (map[string]any, error) {
	raw, err := m.rawDocuments(ref)
	if err != nil {
		return nil, err
	}
	out := map[string]any{}
	for d, data := range raw {
		var v any
		if err := json.Unmarshal(data, &v); err != nil {
			return nil, fmt.Errorf("%s/%s.json: %w", ref, d, err)
		}
		out[d] = v
	}
	return out, nil
}

// rawDocuments is Documents as file contents (key order kept).
func (m *Manager) rawDocuments(ref string) (map[string][]byte, error) {
	out := map[string][]byte{}
	switch ref {
	case Current:
		for _, d := range m.lookDomains() {
			if _, err := os.Stat(m.Store.File(d)); err != nil {
				continue
			}
			data, err := os.ReadFile(m.Store.File(d))
			if err != nil {
				return nil, err
			}
			if out[d], err = m.stripLocal(d, data); err != nil {
				return nil, fmt.Errorf("%s: %w", m.Store.File(d), err)
			}
		}
		if doc := m.currentWallpaper(); doc != nil {
			out[WallpaperDomain] = doc
		}
		return out, nil
	case Defaults:
		for _, d := range m.lookDomains() {
			out[d] = []byte("{}")
		}
		out[WallpaperDomain] = []byte(`{"matugenScheme":"` + DefaultScheme + `"}`)
		return out, nil
	}
	if st, err := os.Stat(ref); err == nil {
		if st.IsDir() {
			return m.readDir(ref, domainsIn(ref))
		}
		b, err := ReadBundle(ref)
		if err != nil {
			return nil, err
		}
		for d, data := range b.raw {
			if Excluded[d] {
				continue
			}
			if out[d], err = m.stripLocal(d, data); err != nil {
				return nil, fmt.Errorf("%s: domain %s: %w", ref, d, err)
			}
		}
		return out, nil
	}
	p, err := m.Find(ref)
	if err != nil {
		return nil, err
	}
	return m.readDir(p.Path, p.Domains)
}

// readDir reads a preset directory's domain files without machine-local keys.
func (m *Manager) readDir(dir string, domains []string) (map[string][]byte, error) {
	raw, err := readDir(dir, domains)
	if err != nil {
		return nil, err
	}
	for d, data := range raw {
		if raw[d], err = m.stripLocal(d, data); err != nil {
			return nil, fmt.Errorf("%s/%s.json: %w", dir, d, err)
		}
	}
	return raw, nil
}

func readDir(dir string, domains []string) (map[string][]byte, error) {
	out := map[string][]byte{}
	for _, d := range domains {
		data, err := os.ReadFile(filepath.Join(dir, d+".json"))
		if err != nil {
			return nil, err
		}
		if !json.Valid(data) {
			return nil, fmt.Errorf("%s/%s.json is not valid JSON", dir, d)
		}
		out[d] = data
	}
	return out, nil
}

// lookDomains are the catalog domains a preset may carry.
func (m *Manager) lookDomains() []string {
	var out []string
	for _, d := range m.Cat.DomainNames() {
		if !Excluded[d] {
			out = append(out, d)
		}
	}
	return out
}

// validate reports catalog problems of one preset file.
func (m *Manager) validate(domain string, doc any) []catalog.Problem {
	if domain == WallpaperDomain {
		return validateWallpaper(doc)
	}
	if m.Cat.HasDomain(domain) {
		return m.Cat.ValidateDocument(domain, doc)
	}
	return nil
}

// knownDomain reports whether a preset may hold the file.
func (m *Manager) knownDomain(d string) bool {
	return d == WallpaperDomain || m.Cat.HasDomain(d)
}

// lockFile serialises preset operations between processes (CLI, MCP,
// settings studio): a session or apply never interleaves with another.
func (m *Manager) lockFile() string { return filepath.Join(m.StateDir, "presets", ".lock") }

// lock takes the preset lock (a no-op without a state dir).
func (m *Manager) lock() (func(), error) {
	if m.StateDir == "" {
		return func() {}, nil
	}
	return fsutil.Lock(m.lockFile())
}

// Apply copies a preset's domain files over the live config (the shell
// hot-reloads them) and marks it active. Values the catalog rejects are
// reported, not fixed: the shell's validator resets them to defaults.
func (m *Manager) Apply(name string) (Preset, []catalog.Problem, error) {
	unlock, err := m.lock()
	if err != nil {
		return Preset{}, nil, err
	}
	defer unlock()
	p, problems, err := m.apply(name)
	if err == nil {
		// A real apply keeps it: a running preview's backup is dropped.
		m.dropSession(PreviewSession)
	}
	return p, problems, err
}

func (m *Manager) apply(name string) (Preset, []catalog.Problem, error) {
	p, err := m.Find(name)
	if err != nil {
		return Preset{}, nil, err
	}
	raw, err := m.readDir(p.Path, p.Domains)
	if err != nil {
		return p, nil, err
	}
	if raw, err = m.keepFollowed(raw, p.Follows); err != nil {
		return p, nil, err
	}
	problems, err := m.applyFiles(raw)
	if err != nil {
		return p, problems, err
	}
	if err := m.setActive(p.Name); err != nil {
		return p, problems, err
	}
	p.Active = true
	return p, problems, nil
}

// keepFollowed copies the live value of every followed key (info.json
// "follows") into the preset files about to be applied, so they survive.
func (m *Manager) keepFollowed(raw map[string][]byte, follows []string) (map[string][]byte, error) {
	for _, key := range follows {
		ref, err := m.Cat.Lookup(key)
		if err != nil {
			return raw, fmt.Errorf("info.json follows: %w", err)
		}
		data, ok := raw[ref.Entry.Domain]
		if !ok || ref.Index >= 0 {
			continue
		}
		live, _, err := m.Store.Get(key)
		if err != nil || live == nil {
			continue
		}
		v, err := catalog.DecodeOrdered(data)
		if err != nil {
			return raw, err
		}
		doc, ok := v.(*catalog.Object)
		if !ok {
			continue
		}
		catalog.SetOrdered(doc, ref.Entry.Path, live)
		out, err := json.MarshalIndent(doc, "", "  ")
		if err != nil {
			return raw, err
		}
		raw[ref.Entry.Domain] = append(out, '\n')
	}
	return raw, nil
}

// applyFiles writes domain files over the live config, keeping the live
// machine-local values (endpoints, secrets, ...).
func (m *Manager) applyFiles(raw map[string][]byte) ([]catalog.Problem, error) {
	var problems []catalog.Problem
	for _, d := range sortedKeys(raw) {
		data := raw[d]
		var doc any
		if err := json.Unmarshal(data, &doc); err != nil {
			return problems, fmt.Errorf("%s.json: %w", d, err)
		}
		problems = append(problems, m.validate(d, doc)...)
		if d == WallpaperDomain {
			if err := m.applyWallpaper(doc); err != nil {
				return problems, err
			}
			continue
		}
		if !m.Cat.HasDomain(d) {
			continue
		}
		data, err := m.keepLocal(d, data)
		if err != nil {
			return problems, fmt.Errorf("%s.json: %w", d, err)
		}
		if err := writeAtomic(m.Store.File(d), data); err != nil {
			return problems, err
		}
	}
	return problems, nil
}

// liveFiles reads the live files of the given domains (missing ones skipped).
func (m *Manager) liveFiles(domains []string) (map[string][]byte, error) {
	files := map[string][]byte{}
	for _, d := range domains {
		if Excluded[d] {
			return nil, fmt.Errorf("%s is never stored in presets (machine specific)", d)
		}
		if d == WallpaperDomain {
			if doc := m.currentWallpaper(); doc != nil {
				files[d] = doc
			}
			continue
		}
		if !m.Cat.HasDomain(d) {
			return nil, fmt.Errorf("unknown config domain %q", d)
		}
		data, err := os.ReadFile(m.Store.File(d))
		if os.IsNotExist(err) {
			continue
		}
		if err != nil {
			return nil, err
		}
		if files[d], err = m.stripLocal(d, data); err != nil {
			return nil, fmt.Errorf("%s: %w", m.Store.File(d), err)
		}
	}
	return files, nil
}

// Save stores the live config domains (all non-excluded ones that exist,
// plus the matugen scheme, or only the given ones) as a user preset,
// copying the files verbatim.
func (m *Manager) Save(name string, domains []string, force bool) (Preset, error) {
	unlock, err := m.lock()
	if err != nil {
		return Preset{}, err
	}
	defer unlock()
	if err := m.checkNewName(name); err != nil {
		return Preset{}, err
	}
	if len(domains) == 0 {
		domains = append(m.lookDomains(), WallpaperDomain)
	}
	files, err := m.liveFiles(domains)
	if err != nil {
		return Preset{}, err
	}
	inf := info{Author: "User"}
	if old, err := m.findUser(name); err == nil && force {
		if prev, ok := readInfo(old.Path); ok {
			inf = prev
		}
	}
	return m.write(name, files, inf, force)
}

// Update overwrites a user preset's files with the live config: the
// domains it already holds, or only the given ones. Its info is kept.
func (m *Manager) Update(name string, domains []string) (Preset, error) {
	unlock, err := m.lock()
	if err != nil {
		return Preset{}, err
	}
	defer unlock()
	return m.update(name, domains)
}

func (m *Manager) update(name string, domains []string) (Preset, error) {
	p, err := m.findUser(name)
	if err != nil {
		return p, err
	}
	if len(domains) == 0 {
		domains = p.Domains
	}
	files, err := m.liveFiles(domains)
	if err != nil {
		return p, err
	}
	for d, data := range files {
		if err := writeAtomic(filepath.Join(p.Path, d+".json"), data); err != nil {
			return p, err
		}
	}
	return m.Find(p.Name)
}

// checkNewName validates a name for a user preset: no built-in name.
func (m *Manager) checkNewName(name string) error {
	if err := validName(name); err != nil {
		return err
	}
	for _, p := range m.List() {
		if p.Official && strings.EqualFold(p.Name, name) {
			return fmt.Errorf("%q is a built-in preset name; choose another", p.Name)
		}
	}
	return nil
}

// write creates (or with force replaces) a user preset from raw domain
// files. The preset is built in a hidden staging dir and swapped in whole,
// so a failed write never leaves a half-replaced (or deleted) preset.
func (m *Manager) write(name string, files map[string][]byte, inf info, force bool) (Preset, error) {
	if err := validName(name); err != nil {
		return Preset{}, err
	}
	if len(files) == 0 {
		return Preset{}, fmt.Errorf("nothing to save: no config domain files")
	}
	dir := filepath.Join(m.UserDir, name)
	_, statErr := os.Stat(dir)
	exists := statErr == nil
	if exists && !force {
		return Preset{}, fmt.Errorf("preset %q already exists (use --force to overwrite)", name)
	}
	if err := os.MkdirAll(m.UserDir, 0o755); err != nil {
		return Preset{}, err
	}
	staging, err := os.MkdirTemp(m.UserDir, "."+name+".new-")
	if err != nil {
		return Preset{}, err
	}
	defer os.RemoveAll(staging)
	if err := os.Chmod(staging, 0o755); err != nil {
		return Preset{}, err
	}
	for _, d := range sortedKeys(files) {
		if err := writeAtomic(filepath.Join(staging, d+".json"), files[d]); err != nil {
			return Preset{}, err
		}
	}
	if err := writeInfo(staging, inf); err != nil {
		return Preset{}, err
	}
	if err := swapDir(staging, dir, exists); err != nil {
		return Preset{}, err
	}
	return m.Find(name)
}

// swapDir moves staging to dir, atomically exchanging it with an existing
// dir (whose old content is then removed).
func swapDir(staging, dir string, exists bool) error {
	if !exists {
		return os.Rename(staging, dir)
	}
	if err := unix.Renameat2(unix.AT_FDCWD, staging, unix.AT_FDCWD, dir, unix.RENAME_EXCHANGE); err != nil {
		// No RENAME_EXCHANGE (some filesystems): move the old dir aside first.
		old := staging + ".old"
		if err := os.Rename(dir, old); err != nil {
			return err
		}
		if err := os.Rename(staging, dir); err != nil {
			_ = os.Rename(old, dir)
			return err
		}
		return os.RemoveAll(old)
	}
	return nil // staging now holds the old preset; the caller removes it
}

func validName(name string) error {
	if strings.TrimSpace(name) == "" || name != strings.TrimSpace(name) || name == "." || name == ".." ||
		strings.HasPrefix(name, ".") || strings.ContainsAny(name, "/\x00\n") || name == Current || name == Defaults {
		return fmt.Errorf("invalid preset name %q", name)
	}
	return nil
}

// writeAtomic replaces a file crash-safely, writing through symlinks.
func writeAtomic(path string, data []byte) error {
	return fsutil.WriteFile(path, data, 0o644)
}

func sortedKeys[V any](m map[string]V) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}
