package catalog

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"

	"yozakura/backend/pkg/fsutil"
)

// Store reads and writes the live config files
// ($XDG_CONFIG_HOME/<app>/config/<domain>.json). Writes are atomic
// (temp file + rename, like the shell's FileView atomicWrites) and keep
// key order and 2-space indentation, so the running shell's file watcher
// hot-applies them and the user's file diff stays minimal.
type Store struct {
	Cat  *Catalog
	File func(domain string) string
}

// Change is one key whose value changed.
type Change struct {
	Key string `json:"key"`
	Old any    `json:"old"`
	New any    `json:"new"`
}

func (s *Store) read(domain string) (*Object, error) {
	data, err := os.ReadFile(s.File(domain))
	if err != nil {
		if os.IsNotExist(err) {
			return NewObject(), nil
		}
		return nil, err
	}
	v, err := DecodeOrdered(data)
	if err != nil {
		return nil, fmt.Errorf("%s: %w", s.File(domain), err)
	}
	o, ok := v.(*Object)
	if !ok {
		return nil, fmt.Errorf("%s: not a JSON object", s.File(domain))
	}
	return o, nil
}

func (s *Store) write(domain string, doc *Object) error {
	data, err := json.MarshalIndent(doc, "", "  ")
	if err != nil {
		return err
	}
	return fsutil.WriteFile(s.File(domain), data, 0o644)
}

// Current is the effective document of a domain: the file merged over the
// defaults (what the shell runs with).
func (s *Store) Current(domain string) (map[string]any, error) {
	if !s.Cat.HasDomain(domain) {
		return nil, fmt.Errorf("unknown config domain %q (domains: %s)", domain, strings.Join(s.Cat.DomainNames(), ", "))
	}
	doc, err := s.read(domain)
	if err != nil {
		return nil, err
	}
	merged, _ := mergeDefaults(s.Cat.DomainDefault(domain), Plain(doc)).(map[string]any)
	return merged, nil
}

// mergeDefaults overlays file values on defaults, object by object.
func mergeDefaults(def, cur any) any {
	dm, ok1 := def.(map[string]any)
	cm, ok2 := cur.(map[string]any)
	if !ok1 || !ok2 {
		if cur == nil {
			return def
		}
		return cur
	}
	out := map[string]any{}
	for k, v := range dm {
		out[k] = v
	}
	for k, v := range cm {
		out[k] = mergeDefaults(dm[k], v)
	}
	return out
}

// Get returns the effective value of a key and whether the file sets it.
func (s *Store) Get(key string) (value any, explicit bool, err error) {
	ref, err := s.Cat.Lookup(key)
	if err != nil {
		return nil, false, err
	}
	e := ref.Entry
	cur, err := s.Current(e.Domain)
	if err != nil {
		return nil, false, err
	}
	value, _ = getPath(cur, e.Path)
	doc, _ := s.read(e.Domain)
	_, explicit = getPath(Plain(doc), e.Path)
	if ref.Index >= 0 {
		arr, _ := value.([]any)
		if ref.Index >= len(arr) {
			return nil, explicit, fmt.Errorf("%s has %d items, no index %d", e.Key, len(arr), ref.Index)
		}
		return arr[ref.Index], explicit, nil
	}
	return value, explicit, nil
}

// Set validates and writes a value; it returns what changed.
func (s *Store) Set(key string, value any, force bool) ([]Change, error) {
	domain, leaves, err := s.resolve(key, value, force)
	if err != nil {
		return nil, err
	}
	return s.apply(domain, leaves)
}

// Check validates a value exactly like Set without writing it.
func (s *Store) Check(key string, value any, force bool) error {
	_, _, err := s.resolve(key, value, force)
	return err
}

// KV is one key and its new value (SetAll).
type KV struct {
	Key   string
	Value any
}

// SetAll validates every value first and then writes them all in one
// atomic write: nothing is written when any value is invalid. All keys must
// belong to one domain; force skips enum/range checks like Set.
func (s *Store) SetAll(values []KV, force bool) ([]Change, error) {
	domain := ""
	var all []Leaf
	for _, kv := range values {
		d, leaves, err := s.resolve(kv.Key, kv.Value, force)
		if err != nil {
			return nil, err
		}
		if domain != "" && d != domain {
			return nil, fmt.Errorf("SetAll: %s is not in domain %s", kv.Key, domain)
		}
		domain = d
		all = append(all, leaves...)
	}
	if domain == "" {
		return nil, nil
	}
	return s.apply(domain, all)
}

// resolve validates a value for key and returns its domain and leaves.
func (s *Store) resolve(key string, value any, force bool) (string, []Leaf, error) {
	ref, err := s.Cat.Lookup(key)
	if err != nil {
		return "", nil, err
	}
	e := ref.Entry
	if ref.Index >= 0 {
		whole, _, err := s.Get(e.Key)
		if err != nil {
			return "", nil, err
		}
		arr, _ := clone(whole).([]any)
		switch {
		case ref.Index < len(arr):
			arr[ref.Index] = value
		case ref.Index == len(arr):
			arr = append(arr, value)
		default:
			return "", nil, fmt.Errorf("%s has %d items; index %d is out of range", e.Key, len(arr), ref.Index)
		}
		value = arr
	}
	leaves, err := s.Cat.Assign(e.Key, value, force)
	if err != nil {
		return "", nil, err
	}
	return e.Domain, leaves, nil
}

