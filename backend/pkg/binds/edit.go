package binds

import (
	"encoding/json"
	"fmt"
	"sort"
	"strings"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/fsutil"
)

// SetRequest binds Combo to an action.
type SetRequest struct {
	Combo  string         `json:"combo"`
	Action string         `json:"action"`
	Args   map[string]any `json:"args,omitempty"`
	// Name of a new custom bind ("" = the action's label).
	Name string `json:"name,omitempty"`
	// Replace unbinds the shell binds already on Combo (compositor binds
	// are never touched: a combo they use is refused).
	Replace bool `json:"replace,omitempty"`
	// Additional keeps a core action's own bind and adds Combo as an extra
	// custom bind (default: a core action is rebound).
	Additional bool `json:"additional,omitempty"`
}

// Undo is how to revert an edit.
type Undo struct {
	Tool  string         `json:"tool"`
	Args  map[string]any `json:"args"`
	CLI   string         `json:"cli"`
	Token string         `json:"-"`
}

// EditResult describes a binds.json edit.
type EditResult struct {
	Combo   string     `json:"combo,omitempty"`
	Action  *ActionRef `json:"action,omitempty"`
	Label   string     `json:"label,omitempty"`
	Changes []string   `json:"changes"`
	Undo    *Undo      `json:"undo,omitempty"`
	Note    string     `json:"note"`
}

const liveNote = "binds.json was written; the running shell reloads it and regenerates the compositor binds, so the change is live. The compositor's own config was not touched."

// ConflictError is returned by Set when Combo is in use.
type ConflictError struct {
	Combo     string
	Conflicts []Bind
	// Fixed is true when a bind that cannot be replaced from here uses it
	// (the compositor's own config, a special workspace).
	Fixed bool
}

func (e *ConflictError) Error() string {
	var parts []string
	special := false
	for _, b := range e.Conflicts {
		parts = append(parts, fmt.Sprintf("%s (%s)", b.Label, b.Source))
		special = special || b.Source == SourceSpecial
	}
	msg := fmt.Sprintf("%s is already bound to %s", e.Combo, strings.Join(parts, ", "))
	switch {
	case e.Fixed && special:
		return msg + "; change the special workspace's bind with special_update, or pick another combo (binds_suggest)"
	case e.Fixed:
		return msg + "; the compositor's own config is never edited here, pick another combo (binds_suggest)"
	}
	return msg + "; pass replace to unbind it, or pick another combo (binds_suggest)"
}

// fixed reports binds that binds.json edits cannot change.
func fixed(b Bind) bool { return b.Source == SourceCompositor || b.Source == SourceSpecial }

func (a *Advisor) undoFor(inverse []op) *Undo {
	tok := encodeToken(inverse)
	if tok == "" {
		return nil
	}
	return &Undo{Tool: "binds_undo", Args: map[string]any{"token": tok}, CLI: brand.Command("binds", "undo", tok), Token: tok}
}

// edit loads binds.json under the lock, lets fn build ops, applies and
// saves them.
func (a *Advisor) edit(fn func(doc *document, l *Listing) ([]op, error)) ([]op, error) {
	if a.LockFile != "" {
		unlock, err := fsutil.Lock(a.LockFile)
		if err != nil {
			return nil, err
		}
		defer unlock()
	}
	doc, err := loadDocument(a.File, a.appID())
	if err != nil {
		return nil, err
	}
	ops, err := fn(doc, a.listDoc(doc))
	if err != nil || len(ops) == 0 {
		return nil, err
	}
	inverse, err := doc.apply(ops)
	if err != nil {
		return nil, err
	}
	return inverse, doc.save(a.File)
}

