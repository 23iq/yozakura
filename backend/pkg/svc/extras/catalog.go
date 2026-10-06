// Package extras holds the catalog of installable extras (AI agents, local
// AI, GPU tooling, terminal tools, apps) and platform detection.
package extras

import (
	"encoding/json"
	"fmt"
	"net/url"
	"os"
	"path/filepath"
	"regexp"

	"yozakura/backend/pkg/paths"
)

// Method lists native packages for one distro family. GPU variants override
// Pkgs (repo packages) of this distro only, never AUR.
type Method struct {
	Pkgs []string    `json:"pkgs,omitempty"`
	AUR  []string    `json:"aur,omitempty"` // arch only
	GPU  GPUVariants `json:"gpu,omitempty"`
}

// GPUVariants maps "nvidia"|"amd"|"intel"|"none" to repo packages that
// override the owning Method.Pkgs.
type GPUVariants map[string][]string

// ScriptSpec is a vetted remote install script.
type ScriptSpec struct {
	URL  string   `json:"url"`
	Args []string `json:"args,omitempty"`
}

// DetectSpec describes how to tell an entry is already installed.
type DetectSpec struct {
	Bins    []string `json:"bins,omitempty"`
	Flatpak string   `json:"flatpak,omitempty"`
	Pkgs    []string `json:"pkgs,omitempty"`
	Paths   []string `json:"paths,omitempty"` // globs, "~" allowed
}

// Install lists the ways an entry can be installed.
type Install struct {
	Arch    *Method     `json:"arch,omitempty"`
	Fedora  *Method     `json:"fedora,omitempty"`
	Flatpak string      `json:"flatpak,omitempty"`
	Npm     string      `json:"npm,omitempty"`
	Script  *ScriptSpec `json:"script,omitempty"`
	Shell   string      `json:"shell,omitempty"`   // repo script under scripts/
	Service string      `json:"service,omitempty"` // system unit to enable after
}

// Entry is one installable item.
type Entry struct {
	ID          string     `json:"id"`
	Category    string     `json:"category"`
	Name        string     `json:"name"`
	Icon        string     `json:"icon"`
	Description string     `json:"description,omitempty"`
	Size        string     `json:"size,omitempty"`
	Recommended bool       `json:"recommended,omitempty"`
	Hidden      bool       `json:"hidden,omitempty"`
	Detect      DetectSpec `json:"detect"`
	Install     Install    `json:"install"`
	Requires    []string   `json:"requires,omitempty"`
	Post        []string   `json:"post,omitempty"`     // "apphook:<id>"
	Only        []string   `json:"only,omitempty"`     // distros; empty = all
	Multilib    bool       `json:"multilib,omitempty"` // arch pkgs need [multilib]
}

// Category groups entries; Name is an i18n key.
type Category struct {
	ID   string `json:"id"`
	Name string `json:"name"`
	Icon string `json:"icon"`
}

// Catalog is the parsed extras.json.
type Catalog struct {
	Version    int        `json:"version"`
	Categories []Category `json:"categories"`
	Entries    []Entry    `json:"entries"`
}

var (
	rePkg     = regexp.MustCompile(`^[a-z0-9@._+-]+$`)
	reID      = regexp.MustCompile(`^[a-z0-9-]+$`)
	reNpm     = regexp.MustCompile(`^(@[a-z0-9-]+/)?[a-z0-9._-]+$`)
	reFlatpak = regexp.MustCompile(`^[A-Za-z0-9._-]+$`)
	reShell   = regexp.MustCompile(`^[a-z0-9_]+\.sh$`)
	reUnit    = regexp.MustCompile(`^[a-z0-9@._-]+$`)
	reArg     = regexp.MustCompile(`^[A-Za-z0-9@._+/~=:-]+$`)
	reHook    = regexp.MustCompile(`^apphook:[a-z0-9-]+$`)

	scriptHosts = map[string]bool{"claude.ai": true, "opencode.ai": true, "ohmyposh.dev": true}
	gpuKeys     = map[string]bool{"nvidia": true, "amd": true, "intel": true, "none": true}
	distroKeys  = map[string]bool{"arch": true, "fedora": true}
)

// CatalogPath returns <shell repo>/assets/catalog/extras.json.
func CatalogPath() string {
	return filepath.Join(paths.FindShellSource(), "assets", "catalog", "extras.json")
}

// LoadCatalog reads, parses and validates the catalog at path.
func LoadCatalog(path string) (*Catalog, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var c Catalog
	if err := json.Unmarshal(data, &c); err != nil {
		return nil, fmt.Errorf("extras catalog: %w", err)
	}
	if err := c.Validate(); err != nil {
		return nil, err
	}
	return &c, nil
}

// Get returns the entry with the given id.
func (c *Catalog) Get(id string) (Entry, bool) {
	for _, e := range c.Entries {
		if e.ID == id {
			return e, true
		}
	}
	return Entry{}, false
}

