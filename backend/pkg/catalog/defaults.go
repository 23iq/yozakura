package catalog

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	"yozakura/backend/pkg/mcp"
)

var dataLiteral = regexp.MustCompile(`(?s)\bvar\s+data\s*=\s*`)

// ParseDefaults extracts the `var data = {...}` literal of a
// config/defaults/<domain>.js file as JSON (key order kept).
func ParseDefaults(src string) (*Object, error) {
	var kept []string
	for _, line := range strings.Split(src, "\n") {
		t := strings.TrimSpace(line)
		if strings.HasPrefix(t, ".pragma") || strings.HasPrefix(t, ".import") {
			continue
		}
		kept = append(kept, line)
	}
	body := mcp.StripJSONC(strings.Join(kept, "\n"))
	loc := dataLiteral.FindStringIndex(body)
	if loc == nil {
		return nil, fmt.Errorf("no `var data =` literal")
	}
	lit, err := balancedObject(body[loc[1]:])
	if err != nil {
		return nil, err
	}
	v, err := DecodeOrdered([]byte(lit))
	if err != nil {
		return nil, fmt.Errorf("defaults literal is not JSON-shaped: %w", err)
	}
	o, ok := v.(*Object)
	if !ok {
		return nil, fmt.Errorf("defaults literal is not an object")
	}
	return o, nil
}

// balancedObject returns the leading {...} of s, honouring strings.
func balancedObject(s string) (string, error) {
	s = strings.TrimLeft(s, " \t\r\n")
	if s == "" || s[0] != '{' {
		return "", fmt.Errorf("defaults literal does not start with {")
	}
	depth, inStr, esc := 0, false, false
	for i := 0; i < len(s); i++ {
		c := s[i]
		if inStr {
			switch {
			case esc:
				esc = false
			case c == '\\':
				esc = true
			case c == '"':
				inStr = false
			}
			continue
		}
		switch c {
		case '"':
			inStr = true
		case '{', '[':
			depth++
		case '}', ']':
			depth--
			if depth == 0 {
				return s[:i+1], nil
			}
		}
	}
	return "", fmt.Errorf("unbalanced defaults literal")
}

// FromDefaults builds a minimal catalog (types and defaults only) from
// <root>/config/defaults/*.js; used when the generated schema is missing.
func FromDefaults(root string) (*Catalog, error) {
	dir := filepath.Join(root, "config", "defaults")
	files, err := filepath.Glob(filepath.Join(dir, "*.js"))
	if err != nil {
		return nil, err
	}
	if len(files) == 0 {
		return nil, fmt.Errorf("no config defaults found in %s", dir)
	}
	sort.Strings(files)
	c := &Catalog{entries: map[string]*Entry{}, Source: dir}
	for _, f := range files {
		data, err := os.ReadFile(f)
		if err != nil {
			continue
		}
		obj, err := ParseDefaults(string(data))
		if err != nil {
			continue
		}
		name := strings.TrimSuffix(filepath.Base(f), ".js")
		leaves := c.addDefaults(name, nil, obj)
		c.domains = append(c.domains, Domain{Name: name, Keys: leaves})
	}
	return c, nil
}

func (c *Catalog) addDefaults(domain string, path []string, obj *Object) int {
	leaves := 0
	for _, name := range obj.Keys() {
		v, _ := obj.Get(name)
		p := append(append([]string{}, path...), name)
		e := &Entry{Key: domain + "." + strings.Join(p, "."), Domain: domain, Path: p, Title: name}
		c.entries[e.Key] = e
		c.order = append(c.order, e.Key)
		if sub, ok := v.(*Object); ok {
			e.Type = "object"
			e.Children = sub.Keys()
			leaves += c.addDefaults(domain, p, sub)
			e.Default = c.defaultOf(e)
			continue
		}
		e.Default = Plain(v)
		e.Type = KindOf(e.Default)
		if e.Type == "null" {
			e.Type = "any"
		}
		leaves++
	}
	return leaves
}

// KindOf names the JSON type of a plain value.
func KindOf(v any) string {
	switch v.(type) {
	case nil:
		return "null"
	case bool:
		return "boolean"
	case float64, float32, int, int64, json.Number:
		return "number"
	case string:
		return "string"
	case []any:
		return "array"
	case map[string]any, *Object:
		return "object"
	}
	return fmt.Sprintf("%T", v)
}