// unbindOps unbinds one shell bind from its combo: a core bind is
// switched off, a custom bind loses that key (or goes when it was its
// only one).
func unbindOps(doc *document, b Bind) ([]op, error) {
	if b.Source == SourceCore {
		return []op{{Op: opDisabledAdd, Path: b.path}}, nil
	}
	raw := doc.custom[b.index]
	var cb map[string]any
	if err := json.Unmarshal(raw, &cb); err != nil {
		return nil, err
	}
	keys, _ := cb["keys"].([]any)
	var keep []json.RawMessage
	for _, k := range keys {
		kb, _ := json.Marshal(k)
		var c Combo
		if json.Unmarshal(kb, &c) == nil && c.ID() == b.id {
			continue
		}
		keep = append(keep, kb)
	}
	del := op{Op: opCustomDelete, Index: b.index, Bind: raw}
	if len(keep) == 0 {
		return []op{del}, nil
	}
	o, err := parseObject(raw)
	if err != nil {
		return nil, err
	}
	kj, err := marshalPlain(keep)
	if err != nil {
		return nil, err
	}
	o.set("keys", kj)
	return []op{del, {Op: opCustomInsert, Index: b.index, Bind: o.marshal()}}, nil
}

// unbindAll unbinds several shell binds; custom binds go from the highest
// index down so earlier indices stay valid.
func unbindAll(doc *document, list []Bind) ([]op, []string, error) {
	sort.SliceStable(list, func(i, j int) bool { return list[i].index > list[j].index })
	var ops []op
	var changes []string
	done := map[string]bool{}
	for _, b := range list {
		if done[b.Ref] {
			continue
		}
		done[b.Ref] = true
		o, err := unbindOps(doc, b)
		if err != nil {
			return nil, nil, err
		}
		ops = append(ops, o...)
		changes = append(changes, fmt.Sprintf("unbound %s from %s (%s)", b.Combo, b.Label, b.Source))
	}
	return ops, changes, nil
}

// Set binds a combo to an action in binds.json.
func (a *Advisor) Set(req SetRequest) (*EditResult, error) {
	c, err := ParseCombo(req.Combo)
	if err != nil {
		return nil, err
	}
	act, ok := a.Catalog.Action(req.Action)
	if !ok {
		return nil, fmt.Errorf("unknown action %q (find one with binds_search)", req.Action)
	}
	args, err := act.CheckArgs(req.Args)
	if err != nil {
		return nil, err
	}
	ref := ActionRef{ID: act.ID, Args: args}
	res := &EditResult{Combo: c.String(), Action: &ref, Label: act.Describe(a.lang(), args), Note: liveNote}
	inverse, err := a.edit(func(doc *document, l *Listing) ([]op, error) {
		var ops []op
		var shellHits []Bind
		for _, b := range conflicts(l.Binds, c.ID()) {
			if !fixed(b) && len(b.Actions) == 1 && sameAction(b.Actions[0], ref) {
				res.Changes = append(res.Changes, fmt.Sprintf("%s already runs %s; nothing to do", c.String(), res.Label))
				return nil, nil
			}
			if fixed(b) {
				return nil, &ConflictError{Combo: c.String(), Conflicts: conflicts(l.Binds, c.ID()), Fixed: true}
			}
			shellHits = append(shellHits, b)
		}
		if len(shellHits) > 0 {
			if !req.Replace {
				return nil, &ConflictError{Combo: c.String(), Conflicts: shellHits}
			}
			unbind, changes, err := unbindAll(doc, shellHits)
			if err != nil {
				return nil, err
			}
			ops, res.Changes = unbind, changes
		}
		core := a.Catalog.CoreFor(act.ID)
		if len(core) > 0 && !req.Additional && len(act.Args) == 0 {
			cb := core[0]
			prev, _ := doc.core(cb.Path)
			entry := coreEntry{Modifiers: c.Modifiers, Key: c.Key, Action: ActionRef{ID: act.ID, Args: map[string]any{}}}
			raw, err := rebindCore(prev, entry)
			if err != nil {
				return nil, err
			}
			ops = append(ops, op{Op: opCoreSet, Path: cb.Path, Bind: raw}, op{Op: opDisabledRemove, Path: cb.Path})
			res.Changes = append(res.Changes, fmt.Sprintf("rebound the shell's %s bind to %s", cb.Path, c.String()))
			return ops, nil
		}
		name := strings.TrimSpace(req.Name)
		if name == "" {
			name = res.Label
		}
		enabled := true
		raw, err := marshalPlain(customBind{Name: name, Keys: []Combo{c}, Actions: []customAction{{Args: args, ID: act.ID, Layouts: []string{}}}, Enabled: &enabled})
		if err != nil {
			return nil, err
		}
		ops = append(ops, op{Op: opCustomInsert, Index: len(doc.custom), Bind: raw})
		res.Changes = append(res.Changes, fmt.Sprintf("added custom bind %s → %s", c.String(), res.Label))
		return ops, nil
	})
	if err != nil {
		return nil, err
	}
	res.Undo = a.undoFor(inverse)
	return res, nil
}

