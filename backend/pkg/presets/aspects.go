package presets

import (
	"encoding/json"
	"fmt"
	"sort"
	"strings"

	"yozakura/backend/pkg/catalog"
)

// Aspect is one independently mixable part of a look. Domains are whole
// preset files; Keys are first-level keys of another aspect's domain that
// belong here instead (e.g. motion lives in theme.json but is "windows").
// Category is the settings page to open for it.
type Aspect struct {
	ID       string   `json:"id"`
	Domains  []string `json:"domains"`
	Keys     []string `json:"keys,omitempty"`
	Category string   `json:"category"`
}

// Aspects is the registry used by the mixer, the editor and `preset mix`.
// Adding an aspect is one entry here plus its label in translations.
var Aspects = []Aspect{
	{ID: "layout", Domains: []string{"bar", "notch", "dock", "overview", "workspaces"}, Category: "bar"},
	{ID: "colors", Domains: []string{"theme", WallpaperDomain}, Category: "appearance"},
	{ID: "windows", Domains: []string{"compositor", "performance"}, Keys: []string{"theme.animDuration", "theme.paletteTransitionDuration"}, Category: "windows"},
	{ID: "desktop", Domains: []string{"desktop"}, Category: "desktop"},
	{ID: "lockscreen", Domains: []string{"lockscreen"}, Category: "lockscreen"},
	{ID: "terminal", Domains: []string{"terminal"}, Keys: []string{"apps.kitty"}, Category: "terminal"},
}

// AspectByID returns the aspect, or nil.
func AspectByID(id string) *Aspect {
	for i := range Aspects {
		if Aspects[i].ID == id {
			return &Aspects[i]
		}
	}
	return nil
}

// AspectOf names the aspect a key (or domain) belongs to; "other" when none.
func AspectOf(key string) string {
	for _, a := range Aspects {
		for _, k := range a.Keys {
			if key == k || strings.HasPrefix(key, k+".") {
				return a.ID
			}
		}
	}
	domain := strings.SplitN(key, ".", 2)[0]
	for _, a := range Aspects {
		for _, d := range a.Domains {
			if d == domain {
				return a.ID
			}
		}
	}
	return "other"
}

// Mix creates a user preset taking each aspect from a source (a preset
// name, "current" or "defaults"); aspects without a source are left out,
// so applying the result keeps the user's values for them.
func (m *Manager) Mix(name string, sources map[string]string, description string, force bool) (Preset, error) {
	unlock, lerr := m.lock()
	if lerr != nil {
		return Preset{}, lerr
	}
	defer unlock()
	if err := m.checkNewName(name); err != nil {
		return Preset{}, err
	}
	for id := range sources {
		if AspectByID(id) == nil {
			return Preset{}, fmt.Errorf("unknown aspect %q (aspects: %s)", id, strings.Join(aspectIDs(), ", "))
		}
	}
	cache := map[string]map[string][]byte{}
	docsOf := func(ref string) (map[string][]byte, error) {
		if d, ok := cache[ref]; ok {
			return d, nil
		}
		d, err := m.rawDocuments(ref)
		if err != nil {
			return nil, err
		}
		cache[ref] = d
		return d, nil
	}
	objects := map[string]*catalog.Object{}
	var parts []string
	// Whole domains first, then keys that move to another aspect.
	for _, a := range Aspects {
		ref, ok := sources[a.ID]
		if !ok || ref == "" {
			continue
		}
		parts = append(parts, a.ID+": "+ref)
		docs, err := docsOf(ref)
		if err != nil {
			return Preset{}, err
		}
		for _, d := range a.Domains {
			data, ok := docs[d]
			if !ok {
				continue
			}
			v, err := catalog.DecodeOrdered(data)
			if err != nil {
				return Preset{}, fmt.Errorf("%s/%s.json: %w", ref, d, err)
			}
			o, ok := v.(*catalog.Object)
			if !ok {
				return Preset{}, fmt.Errorf("%s/%s.json: not an object", ref, d)
			}
			objects[d] = o
		}
	}
	for _, a := range Aspects {
		ref, ok := sources[a.ID]
		if !ok || ref == "" || len(a.Keys) == 0 {
			continue
		}
		docs, err := docsOf(ref)
		if err != nil {
			return Preset{}, err
		}
		for _, key := range a.Keys {
			kp := strings.SplitN(key, ".", 2)
			domain, prop := kp[0], kp[1]
			var src any
			if data, ok := docs[domain]; ok {
				var doc map[string]any
				if json.Unmarshal(data, &doc) == nil {
					src = doc[prop]
				}
			}
			if src == nil {
				src = m.Cat.DomainDefault(domain)[prop]
			}
			o := objects[domain]
			if o == nil {
				o = catalog.NewObject()
				objects[domain] = o
			}
			o.Set(prop, src)
		}
	}
	files := map[string][]byte{}
	for d, o := range objects {
		data, err := json.MarshalIndent(o, "", "  ")
		if err != nil {
			return Preset{}, err
		}
		files[d] = append(data, '\n')
	}
	if description == "" && len(parts) > 0 {
		description = "Mixed from " + strings.Join(parts, ", ")
	}
	return m.write(name, files, info{Author: "User", Description: description}, force)
}

