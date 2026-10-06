package binds

import (
	"encoding/json"
	"fmt"
	"strings"

	"yozakura/backend/pkg/specials"
	"yozakura/backend/pkg/yozd/ipc"
)

// Bind sources.
const (
	SourceCore       = "shell-core" // the shell's own binds (binds.json app root)
	SourceUser       = "shell-user" // custom binds (binds.json "custom")
	SourceCompositor = "compositor" // the compositor's own config, read only
	// SourceSpecial binds come from specials.workspaces (toggle / send of a
	// special workspace); they are changed with `special set` /
	// special_update, not here.
	SourceSpecial = "shell-special"
)

// specialBinds lists the toggle and send binds of the special workspaces.
func (a *Advisor) specialBinds() []Bind {
	if a.Specials == nil {
		return nil
	}
	list, err := a.Specials()
	if err != nil {
		return nil
	}
	var out []Bind
	for _, s := range list {
		for _, role := range []struct {
			c     specials.Combo
			label string
		}{{s.Toggle, "Toggle special workspace " + s.Name}, {s.Send, "Send window to special workspace " + s.Name}} {
			b := newBind(SourceSpecial, Combo{Key: role.c.Key, Modifiers: role.c.Modifiers})
			if b.id == "" {
				continue
			}
			b.Label, b.Ref, b.Name = role.label, "special:"+s.ID, s.Name
			out = append(out, b)
		}
	}
	return out
}

// ActionRef is an action with its arguments, as stored in binds.json.
type ActionRef struct {
	Args map[string]any `json:"args"`
	ID   string         `json:"id"`
}

// Bind is one bind of any source.
type Bind struct {
	Source    string      `json:"source"`
	Combo     string      `json:"combo"`
	Modifiers []string    `json:"modifiers"`
	Key       string      `json:"key"`
	Label     string      `json:"label"`
	Actions   []ActionRef `json:"actions,omitempty"`
	Enabled   bool        `json:"enabled"`
	// Ref locates it: "core:system.tools", "custom:12" (index in
	// binds.json "custom"), "compositor".
	Ref     string   `json:"ref"`
	Name    string   `json:"name,omitempty"`
	Layouts []string `json:"layouts,omitempty"`
	// Compositor binds only.
	Dispatcher string `json:"dispatcher,omitempty"`
	Arg        string `json:"arg,omitempty"`
	Submap     string `json:"submap,omitempty"`
	Release    bool   `json:"release,omitempty"`
	id         string
	path       string // core path
	index      int    // custom index
}

// ComboID is the canonical combo identity (see Combo.ID).
func (b Bind) ComboID() string { return b.id }

// customBind is the binds.json "custom" entry shape (key order as the shell
// writes it).
type customBind struct {
	Name    string         `json:"name"`
	Keys    []Combo        `json:"keys"`
	Actions []customAction `json:"actions"`
	Enabled *bool          `json:"enabled,omitempty"`
}

type customAction struct {
	Args    map[string]any `json:"args"`
	ID      string         `json:"id"`
	Layouts []string       `json:"layouts"`
}

type coreEntry struct {
	Action    ActionRef `json:"action"`
	Key       string    `json:"key"`
	Modifiers []string  `json:"modifiers"`
}

func newBind(source string, c Combo) Bind {
	return Bind{Source: source, Combo: c.String(), Modifiers: NormalizeMods(c.Modifiers), Key: c.Key, id: c.ID(), Enabled: true}
}

func (a *Advisor) labelOf(acts []ActionRef) string {
	var parts []string
	for _, r := range acts {
		if act, ok := a.Catalog.Action(r.ID); ok {
			parts = append(parts, act.Describe(a.lang(), r.Args))
		} else if r.ID != "" {
			parts = append(parts, r.ID)
		}
	}
	return strings.Join(parts, " + ")
}

// shellBinds lists the core and custom binds of a loaded binds.json (one
// Bind per key of a custom bind). Core binds missing from the file use
// their CoreBinds.js default, like the shell's adapter.
func (a *Advisor) shellBinds(doc *document) []Bind {
	var out []Bind
	for _, cb := range a.Catalog.Core {
		e := coreEntry{Modifiers: cb.Modifiers, Key: cb.Key, Action: ActionRef{ID: cb.Action, Args: map[string]any{}}}
		if raw, ok := doc.core(cb.Path); ok {
			var got coreEntry
			if json.Unmarshal(raw, &got) == nil && got.Key != "" {
				e = got
			}
		}
		if e.Action.ID == "" {
			e.Action.ID = cb.Action
		}
		b := newBind(SourceCore, Combo{Modifiers: e.Modifiers, Key: e.Key})
		b.Actions = []ActionRef{e.Action}
		b.Label = a.labelOf(b.Actions)
		b.Ref, b.path = "core:"+cb.Path, cb.Path
		b.Enabled = !doc.isDisabled(cb.Path)
		out = append(out, b)
	}
	for i, raw := range doc.custom {
		var cb customBind
		if json.Unmarshal(raw, &cb) != nil {
			continue
		}
		var acts []ActionRef
		var layouts []string
		for _, ca := range cb.Actions {
			acts = append(acts, ActionRef{ID: ca.ID, Args: ca.Args})
			layouts = append(layouts, ca.Layouts...)
		}
		for _, k := range cb.Keys {
			b := newBind(SourceUser, k)
			if b.id == "" {
				continue
			}
			b.Actions, b.Name, b.Layouts = acts, cb.Name, layouts
			b.Label = a.labelOf(acts)
			if b.Label == "" {
				b.Label = cb.Name
			}
			b.Ref, b.index = fmt.Sprintf("custom:%d", i), i
			b.Enabled = cb.Enabled == nil || *cb.Enabled
			out = append(out, b)
		}
	}
	return out
}