func (s *Store) apply(domain string, leaves []Leaf) ([]Change, error) {
	doc, err := s.read(domain)
	if err != nil {
		return nil, err
	}
	cur, err := s.Current(domain)
	if err != nil {
		return nil, err
	}
	var changes []Change
	dirty := false
	plain := Plain(doc)
	for _, l := range leaves {
		old, _ := getPath(cur, l.Path)
		if equalJSON(old, l.Value) {
			if _, set := getPath(plain, l.Path); set {
				continue
			}
		} else {
			changes = append(changes, Change{Key: l.Key(domain), Old: old, New: l.Value})
		}
		setOrdered(doc, l.Path, l.Value)
		dirty = true
	}
	if !dirty {
		return changes, nil
	}
	if err := s.write(domain, doc); err != nil {
		return nil, err
	}
	return changes, nil
}

// Reset writes the default of a key (or of every leaf under an object key).
func (s *Store) Reset(key string) ([]Change, error) {
	ref, err := s.Cat.Lookup(key)
	if err != nil {
		return nil, err
	}
	if ref.Index >= 0 {
		return nil, fmt.Errorf("reset the whole array (%s), not one item", ref.Entry.Key)
	}
	var leaves []Leaf
	for _, e := range s.Cat.Keys(ref.Entry.Key, true) {
		leaves = append(leaves, Leaf{Path: e.Path, Value: clone(e.Default)})
	}
	return s.apply(ref.Entry.Domain, leaves)
}

// ResetDomain rewrites a whole domain file with its defaults.
func (s *Store) ResetDomain(domain string) ([]Change, error) {
	cur, err := s.Current(domain)
	if err != nil {
		return nil, err
	}
	doc := NewObject()
	var changes []Change
	for _, e := range s.Cat.Keys(domain, true) {
		old, _ := getPath(cur, e.Path)
		if !equalJSON(old, e.Default) {
			changes = append(changes, Change{Key: e.Key, Old: old, New: e.Default})
		}
	}
	for _, k := range s.Cat.TopKeys(domain) {
		e, _ := s.Cat.Entry(domain + "." + k)
		setOrdered(doc, []string{k}, toOrdered(s.Cat, e, clone(s.Cat.defaultOf(e))))
	}
	return changes, s.write(domain, doc)
}

// WriteDocument replaces a domain file with doc (preset apply).
func (s *Store) WriteDocument(domain string, doc any) error {
	v, err := json.Marshal(doc)
	if err != nil {
		return err
	}
	o, err := DecodeOrdered(v)
	if err != nil {
		return err
	}
	obj, ok := o.(*Object)
	if !ok {
		return fmt.Errorf("%s: document is not an object", domain)
	}
	return s.write(domain, obj)
}

// toOrdered converts a default object into catalog (file) order.
func toOrdered(c *Catalog, e *Entry, v any) any {
	m, ok := v.(map[string]any)
	if !ok || e == nil || e.Leaf() {
		return v
	}
	o := NewObject()
	for _, name := range e.Children {
		child, _ := c.Entry(e.Key + "." + name)
		o.Set(name, toOrdered(c, child, m[name]))
	}
	return o
}

func getPath(doc any, path []string) (any, bool) {
	cur := doc
	for _, p := range path {
		m, ok := cur.(map[string]any)
		if !ok {
			return nil, false
		}
		cur, ok = m[p]
		if !ok {
			return nil, false
		}
	}
	return cur, true
}

// SetOrdered sets a nested key of an ordered document (missing objects are
// created, key order kept).
func SetOrdered(doc *Object, path []string, v any) { setOrdered(doc, path, v) }

// GetOrdered reads a nested key of an ordered document.
func GetOrdered(doc *Object, path []string) (any, bool) {
	var cur any = doc
	for _, p := range path {
		o, ok := cur.(*Object)
		if !ok {
			return nil, false
		}
		if cur, ok = o.Get(p); !ok {
			return nil, false
		}
	}
	return cur, true
}

// DeleteOrdered removes a nested key; it reports whether it was there.
func DeleteOrdered(doc *Object, path []string) bool {
	cur := doc
	for _, p := range path[:len(path)-1] {
		next, ok := cur.vals[p].(*Object)
		if !ok {
			return false
		}
		cur = next
	}
	return cur.Delete(path[len(path)-1])
}

func setOrdered(doc *Object, path []string, v any) {
	cur := doc
	for _, p := range path[:len(path)-1] {
		next, ok := cur.vals[p].(*Object)
		if !ok {
			next = NewObject()
			cur.Set(p, next)
		}
		cur = next
	}
	cur.Set(path[len(path)-1], v)
}