func aspectIDs() []string {
	out := make([]string, len(Aspects))
	for i, a := range Aspects {
		out[i] = a.ID
	}
	return out
}

// Change is one key a preset sets differently from the reference, with the
// settings page that edits it.
type Change struct {
	Key      string `json:"key"`
	Title    string `json:"title,omitempty"`
	From     any    `json:"from"`
	To       any    `json:"to"`
	Category string `json:"category,omitempty"`
	Section  string `json:"section,omitempty"`
	Entry    string `json:"entry,omitempty"`
}

// AspectReport is what a preset does for one aspect.
type AspectReport struct {
	ID       string   `json:"id"`
	Category string   `json:"category"`
	Carried  bool     `json:"carried"`          // the preset holds files of this aspect
	Changes  []Change `json:"changes"`          // keys differing from the reference
	SameAs   []string `json:"sameAs,omitempty"` // other presets identical for this aspect
}

// Inspection describes a preset against a reference ("defaults" or any
// preset): which aspects it changes and how.
type Inspection struct {
	Preset  Preset         `json:"preset"`
	Against string         `json:"against"`
	Aspects []AspectReport `json:"aspects"`
	Total   int            `json:"total"`
}

// Inspect reports, aspect by aspect, the keys a preset sets differently
// from against (default "defaults"), and the other presets that share
// each aspect exactly.
func (m *Manager) Inspect(name, against string) (*Inspection, error) {
	if against == "" {
		against = Defaults
	}
	var p Preset
	var docs map[string]any
	var err error
	if name == Current {
		p = Preset{Name: Current}
	} else if p, err = m.Find(name); err != nil {
		return nil, err
	}
	if docs, err = m.Documents(name); err != nil {
		return nil, err
	}
	if name != Current {
		p.Domains = sortedKeys(docs)
		p = m.WithLooks([]Preset{p})[0]
	}
	base, err := m.Documents(against)
	if err != nil {
		return nil, err
	}
	diffs := m.compareDocs(base, docs, sortedKeys(docs))
	byAspect := map[string][]Change{}
	for _, d := range diffs {
		c := Change{Key: d.Key, From: d.A, To: d.B}
		if e, ok := m.Cat.Entry(d.Key); ok {
			c.Title = e.Title
			if e.Settings != nil {
				c.Category, c.Section, c.Entry = e.Settings.Category, e.Settings.Section, e.Settings.Entry
			}
		}
		a := AspectOf(d.Key)
		byAspect[a] = append(byAspect[a], c)
	}
	others := m.List()
	otherDocs := map[string]map[string]any{}
	for _, o := range others {
		if o.Name == p.Name {
			continue
		}
		if d, err := m.Documents(o.Path); err == nil {
			otherDocs[o.Name] = d
		}
	}
	out := &Inspection{Preset: p, Against: against}
	ids := append(aspectIDs(), "other")
	for _, id := range ids {
		r := AspectReport{ID: id, Changes: byAspect[id]}
		if r.Changes == nil {
			r.Changes = []Change{}
		}
		domains := aspectDomains(id, docs)
		r.Carried = len(domains) > 0
		if a := AspectByID(id); a != nil {
			r.Category = a.Category
		}
		if id == "other" && !r.Carried {
			continue
		}
		if r.Carried {
			for _, o := range sortedKeys(otherDocs) {
				if m.sameAspect(id, docs, otherDocs[o], domains) {
					r.SameAs = append(r.SameAs, o)
				}
			}
		}
		out.Total += len(r.Changes)
		out.Aspects = append(out.Aspects, r)
	}
	return out, nil
}

// aspectDomains lists the domains of docs that hold keys of an aspect.
func aspectDomains(id string, docs map[string]any) []string {
	seen := map[string]bool{}
	for d := range docs {
		if AspectOf(d) == id {
			seen[d] = true
		}
	}
	if a := AspectByID(id); a != nil {
		for _, k := range a.Keys {
			d := strings.SplitN(k, ".", 2)[0]
			if _, ok := docs[d]; ok {
				seen[d] = true
			}
		}
	}
	out := sortedKeys(seen)
	sort.Strings(out)
	return out
}

// sameAspect reports whether b sets every key of the aspect like a.
func (m *Manager) sameAspect(id string, a, b map[string]any, domains []string) bool {
	for _, d := range domains {
		if _, ok := b[d]; !ok {
			return false
		}
	}
	for _, diff := range m.compareDocs(a, b, domains) {
		if AspectOf(diff.Key) == id {
			return false
		}
	}
	return true
}