// rebindCore changes the combo of a core bind, keeping its other fields
// (and their order) when it exists.
func rebindCore(prev json.RawMessage, e coreEntry) (json.RawMessage, error) {
	if prev == nil {
		return marshalPlain(e)
	}
	o, err := parseObject(prev)
	if err != nil {
		return marshalPlain(e)
	}
	mods, _ := marshalPlain(e.Modifiers)
	key, _ := marshalPlain(e.Key)
	o.set("modifiers", mods)
	o.set("key", key)
	if _, ok := o.get("action"); !ok {
		act, _ := marshalPlain(e.Action)
		o.set("action", act)
	}
	return o.marshal(), nil
}

func sameAction(x, y ActionRef) bool {
	if brand.NormalizeAction(x.ID) != brand.NormalizeAction(y.ID) {
		return false
	}
	for k, v := range y.Args {
		if fmt.Sprint(x.Args[k]) != fmt.Sprint(v) {
			return false
		}
	}
	return true
}

// Remove unbinds combo from the shell (core binds are switched off, custom
// binds lose that key). action, when set, limits it to binds running that
// action id. Compositor-config binds are never touched.
func (a *Advisor) Remove(combo, action string) (*EditResult, error) {
	c, err := ParseCombo(combo)
	if err != nil {
		return nil, err
	}
	res := &EditResult{Combo: c.String(), Note: liveNote}
	inverse, err := a.edit(func(doc *document, l *Listing) ([]op, error) {
		var hits, native []Bind
		for _, b := range conflicts(l.Binds, c.ID()) {
			if fixed(b) {
				native = append(native, b)
				continue
			}
			if action != "" && !runs(b, action) {
				continue
			}
			hits = append(hits, b)
		}
		if len(hits) == 0 {
			if len(native) > 0 && native[0].Source == SourceSpecial {
				return nil, fmt.Errorf("%s belongs to a special workspace (%s); change it with special_update / `%s special set`", c.String(), native[0].Label, brand.AppID)
			}
			if len(native) > 0 {
				return nil, fmt.Errorf("%s is bound in the compositor's own config (%s); it is not edited from here", c.String(), native[0].Label)
			}
			return nil, fmt.Errorf("nothing in binds.json is bound to %s", c.String())
		}
		ops, changes, err := unbindAll(doc, hits)
		res.Changes = changes
		return ops, err
	})
	if err != nil {
		return nil, err
	}
	res.Undo = a.undoFor(inverse)
	return res, nil
}

func runs(b Bind, action string) bool {
	for _, r := range b.Actions {
		if brand.NormalizeAction(r.ID) == brand.NormalizeAction(action) {
			return true
		}
	}
	return false
}

// Undo reverts an edit from its token; the result carries the token that
// redoes it.
func (a *Advisor) Undo(token string) (*EditResult, error) {
	ops, err := decodeToken(token)
	if err != nil {
		return nil, err
	}
	res := &EditResult{Changes: []string{"reverted the previous bind edit"}, Note: liveNote}
	inverse, err := a.edit(func(*document, *Listing) ([]op, error) { return ops, nil })
	if err != nil {
		return nil, err
	}
	res.Undo = a.undoFor(inverse)
	return res, nil
}
