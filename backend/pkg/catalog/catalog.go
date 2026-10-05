// Package catalog is the machine-readable settings catalog of the shell:
// every config key with its type, default, label, description, allowed
// values, range and settings-page location. It is read from the generated
// JSON Schema (assets/schema/<app>.schema.json, built by
// tools/schema/gen_schema.cjs from config/defaults, config/meta and the
// settings schema) and shared by `yozakura config`, `yozakura preset` and
// the MCP config tools, so all of them describe and validate keys the same
// way. Without the generated file it falls back to config/defaults alone
// (types and defaults, no descriptions).
package catalog

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"yozakura/backend/pkg/brand"
)

// SchemaFile is the combined catalog, relative to the shell source.
var SchemaFile = filepath.Join("assets", "schema", brand.AppID+".schema.json")

// Settings is where a key appears in the settings window.
type Settings struct {
	Category      string          `json:"category,omitempty"`
	Section       string          `json:"section,omitempty"`
	Control       string          `json:"control,omitempty"`
	Component     string          `json:"component,omitempty"`
	Entry         string          `json:"entry,omitempty"`
	EntryTitle    string          `json:"entryTitle,omitempty"`
	Step          *float64        `json:"step,omitempty"`
	Min           *float64        `json:"min,omitempty"`
	Max           *float64        `json:"max,omitempty"`
	Keywords      string          `json:"keywords,omitempty"`
	VisibleWhen   json.RawMessage `json:"visibleWhen,omitempty"`
	EnabledWhen   json.RawMessage `json:"enabledWhen,omitempty"`
	SpecialValues []SpecialValue  `json:"specialValues,omitempty"`
}

// SpecialValue is a sentinel accepted besides the range (e.g. -1 = auto).
type SpecialValue struct {
	Value any    `json:"value"`
	Label string `json:"label,omitempty"`
}

// Items constrains array elements.
type Items struct {
	Type string `json:"type,omitempty"`
	Enum []any  `json:"enum,omitempty"`
}

// Entry is one config key (an object or a leaf).
type Entry struct {
	Key         string            `json:"key"` // domain.dotted.path
	Domain      string            `json:"domain"`
	Path        []string          `json:"-"`
	Type        string            `json:"type"` // string|number|boolean|array|object|any
	Title       string            `json:"title,omitempty"`
	Description string            `json:"description,omitempty"`
	Default     any               `json:"default,omitempty"`
	Enum        []any             `json:"enum,omitempty"`
	EnumLabels  map[string]string `json:"enumLabels,omitempty"`
	Min         *float64          `json:"minimum,omitempty"`
	Max         *float64          `json:"maximum,omitempty"`
	Unit        string            `json:"unit,omitempty"`
	Pattern     string            `json:"pattern,omitempty"`
	Format      string            `json:"format,omitempty"`
	Items       *Items            `json:"items,omitempty"`
	UniqueItems bool              `json:"uniqueItems,omitempty"`
	Secret      bool              `json:"secret,omitempty"`
	Local       bool              `json:"local,omitempty"` // machine specific: never carried by presets
	ReadOnly    bool              `json:"readOnly,omitempty"`
	Settings    *Settings         `json:"settings,omitempty"`
	Special     []SpecialValue    `json:"specialValues,omitempty"`
	Children    []string          `json:"children,omitempty"` // object: child names in file order
}

// Leaf reports whether the entry holds a value (not an object of keys).
func (e *Entry) Leaf() bool { return e.Type != "object" }

// Domain is one config file.
type Domain struct {
	Name        string `json:"name"`
	Description string `json:"description"`
	Keys        int    `json:"keys"` // leaf count
}

// Catalog indexes every key of every domain.
type Catalog struct {
	Source     string // where it was loaded from
	domains    []Domain
	categories map[string]Category
	entries    map[string]*Entry
	order      []string // every key, depth-first in file order
}

// Load reads the generated catalog of the shell source at root, falling
// back to config/defaults/*.js when it is missing.
func Load(root string) (*Catalog, error) {
	if root == "" {
		return nil, fmt.Errorf("shell source not found: cannot read the settings catalog")
	}
	data, err := os.ReadFile(filepath.Join(root, SchemaFile))
	if err == nil {
		c, perr := Parse(data)
		if perr != nil {
			return nil, fmt.Errorf("%s: %w", SchemaFile, perr)
		}
		c.Source = filepath.Join(root, SchemaFile)
		return c, nil
	}
	return FromDefaults(root)
}

type schemaNode struct {
	Type          string            `json:"type"`
	Title         string            `json:"title"`
	Description   string            `json:"description"`
	Default       any               `json:"default"`
	Enum          []any             `json:"enum"`
	EnumLabels    map[string]string `json:"x-enumLabels"`
	Minimum       *float64          `json:"minimum"`
	Maximum       *float64          `json:"maximum"`
	Unit          string            `json:"x-unit"`
	Pattern       string            `json:"pattern"`
	Format        string            `json:"format"`
	Items         *Items            `json:"items"`
	UniqueItems   bool              `json:"uniqueItems"`
	Secret        bool              `json:"x-secret"`
	Local         bool              `json:"x-local"`
	ReadOnly      bool              `json:"readOnly"`
	Settings      *Settings         `json:"x-settings"`
	SpecialValues []SpecialValue    `json:"x-specialValues"`
	Range         *struct {
		Min *float64 `json:"min"`
		Max *float64 `json:"max"`
	} `json:"x-range"`
	Properties           orderedProps           `json:"properties"`
	AdditionalProperties *bool                  `json:"additionalProperties"`
	Defs                 map[string]*schemaNode `json:"$defs"`
	Categories           []Category             `json:"x-categories"`
}