// Validate checks structural and safety invariants: unique ids, known
// categories, resolvable acyclic requires, safe package/script/arg values and
// at least one install method per entry.
func (c *Catalog) Validate() error {
	cats := map[string]bool{}
	for _, cat := range c.Categories {
		if !reID.MatchString(cat.ID) || cats[cat.ID] {
			return fmt.Errorf("extras catalog: bad or duplicate category %q", cat.ID)
		}
		cats[cat.ID] = true
	}
	ids := map[string]*Entry{}
	for i := range c.Entries {
		e := &c.Entries[i]
		if !reID.MatchString(e.ID) {
			return fmt.Errorf("extras catalog: bad id %q", e.ID)
		}
		if ids[e.ID] != nil {
			return fmt.Errorf("extras catalog: duplicate id %q", e.ID)
		}
		ids[e.ID] = e
		if !cats[e.Category] {
			return fmt.Errorf("extras catalog: %s: unknown category %q", e.ID, e.Category)
		}
		if err := e.validateInstall(); err != nil {
			return fmt.Errorf("extras catalog: %s: %w", e.ID, err)
		}
		for _, d := range e.Only {
			if !distroKeys[d] {
				return fmt.Errorf("extras catalog: %s: unknown distro %q", e.ID, d)
			}
		}
		for _, h := range e.Post {
			if !reHook.MatchString(h) {
				return fmt.Errorf("extras catalog: %s: bad post hook %q", e.ID, h)
			}
		}
		if err := checkPkgs(e.Detect.Pkgs); err != nil {
			return fmt.Errorf("extras catalog: %s: detect: %w", e.ID, err)
		}
	}
	for _, e := range c.Entries {
		for _, r := range e.Requires {
			if ids[r] == nil {
				return fmt.Errorf("extras catalog: %s requires unknown %q", e.ID, r)
			}
		}
	}
	return c.checkCycles(ids)
}

func (c *Catalog) checkCycles(ids map[string]*Entry) error {
	state := map[string]int{} // 1 visiting, 2 done
	var visit func(id string) error
	visit = func(id string) error {
		switch state[id] {
		case 1:
			return fmt.Errorf("extras catalog: requires cycle at %q", id)
		case 2:
			return nil
		}
		state[id] = 1
		for _, r := range ids[id].Requires {
			if err := visit(r); err != nil {
				return err
			}
		}
		state[id] = 2
		return nil
	}
	for _, e := range c.Entries {
		if err := visit(e.ID); err != nil {
			return err
		}
	}
	return nil
}

func checkPkgs(pkgs []string) error {
	for _, p := range pkgs {
		if !rePkg.MatchString(p) {
			return fmt.Errorf("bad package name %q", p)
		}
	}
	return nil
}

func (m *Method) validate() error {
	if m == nil {
		return nil
	}
	if err := checkPkgs(m.Pkgs); err != nil {
		return err
	}
	for k, pkgs := range m.GPU {
		if !gpuKeys[k] {
			return fmt.Errorf("unknown gpu variant %q", k)
		}
		if err := checkPkgs(pkgs); err != nil {
			return err
		}
	}
	return checkPkgs(m.AUR)
}

func (e *Entry) validateInstall() error {
	in := e.Install
	if err := in.Arch.validate(); err != nil {
		return err
	}
	if err := in.Fedora.validate(); err != nil {
		return err
	}
	if in.Flatpak != "" && !reFlatpak.MatchString(in.Flatpak) {
		return fmt.Errorf("bad flatpak id %q", in.Flatpak)
	}
	if in.Npm != "" && !reNpm.MatchString(in.Npm) {
		return fmt.Errorf("bad npm package %q", in.Npm)
	}
	if in.Shell != "" && !reShell.MatchString(in.Shell) {
		return fmt.Errorf("bad shell script %q", in.Shell)
	}
	if in.Service != "" && !reUnit.MatchString(in.Service) {
		return fmt.Errorf("bad service %q", in.Service)
	}
	if in.Script != nil {
		if err := in.Script.validate(); err != nil {
			return err
		}
	}
	if in.Arch == nil && in.Fedora == nil && in.Flatpak == "" && in.Npm == "" &&
		in.Script == nil && in.Shell == "" {
		return fmt.Errorf("no install method")
	}
	return nil
}

func (s *ScriptSpec) validate() error {
	u, err := url.Parse(s.URL)
	if err != nil || u.Scheme != "https" || !scriptHosts[u.Hostname()] || u.User != nil {
		return fmt.Errorf("script url %q not allowed", s.URL)
	}
	for _, a := range s.Args {
		if !reArg.MatchString(a) {
			return fmt.Errorf("bad script arg %q", a)
		}
	}
	return nil
}
