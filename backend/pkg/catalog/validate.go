package catalog

import (
	"encoding/json"
	"fmt"
	"regexp"
	"sort"
	"strconv"
	"strings"
)

// Leaf is one validated assignment inside a domain file.
type Leaf struct {
	Path  []string
	Value any
}

// Key is the full dotted key of the leaf.
func (l Leaf) Key(domain string) string { return domain + "." + strings.Join(l.Path, ".") }

// Ref is a resolved user key: an entry plus an optional array index
// ("bar.layout.left.0" / "bar.layout.left[0]").
type Ref struct {
	Entry *Entry
	Index int // -1 when the key addresses the whole value
}

// NormalizeKey turns "a.b[2]" into "a.b.2" and trims spaces/dots.
func NormalizeKey(key string) string {
	key = strings.TrimSpace(key)
	key = strings.ReplaceAll(key, "[", ".")
	key = strings.ReplaceAll(key, "]", "")
	return strings.Trim(key, ".")
}

// Lookup resolves a key, with helpful errors (known domains, closest keys).
func (c *Catalog) Lookup(key string) (Ref, error) {
	key = NormalizeKey(key)
	if key == "" {
		return Ref{}, fmt.Errorf("empty key; use <domain>.<key>, e.g. bar.position (domains: %s)", strings.Join(c.DomainNames(), ", "))
	}
	if e, ok := c.entries[key]; ok {
		return Ref{Entry: e, Index: -1}, nil
	}
	if i := strings.LastIndex(key, "."); i > 0 {
		if n, err := strconv.Atoi(key[i+1:]); err == nil {
			if e, ok := c.entries[key[:i]]; ok && e.Type == "array" {
				if n < 0 {
					return Ref{}, fmt.Errorf("%s: negative index", key)
				}
				return Ref{Entry: e, Index: n}, nil
			}
		}
	}
	domain := strings.SplitN(key, ".", 2)[0]
	if !c.HasDomain(domain) {
		return Ref{}, fmt.Errorf("unknown config domain %q (domains: %s)", domain, strings.Join(c.DomainNames(), ", "))
	}
	var group []string
	for _, k := range c.order {
		if e := c.entries[k]; e.Settings != nil && e.Settings.Entry == key {
			group = append(group, k)
		}
	}
	if len(group) > 0 {
		return Ref{}, fmt.Errorf("%s is a settings control for several keys: %s", key, strings.Join(group, ", "))
	}
	msg := fmt.Sprintf("unknown key %s", key)
	if s := c.Suggest(key, 3); len(s) > 0 {
		msg += "; did you mean " + strings.Join(s, ", ") + "?"
	}
	return Ref{}, fmt.Errorf("%s (see `config list %s`)", msg, domain)
}

// Assign validates value for key and returns the leaf assignments.
// Objects may be partial (each given member is checked). force skips the
// enum/range/pattern checks but never the type check.
func (c *Catalog) Assign(key string, value any, force bool) ([]Leaf, error) {
	ref, err := c.Lookup(key)
	if err != nil {
		return nil, err
	}
	if ref.Index >= 0 {
		return nil, fmt.Errorf("%s addresses an array element; set it through the config store", key)
	}
	var out []Leaf
	if err := c.check(ref.Entry, value, force, &out); err != nil {
		return nil, err
	}
	return out, nil
}

func (c *Catalog) check(e *Entry, v any, force bool, out *[]Leaf) error {
	if e.ReadOnly && !force {
		return fmt.Errorf("%s is read-only", e.Key)
	}
	if e.Type == "object" {
		m, ok := v.(map[string]any)
		if !ok {
			return fmt.Errorf("%s must be an object of {%s}, got %s", e.Key, strings.Join(e.Children, ", "), describeKind(v))
		}
		names := make([]string, 0, len(m))
		for k := range m {
			names = append(names, k)
		}
		sort.Strings(names)
		for _, k := range names {
			child, ok := c.entries[e.Key+"."+k]
			if !ok {
				return fmt.Errorf("unknown key %s.%s; valid keys: %s", e.Key, k, strings.Join(e.Children, ", "))
			}
			if err := c.check(child, m[k], force, out); err != nil {
				return err
			}
		}
		return nil
	}
	if err := CheckValue(e, v, force); err != nil {
		return err
	}
	*out = append(*out, Leaf{Path: append([]string{}, e.Path...), Value: v})
	return nil
}