// Category is a page of the settings window.
type Category struct {
	ID          string `json:"id"`
	Title       string `json:"title"`
	Description string `json:"description"`
}

// orderedProps keeps the file order of "properties".
type orderedProps struct {
	names []string
	nodes map[string]*schemaNode
}

func (o *orderedProps) UnmarshalJSON(b []byte) error {
	names, err := objectKeys(b)
	if err != nil {
		return err
	}
	o.names = names
	return json.Unmarshal(b, &o.nodes)
}

// Parse builds a catalog from the combined JSON Schema.
func Parse(data []byte) (*Catalog, error) {
	var root schemaNode
	if err := json.Unmarshal(data, &root); err != nil {
		return nil, err
	}
	if len(root.Defs) == 0 {
		return nil, fmt.Errorf("no $defs (not a combined catalog)")
	}
	c := &Catalog{entries: map[string]*Entry{}, categories: map[string]Category{}}
	for _, cat := range root.Categories {
		c.categories[cat.ID] = cat
	}
	names := make([]string, 0, len(root.Defs))
	for n := range root.Defs {
		names = append(names, n)
	}
	sort.Strings(names)
	for _, name := range names {
		def := root.Defs[name]
		leaves := c.addChildren(name, nil, def)
		c.domains = append(c.domains, Domain{Name: name, Description: def.Description, Keys: leaves})
	}
	return c, nil
}

// addChildren registers the properties of node and returns its leaf count.
func (c *Catalog) addChildren(domain string, path []string, node *schemaNode) int {
	leaves := 0
	for _, name := range node.Properties.names {
		child := node.Properties.nodes[name]
		p := append(append([]string{}, path...), name)
		e := &Entry{
			Key: domain + "." + strings.Join(p, "."), Domain: domain, Path: p,
			Type: child.Type, Title: child.Title, Description: child.Description, Default: child.Default,
			Enum: child.Enum, EnumLabels: child.EnumLabels, Min: child.Minimum, Max: child.Maximum,
			Unit: child.Unit, Pattern: child.Pattern, Format: child.Format, Items: child.Items,
			UniqueItems: child.UniqueItems, Secret: child.Secret, Local: child.Local, ReadOnly: child.ReadOnly, Settings: child.Settings,
			Special: child.SpecialValues,
		}
		if child.Range != nil && e.Min == nil && e.Max == nil {
			e.Min, e.Max = child.Range.Min, child.Range.Max
		}
		if e.Settings != nil {
			e.Special = append(e.Special, e.Settings.SpecialValues...)
		}
		if e.Type == "" {
			e.Type = "any"
		}
		c.entries[e.Key] = e
		c.order = append(c.order, e.Key)
		if e.Type == "object" {
			e.Children = append([]string{}, child.Properties.names...)
			leaves += c.addChildren(domain, p, child)
			e.Default = c.defaultOf(e)
		} else {
			leaves++
		}
	}
	return leaves
}

// defaultOf rebuilds an object default from its children.
func (c *Catalog) defaultOf(e *Entry) any {
	if e.Leaf() {
		return e.Default
	}
	out := map[string]any{}
	for _, name := range e.Children {
		out[name] = c.defaultOf(c.entries[e.Key+"."+name])
	}
	return out
}

// CategoryTitle is the settings page title of a category id.
func (c *Catalog) CategoryTitle(id string) string {
	if cat, ok := c.categories[id]; ok && cat.Title != "" {
		return cat.Title
	}
	return id
}

// Domains lists the config domains (sorted).
func (c *Catalog) Domains() []Domain { return append([]Domain{}, c.domains...) }

// DomainNames lists the domain names (sorted).
func (c *Catalog) DomainNames() []string {
	out := make([]string, len(c.domains))
	for i, d := range c.domains {
		out[i] = d.Name
	}
	return out
}

// HasDomain reports whether name is a config domain.
func (c *Catalog) HasDomain(name string) bool {
	for _, d := range c.domains {
		if d.Name == name {
			return true
		}
	}
	return false
}

// Domain returns one domain.
func (c *Catalog) Domain(name string) (Domain, bool) {
	for _, d := range c.domains {
		if d.Name == name {
			return d, true
		}
	}
	return Domain{}, false
}

// Entry returns the entry of a full key ("bar.layout.style").
func (c *Catalog) Entry(key string) (*Entry, bool) {
	e, ok := c.entries[key]
	return e, ok
}

// Keys lists every key (objects and leaves) under prefix, which may be "",
// a domain or any key; leavesOnly drops object keys.
func (c *Catalog) Keys(prefix string, leavesOnly bool) []*Entry {
	var out []*Entry
	for _, k := range c.order {
		if prefix != "" && k != prefix && !strings.HasPrefix(k, prefix+".") {
			continue
		}
		e := c.entries[k]
		if leavesOnly && !e.Leaf() {
			continue
		}
		out = append(out, e)
	}
	return out
}

// DomainDefault is the default document of a domain.
func (c *Catalog) DomainDefault(domain string) map[string]any {
	out := map[string]any{}
	for _, k := range c.order {
		e := c.entries[k]
		if e.Domain == domain && len(e.Path) == 1 {
			out[e.Path[0]] = clone(c.defaultOf(e))
		}
	}
	return out
}

// TopKeys lists the first-level key names of a domain in file order.
func (c *Catalog) TopKeys(domain string) []string {
	var out []string
	for _, k := range c.order {
		e := c.entries[k]
		if e.Domain == domain && len(e.Path) == 1 {
			out = append(out, e.Path[0])
		}
	}
	return out
}

func clone(v any) any {
	data, err := json.Marshal(v)
	if err != nil {
		return v
	}
	var out any
	_ = json.Unmarshal(data, &out)
	return out
}