// nativeBinds keeps the compositor binds that are not rendered from
// binds.json (BindModel.nativeBinds): a described bind is the user's own
// compositor config (the shell's carry no description); undescribed ones
// beyond what the shell renders on that combo are native too.
func (a *Advisor) nativeBinds(raw []ipc.Bind, shell []Bind) []Bind {
	ours := map[string]int{}
	for _, b := range shell {
		if !b.Enabled {
			continue
		}
		if b.Source == SourceSpecial {
			ours[b.id+"#press"]++
		}
		for _, r := range b.Actions {
			act, ok := a.Catalog.Action(r.ID)
			switch {
			case ok && strings.Contains(act.Flags, "r"):
				ours[b.id+"#release"]++ // a release bind (the lone-Super launcher)
			case ok && act.Hold:
				ours[b.id+"#press"]++
				ours[b.id+"#release"]++
			default:
				ours[b.id+"#press"]++
			}
		}
	}
	seen := map[string]int{}
	var out []Bind
	for _, nb := range raw {
		c := Combo{Modifiers: nb.Modifiers, Key: nb.Key}
		id := c.ID()
		if id == "" {
			continue
		}
		slot := id + "#press"
		if nb.Release {
			slot = id + "#release"
		}
		if nb.Description == "" && nb.Submap == "" {
			seen[slot]++
			if seen[slot] <= ours[slot] {
				continue
			}
		}
		b := newBind(SourceCompositor, c)
		b.Ref = SourceCompositor
		b.Dispatcher, b.Arg, b.Submap, b.Release = nb.Dispatcher, nb.Arg, nb.Submap, nb.Release
		b.Label = nb.Description
		if b.Label == "" {
			b.Label = strings.TrimSpace(nb.Dispatcher + " " + nb.Arg)
		}
		if act := a.actionForDispatch(nb.Dispatcher, nb.Arg); act != nil {
			b.Actions = []ActionRef{{ID: act.ID, Args: map[string]any{}}}
			if nb.Description == "" {
				b.Label = act.Label(a.lang())
			}
		}
		out = append(out, b)
	}
	return out
}

// actionForDispatch maps a compositor dispatcher + argument to the catalog
// action with that static command, if any.
func (a *Advisor) actionForDispatch(dispatcher, arg string) *Action {
	if dispatcher == "" {
		return nil
	}
	for i := range a.Catalog.Actions {
		act := &a.Catalog.Actions[i]
		if act.Argument != nil && act.Dispatcher == dispatcher && *act.Argument == strings.TrimSpace(arg) {
			return act
		}
	}
	return nil
}

// Listing is every bind with its source.
type Listing struct {
	Binds []Bind `json:"binds"`
	// CompositorError says why compositor binds are missing (yozd not
	// running, compositor cannot list them).
	CompositorError string `json:"compositorError,omitempty"`
}

// List returns the shell's binds (core + custom) and the compositor's own.
func (a *Advisor) List() (*Listing, error) {
	doc, err := loadDocument(a.File, a.appID())
	if err != nil {
		return nil, err
	}
	return a.listDoc(doc), nil
}

func (a *Advisor) listDoc(doc *document) *Listing {
	shell := append(a.shellBinds(doc), a.specialBinds()...)
	l := &Listing{Binds: shell}
	if a.Compositor == nil {
		l.CompositorError = "compositor binds not available"
		return l
	}
	raw, err := a.Compositor()
	if err != nil {
		l.CompositorError = err.Error()
		return l
	}
	l.Binds = append(l.Binds, a.nativeBinds(raw, shell)...)
	return l
}

// boundTo returns the enabled binds running an action id.
func boundTo(binds []Bind, actionID string) []Bind {
	var out []Bind
	for _, b := range binds {
		if !b.Enabled {
			continue
		}
		for _, r := range b.Actions {
			if r.ID == actionID {
				out = append(out, b)
				break
			}
		}
	}
	return out
}