// CheckValue validates a leaf value: type, then (unless force) enum,
// range, pattern and array items.
func CheckValue(e *Entry, v any, force bool) error {
	k := KindOf(v)
	if e.Type != "any" && k != e.Type {
		return fmt.Errorf("%s must be a %s (default %s), got %s", e.Key, e.Type, Compact(e.Default), describeKind(v))
	}
	if force {
		return nil
	}
	if err := checkScalar(e.Key, v, e.Enum, e.Min, e.Max, e.Pattern, specialValues(e)); err != nil {
		return err
	}
	arr, ok := v.([]any)
	if !ok {
		return nil
	}
	seen := map[string]bool{}
	for i, item := range arr {
		where := fmt.Sprintf("%s[%d]", e.Key, i)
		if e.Items != nil {
			if e.Items.Type != "" && KindOf(item) != e.Items.Type {
				return fmt.Errorf("%s must be a %s, got %s", where, e.Items.Type, describeKind(item))
			}
			if err := checkScalar(where, item, e.Items.Enum, nil, nil, "", nil); err != nil {
				return err
			}
		}
		if e.UniqueItems {
			id := Compact(item)
			if seen[id] {
				return fmt.Errorf("%s: duplicate item %s", e.Key, id)
			}
			seen[id] = true
		}
	}
	return nil
}

func specialValues(e *Entry) []any {
	var out []any
	for _, s := range e.Special {
		out = append(out, s.Value)
	}
	return out
}

func checkScalar(where string, v any, enum []any, lo, hi *float64, pattern string, special []any) error {
	for _, s := range special {
		if equalJSON(s, v) {
			return nil
		}
	}
	if len(enum) > 0 {
		for _, x := range enum {
			if equalJSON(x, v) {
				return nil
			}
		}
		return fmt.Errorf("%s must be one of %s, got %s", where, EnumList(enum), Compact(v))
	}
	if f, ok := v.(float64); ok {
		if lo != nil && f < *lo || hi != nil && f > *hi {
			alt := ""
			if len(special) > 0 {
				alt = " or " + EnumList(special)
			}
			return fmt.Errorf("%s must be in %s%s, got %s", where, Range(lo, hi), alt, Compact(v))
		}
	}
	if s, ok := v.(string); ok && pattern != "" {
		if re, err := regexp.Compile(pattern); err == nil && !re.MatchString(s) {
			return fmt.Errorf("%s must match %s, got %q", where, pattern, s)
		}
	}
	return nil
}

// EnumList renders allowed values ("top, bottom").
func EnumList(enum []any) string {
	parts := make([]string, len(enum))
	for i, v := range enum {
		parts[i] = Scalar(v)
	}
	return strings.Join(parts, ", ")
}

// Range renders a numeric range.
func Range(lo, hi *float64) string {
	f := func(p *float64) string {
		if p == nil {
			return ""
		}
		return strconv.FormatFloat(*p, 'f', -1, 64)
	}
	switch {
	case lo != nil && hi != nil:
		return f(lo) + ".." + f(hi)
	case lo != nil:
		return ">= " + f(lo)
	case hi != nil:
		return "<= " + f(hi)
	}
	return "any"
}

func describeKind(v any) string {
	return KindOf(v) + " " + Compact(v)
}

// equalJSON compares two values by their full JSON (Compact truncates, so
// long arrays with a common prefix would compare equal).
func equalJSON(a, b any) bool {
	da, errA := json.Marshal(a)
	db, errB := json.Marshal(b)
	if errA != nil || errB != nil {
		return fmt.Sprint(a) == fmt.Sprint(b)
	}
	return string(da) == string(db)
}

// Compact is a short single-line JSON rendering.
func Compact(v any) string {
	data, err := json.Marshal(v)
	if err != nil {
		return fmt.Sprint(v)
	}
	if len(data) > 120 {
		return string(data[:117]) + "..."
	}
	return string(data)
}

// Scalar renders strings bare and everything else as JSON.
func Scalar(v any) string {
	if s, ok := v.(string); ok {
		return s
	}
	data, _ := json.Marshal(v)
	return string(data)
}

// Problem is one finding of ValidateDocument.
type Problem struct {
	Key     string `json:"key"`
	Message string `json:"message"`
}

// ValidateDocument checks a whole domain document (e.g. a preset file):
// unknown keys and invalid values. Missing keys are fine (the shell fills
// them with defaults).
func (c *Catalog) ValidateDocument(domain string, doc any) []Problem {
	m, ok := doc.(map[string]any)
	if !ok {
		return []Problem{{Key: domain, Message: "must be a JSON object"}}
	}
	var out []Problem
	var walk func(prefix string, m map[string]any)
	walk = func(prefix string, m map[string]any) {
		names := make([]string, 0, len(m))
		for k := range m {
			names = append(names, k)
		}
		sort.Strings(names)
		for _, k := range names {
			key := prefix + "." + k
			e, ok := c.entries[key]
			if !ok {
				out = append(out, Problem{Key: key, Message: "unknown key (ignored by the shell)"})
				continue
			}
			if sub, ok := m[k].(map[string]any); ok && e.Type == "object" {
				walk(key, sub)
				continue
			}
			if e.Type == "object" {
				out = append(out, Problem{Key: key, Message: "must be an object"})
				continue
			}
			if err := CheckValue(e, m[k], false); err != nil {
				out = append(out, Problem{Key: key, Message: strings.TrimPrefix(err.Error(), key+" ")})
			}
		}
	}
	walk(domain, m)
	return out
}
