package apphooks

import (
	"bytes"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"strings"
)

type discordHook struct{}

func init() { Register(discordHook{}) }

func (discordHook) ID() string { return "discord" }

// dirs lists the existing Vesktop/Vencord-style config directories.
func (discordHook) dirs(env Env) []string {
	cands := []string{
		filepath.Join(env.ConfigHome, "vesktop"),
		filepath.Join(env.ConfigHome, "equibop"),
		filepath.Join(env.ConfigHome, "Equicord"),
		filepath.Join(env.ConfigHome, "Vencord"),
		filepath.Join(env.Home, ".var", "app", "dev.vencord.Vesktop", "config", "vesktop"),
	}
	var out []string
	for _, d := range cands {
		if st, err := os.Stat(d); err == nil && st.IsDir() {
			out = append(out, filepath.Join(d, "settings", "settings.json"))
		}
	}
	return out
}

func themeName(env Env) string { return env.AppID + ".css" }

// object is a JSON object keeping key order and raw values.
type object struct {
	keys []string
	vals map[string]json.RawMessage
}

var errNotObject = errors.New("settings.json is not a JSON object")

func parseObject(data []byte) (*object, error) {
	dec := json.NewDecoder(bytes.NewReader(data))
	if t, err := dec.Token(); err != nil || t != json.Delim('{') {
		return nil, errNotObject
	}
	o := &object{vals: map[string]json.RawMessage{}}
	for dec.More() {
		kt, err := dec.Token()
		if err != nil {
			return nil, err
		}
		var raw json.RawMessage
		if err := dec.Decode(&raw); err != nil {
			return nil, err
		}
		k := kt.(string)
		if _, dup := o.vals[k]; !dup {
			o.keys = append(o.keys, k)
		}
		o.vals[k] = raw
	}
	if _, err := dec.Token(); err != nil {
		return nil, err
	}
	if dec.More() {
		return nil, errNotObject
	}
	return o, nil
}

func (o *object) set(k string, v any) {
	raw, _ := json.Marshal(v)
	if _, ok := o.vals[k]; !ok {
		o.keys = append(o.keys, k)
	}
	o.vals[k] = raw
}

func (o *object) del(k string) {
	delete(o.vals, k)
	for i, key := range o.keys {
		if key == k {
			o.keys = append(o.keys[:i], o.keys[i+1:]...)
			return
		}
	}
}

func (o *object) marshal(trailingNL bool) []byte {
	var b bytes.Buffer
	b.WriteByte('{')
	for i, k := range o.keys {
		if i > 0 {
			b.WriteByte(',')
		}
		kb, _ := json.Marshal(k)
		b.Write(kb)
		b.WriteByte(':')
		_ = json.Compact(&b, o.vals[k])
	}
	b.WriteByte('}')
	var out bytes.Buffer
	_ = json.Indent(&out, b.Bytes(), "", "  ")
	if trailingNL {
		out.WriteByte('\n')
	}
	return out.Bytes()
}

// themes returns enabledThemes (nil when missing).
func (o *object) themes() ([]string, error) {
	raw, ok := o.vals["enabledThemes"]
	if !ok {
		return nil, nil
	}
	var l []string
	if err := json.Unmarshal(raw, &l); err != nil {
		return nil, err
	}
	return l, nil
}

func contains(l []string, s string) bool {
	for _, x := range l {
		if x == s {
			return true
		}
	}
	return false
}

// load reads one settings file; a missing file is an empty object.
func loadSettings(path string) (o *object, trailingNL, existed bool, err error) {
	data, rerr := os.ReadFile(path)
	if errors.Is(rerr, os.ErrNotExist) {
		return &object{vals: map[string]json.RawMessage{}}, true, false, nil
	}
	if rerr != nil {
		return nil, false, false, rerr
	}
	o, err = parseObject(data)
	return o, strings.HasSuffix(string(data), "\n"), true, err
}

