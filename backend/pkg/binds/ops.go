package binds

import (
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"reflect"
)

// Edits are lists of ops on binds.json; applying one returns its inverse,
// which is the undo token (base64 JSON). Ops locate custom binds by content
// (index first), so an undo still works after unrelated edits and refuses
// when the bind it would restore or delete was changed meanwhile.

// Op kinds.
const (
	opCustomInsert   = "custom_insert"   // insert Bind at Index
	opCustomDelete   = "custom_delete"   // delete the custom bind equal to Bind
	opCoreSet        = "core_set"        // set (Bind) or delete (no Bind) the core bind at Path
	opDisabledAdd    = "disabled_add"    // switch the core bind at Path off
	opDisabledRemove = "disabled_remove" // switch it back on
)

type op struct {
	Op    string          `json:"op"`
	Index int             `json:"index,omitempty"`
	Path  string          `json:"path,omitempty"`
	Bind  json.RawMessage `json:"bind,omitempty"`
}

// ErrStale is returned by an undo whose target changed since.
var ErrStale = errors.New("binds.json changed since; the undo no longer applies")

func sameJSON(a, b json.RawMessage) bool {
	var x, y any
	if json.Unmarshal(a, &x) != nil || json.Unmarshal(b, &y) != nil {
		return false
	}
	return reflect.DeepEqual(x, y)
}

// apply runs ops in order and returns their inverse (to run in order).
func (d *document) apply(ops []op) ([]op, error) {
	var inverse []op
	for _, o := range ops {
		inv, err := d.applyOne(o)
		if err != nil {
			return nil, err
		}
		if inv != nil {
			inverse = append([]op{*inv}, inverse...)
		}
	}
	return inverse, nil
}

func (d *document) applyOne(o op) (*op, error) {
	switch o.Op {
	case opCustomInsert:
		i := min(max(o.Index, 0), len(d.custom))
		d.custom = append(d.custom[:i], append([]json.RawMessage{o.Bind}, d.custom[i:]...)...)
		return &op{Op: opCustomDelete, Index: i, Bind: o.Bind}, nil
	case opCustomDelete:
		i := -1
		if o.Index >= 0 && o.Index < len(d.custom) && sameJSON(d.custom[o.Index], o.Bind) {
			i = o.Index
		} else {
			for j, raw := range d.custom {
				if sameJSON(raw, o.Bind) {
					i = j
					break
				}
			}
		}
		if i < 0 {
			return nil, ErrStale
		}
		removed := d.custom[i]
		d.custom = append(d.custom[:i], d.custom[i+1:]...)
		return &op{Op: opCustomInsert, Index: i, Bind: removed}, nil
	case opCoreSet:
		prev, _ := d.core(o.Path)
		if err := d.setCore(o.Path, o.Bind); err != nil {
			return nil, err
		}
		return &op{Op: opCoreSet, Path: o.Path, Bind: prev}, nil
	case opDisabledAdd:
		if d.isDisabled(o.Path) {
			return nil, nil
		}
		d.disabled = append(d.disabled, o.Path)
		return &op{Op: opDisabledRemove, Path: o.Path}, nil
	case opDisabledRemove:
		if !d.isDisabled(o.Path) {
			return nil, nil
		}
		var keep []string
		for _, p := range d.disabled {
			if p != o.Path {
				keep = append(keep, p)
			}
		}
		d.disabled = keep
		return &op{Op: opDisabledAdd, Path: o.Path}, nil
	}
	return nil, fmt.Errorf("unknown bind edit %q", o.Op)
}

type tokenBody struct {
	V   int  `json:"v"`
	Ops []op `json:"ops"`
}

func encodeToken(ops []op) string {
	if len(ops) == 0 {
		return ""
	}
	data, _ := json.Marshal(tokenBody{V: 1, Ops: ops})
	return base64.RawURLEncoding.EncodeToString(data)
}

func decodeToken(token string) ([]op, error) {
	data, err := base64.RawURLEncoding.DecodeString(token)
	if err != nil {
		return nil, fmt.Errorf("invalid undo token")
	}
	var body tokenBody
	if err := json.Unmarshal(data, &body); err != nil || body.V != 1 {
		return nil, fmt.Errorf("invalid undo token")
	}
	return body.Ops, nil
}
