package binds

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"strings"

	"yozakura/backend/pkg/fsutil"
)

// binds.json is edited as raw JSON with its key order kept, so a write
// changes only what it means to: untouched entries keep their bytes and
// the file keeps the shell's layout (2-space JSON, same key order).

// object is a JSON object that remembers its key order.
type object struct {
	keys []string
	vals map[string]json.RawMessage
}

func newObject() *object { return &object{vals: map[string]json.RawMessage{}} }

func parseObject(data []byte) (*object, error) {
	dec := json.NewDecoder(bytes.NewReader(data))
	tok, err := dec.Token()
	if err != nil {
		return nil, err
	}
	if d, ok := tok.(json.Delim); !ok || d != '{' {
		return nil, fmt.Errorf("not a JSON object")
	}
	o := newObject()
	for dec.More() {
		tok, err := dec.Token()
		if err != nil {
			return nil, err
		}
		key, _ := tok.(string)
		var raw json.RawMessage
		if err := dec.Decode(&raw); err != nil {
			return nil, err
		}
		o.set(key, raw)
	}
	if _, err := dec.Token(); err != nil {
		return nil, err
	}
	return o, nil
}

func (o *object) get(key string) (json.RawMessage, bool) {
	v, ok := o.vals[key]
	return v, ok
}

func (o *object) set(key string, v json.RawMessage) {
	if _, ok := o.vals[key]; !ok {
		o.keys = append(o.keys, key)
	}
	o.vals[key] = v
}

func (o *object) del(key string) {
	if _, ok := o.vals[key]; !ok {
		return
	}
	delete(o.vals, key)
	for i, k := range o.keys {
		if k == key {
			o.keys = append(o.keys[:i], o.keys[i+1:]...)
			break
		}
	}
}

func (o *object) marshal() json.RawMessage {
	var b bytes.Buffer
	b.WriteByte('{')
	for i, k := range o.keys {
		if i > 0 {
			b.WriteByte(',')
		}
		kb, _ := json.Marshal(k)
		b.Write(kb)
		b.WriteByte(':')
		b.Write(o.vals[k])
	}
	b.WriteByte('}')
	return b.Bytes()
}

// marshalPlain encodes v without HTML escaping (the shell writes "<", ">"
// and "&" as they are).
func marshalPlain(v any) (json.RawMessage, error) {
	var b bytes.Buffer
	enc := json.NewEncoder(&b)
	enc.SetEscapeHTML(false)
	if err := enc.Encode(v); err != nil {
		return nil, err
	}
	return bytes.TrimRight(b.Bytes(), "\n"), nil
}

// document is a loaded binds.json.
type document struct {
	root     *object
	appID    string
	custom   []json.RawMessage
	disabled []string
	trailNL  bool
	newFile  bool
}

func loadDocument(path, appID string) (*document, error) {
	d := &document{appID: appID}
	data, err := os.ReadFile(path)
	if os.IsNotExist(err) || (err == nil && len(bytes.TrimSpace(data)) == 0) {
		d.root, d.newFile = newObject(), true
		return d, nil
	}
	if err != nil {
		return nil, err
	}
	d.trailNL = bytes.HasSuffix(data, []byte("\n"))
	if d.root, err = parseObject(data); err != nil {
		return nil, fmt.Errorf("%s: %w", path, err)
	}
	if raw, ok := d.root.get("custom"); ok {
		if err := json.Unmarshal(raw, &d.custom); err != nil {
			return nil, fmt.Errorf("%s: custom: %w", path, err)
		}
	}
	if raw, ok := d.root.get("disabled"); ok {
		if err := json.Unmarshal(raw, &d.disabled); err != nil {
			return nil, fmt.Errorf("%s: disabled: %w", path, err)
		}
	}
	return d, nil
}

// bytes renders the document like the shell does (2-space JSON).
func (d *document) bytes() ([]byte, error) {
	custom := d.custom
	if custom == nil {
		custom = []json.RawMessage{}
	}
	disabled := d.disabled
	if disabled == nil {
		disabled = []string{}
	}
	c, err := marshalPlain(custom)
	if err != nil {
		return nil, err
	}
	dis, err := marshalPlain(disabled)
	if err != nil {
		return nil, err
	}
	d.root.set("custom", c)
	d.root.set("disabled", dis)
	var compact, out bytes.Buffer
	if err := json.Compact(&compact, d.root.marshal()); err != nil {
		return nil, err
	}
	if err := json.Indent(&out, compact.Bytes(), "", "  "); err != nil {
		return nil, err
	}
	if d.trailNL || d.newFile {
		out.WriteByte('\n')
	}
	return out.Bytes(), nil
}

func (d *document) save(path string) error {
	data, err := d.bytes()
	if err != nil {
		return err
	}
	return fsutil.WriteFile(path, data, 0o644)
}

// core returns the raw core bind at path ("launcher", "system.tools").
func (d *document) core(path string) (json.RawMessage, bool) {
	holder, name, ok := d.coreHolder(path, false)
	if !ok {
		return nil, false
	}
	return holder.get(name)
}

// setCore replaces (raw != nil) or deletes the core bind at path.
func (d *document) setCore(path string, raw json.RawMessage) error {
	holder, name, ok := d.coreHolder(path, true)
	if !ok {
		return fmt.Errorf("binds.json: cannot reach core bind %s", path)
	}
	if raw == nil {
		holder.del(name)
	} else {
		holder.set(name, raw)
	}
	return d.storeHolder(path, holder)
}

func (d *document) coreHolder(path string, create bool) (*object, string, bool) {
	appRaw, ok := d.root.get(d.appID)
	var app *object
	if ok {
		var err error
		if app, err = parseObject(appRaw); err != nil {
			return nil, "", false
		}
	} else if create {
		app = newObject()
	} else {
		return nil, "", false
	}
	section, name, nested := strings.Cut(path, ".")
	if !nested {
		return app, path, true
	}
	secRaw, ok := app.get(section)
	if !ok {
		if !create {
			return nil, "", false
		}
		return newObject(), name, true
	}
	sec, err := parseObject(secRaw)
	if err != nil {
		return nil, "", false
	}
	return sec, name, true
}

// storeHolder writes a modified holder back under the app root.
func (d *document) storeHolder(path string, holder *object) error {
	section, _, nested := strings.Cut(path, ".")
	if !nested {
		d.root.set(d.appID, holder.marshal())
		return nil
	}
	app := newObject()
	if appRaw, ok := d.root.get(d.appID); ok {
		var err error
		if app, err = parseObject(appRaw); err != nil {
			return err
		}
	}
	app.set(section, holder.marshal())
	d.root.set(d.appID, app.marshal())
	return nil
}

func (d *document) isDisabled(path string) bool {
	for _, p := range d.disabled {
		if p == path {
			return true
		}
	}
	return false
}