func (h discordHook) Status(env Env) Status {
	st := Status{ID: h.ID(), Files: h.dirs(env)}
	if len(st.Files) == 0 {
		st.State, st.Files = StateAbsent, nil
		return st
	}
	connected, managed := 0, 0
	for _, f := range st.Files {
		o, _, _, err := loadSettings(f)
		var l []string
		if err == nil {
			l, err = o.themes()
		}
		if err != nil {
			st.State, st.Reason = StateError, "parse: "+f
			return st
		}
		if contains(l, themeName(env)) {
			connected++
		} else if isManaged(f) {
			managed++
		}
	}
	switch {
	case connected == len(st.Files):
		st.State = StateConnected
	case managed > 0:
		st.State, st.Reason = StateManaged, "settings.json is read-only or in the Nix store; enable the "+themeName(env)+" theme in the client"
	default:
		st.State = StateDisconnected
	}
	return st
}

func hadKeyMark(id, path string) string { return "hadThemes:" + id + ":" + path }

// edit adds or removes our theme in every client's settings.json. A client
// that fails (read-only, unreadable) does not stop the others; the result
// aggregates them.
func (h discordHook) edit(env Env, add bool) (Status, error) {
	st := h.Status(env)
	if st.State == StateAbsent || st.State == StateError {
		return st, nil
	}
	changedAny := false
	var firstErr error
	allManaged := true
	for _, f := range st.Files {
		changed, err := h.editOne(env, f, add)
		if err != nil {
			if firstErr == nil {
				firstErr = err
			}
			allManaged = allManaged && errors.Is(err, ErrManaged)
			continue
		}
		changedAny = changedAny || changed
	}
	out := h.Status(env)
	out.NeedsRestart = changedAny && env.running("vesktop", "equibop", "Discord", "discord")
	if firstErr != nil {
		if allManaged {
			out.State, out.Reason = StateManaged, ErrManaged.Error()
		} else {
			out.State, out.Reason = StateError, firstErr.Error()
		}
		return out, firstErr
	}
	return out, nil
}

func (h discordHook) editOne(env Env, f string, add bool) (bool, error) {
	o, nl, existed, err := loadSettings(f)
	if err != nil {
		return false, err
	}
	l, _ := o.themes()
	name := themeName(env)
	if contains(l, name) == add {
		if !add { // nothing of ours left: drop the bookkeeping
			setMark(env, hadKeyMark(h.ID(), f), false)
			setMark(env, createdKey(h.ID(), f), false)
		}
		return false, nil
	}
	_, hadKey := o.vals["enabledThemes"]
	if add {
		setMark(env, hadKeyMark(h.ID(), f), hadKey)
		o.set("enabledThemes", append(append([]string{}, l...), name))
	} else {
		kept := []string{}
		for _, x := range l {
			if x != name {
				kept = append(kept, x)
			}
		}
		if len(kept) == 0 && !hasMark(env, hadKeyMark(h.ID(), f)) {
			o.del("enabledThemes")
		} else {
			o.set("enabledThemes", kept)
		}
	}
	if err := h.write(env, f, o, nl, existed, add); err != nil {
		return false, err
	}
	if !add {
		setMark(env, hadKeyMark(h.ID(), f), false)
		setMark(env, createdKey(h.ID(), f), false)
	}
	return true, nil
}

func (h discordHook) write(env Env, path string, o *object, nl, existed, add bool) error {
	if len(o.keys) == 0 && !add && hasMark(env, createdKey(h.ID(), path)) {
		return removeFile(path) // revert of a file Apply created
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil && !isManaged(path) {
		return err
	}
	if err := WriteFileSafe(path, o.marshal(nl)); err != nil {
		return err
	}
	if add {
		setMark(env, createdKey(h.ID(), path), !existed)
	}
	return nil
}

func (h discordHook) Apply(env Env) (Status, error)  { return h.edit(env, true) }
func (h discordHook) Revert(env Env) (Status, error) { return h.edit(env, false) }
