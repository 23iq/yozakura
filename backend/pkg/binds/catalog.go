package binds

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"yozakura/backend/pkg/brand"
)

// CatalogFile is the generated action catalog, relative to the shell source.
var CatalogFile = filepath.Join("assets", "schema", "bind-actions.json")

// Field is one argument of an action (e.g. "index" of workspace.switch).
type Field struct {
	Key         string            `json:"key"`
	Labels      map[string]string `json:"labels"`
	Placeholder string            `json:"placeholder"`
	Kind        string            `json:"kind"`
	Default     string            `json:"default"`
}

// Action is one entry of config/KeybindActions.js.
type Action struct {
	ID         string            `json:"id"`
	Labels     map[string]string `json:"labels"`
	Category   string            `json:"category"`
	Group      string            `json:"group"`
	Dispatcher string            `json:"dispatcher"`
	Argument   *string           `json:"argument,omitempty"`
	Flags      string            `json:"flags,omitempty"`
	Hold       bool              `json:"hold,omitempty"`
	Hidden     bool              `json:"hidden,omitempty"`
	Args       []Field           `json:"args,omitempty"`
}

// Group is a catalog group ("windows", "media", ...).
type Group struct {
	ID           string            `json:"id"`
	Labels       map[string]string `json:"labels"`
	Descriptions map[string]string `json:"descriptions"`
}

// CoreBind is one of the shell's own binds (config/CoreBinds.js).
type CoreBind struct {
	Path      string   `json:"path"`
	Modifiers []string `json:"modifiers"`
	Key       string   `json:"key"`
	Action    string   `json:"action"`
}

// Catalog is the parsed bind-actions.json.
type Catalog struct {
	Groups  []Group    `json:"groups"`
	Actions []Action   `json:"actions"`
	Core    []CoreBind `json:"core"`
	byID    map[string]int
}

// LoadCatalog reads the catalog of the shell source at root.
func LoadCatalog(root string) (*Catalog, error) {
	if root == "" {
		return nil, fmt.Errorf("shell source not found: cannot read the keybind action catalog")
	}
	data, err := os.ReadFile(filepath.Join(root, CatalogFile))
	if err != nil {
		return nil, fmt.Errorf("keybind action catalog: %w (run `make schema`)", err)
	}
	return ParseCatalog(data)
}

// ParseCatalog decodes bind-actions.json.
func ParseCatalog(data []byte) (*Catalog, error) {
	var c Catalog
	if err := json.Unmarshal(data, &c); err != nil {
		return nil, fmt.Errorf("keybind action catalog: %w", err)
	}
	c.byID = map[string]int{}
	for i, a := range c.Actions {
		c.byID[a.ID] = i
	}
	return &c, nil
}

// Action returns the action with that id (legacy app ids accepted).
func (c *Catalog) Action(id string) (*Action, bool) {
	i, ok := c.byID[brand.NormalizeAction(strings.TrimSpace(id))]
	if !ok {
		return nil, false
	}
	return &c.Actions[i], true
}

// GroupLabel is the English label of a group id.
func (c *Catalog) GroupLabel(id string) string {
	for _, g := range c.Groups {
		if g.ID == id {
			return pick(g.Labels, "en", id)
		}
	}
	return id
}

// CoreFor returns the core binds running an action.
func (c *Catalog) CoreFor(actionID string) []CoreBind {
	var out []CoreBind
	for _, b := range c.Core {
		if b.Action == actionID {
			out = append(out, b)
		}
	}
	return out
}

// Label is the action's label in lang (English fallback).
func (a *Action) Label(lang string) string {
	return pick(a.Labels, lang, a.ID)
}

func pick(m map[string]string, lang, fallback string) string {
	if s := m[lang]; s != "" {
		return s
	}
	if s := m["en"]; s != "" {
		return s
	}
	return fallback
}

// Describe is the label plus argument values ("Switch workspace · 3"),
// like KeybindActions.describeAction.
func (a *Action) Describe(lang string, args map[string]any) string {
	var vals []string
	for _, f := range a.Args {
		if v, ok := args[f.Key]; ok {
			if s := strings.TrimSpace(fmt.Sprint(v)); s != "" {
				vals = append(vals, s)
			}
		}
	}
	if len(vals) == 0 {
		return a.Label(lang)
	}
	return a.Label(lang) + " · " + strings.Join(vals, " ")
}

// CheckArgs validates args against the action's fields and returns them with
// defaults filled in. The first field is required when it has no default
// (the app of apps.launch, the command of command.run, ...).
func (a *Action) CheckArgs(args map[string]any) (map[string]any, error) {
	out := map[string]any{}
	known := map[string]bool{}
	for i, f := range a.Args {
		known[f.Key] = true
		v, ok := args[f.Key]
		s := ""
		if ok && v != nil {
			s = strings.TrimSpace(fmt.Sprint(v))
		}
		if s == "" {
			s = f.Default
		}
		if s == "" && i == 0 {
			return nil, fmt.Errorf("action %s needs argument %q (%s)", a.ID, f.Key, f.Placeholder)
		}
		out[f.Key] = s
	}
	var unknown []string
	for k := range args {
		if !known[k] {
			unknown = append(unknown, k)
		}
	}
	if len(unknown) > 0 {
		sort.Strings(unknown)
		return nil, fmt.Errorf("action %s has no argument %s", a.ID, strings.Join(unknown, ", "))
	}
	return out, nil
}
