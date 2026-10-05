package catalog

import (
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
)

// ParseValue turns command-line text into a value of the entry's type:
//
//	boolean  true/false, on/off, yes/no, 1/0
//	number   12, 0.5, -1
//	string   taken verbatim (a JSON string literal is unquoted)
//	array    JSON (["a","b"]) or a comma list (a,b) for string/enum items
//	object   JSON ({"enabled":false}), merged member by member
//
// asJSON forces JSON parsing whatever the type.
func ParseValue(e *Entry, raw string, asJSON bool) (any, error) {
	if asJSON {
		return parseJSON(raw)
	}
	t := e.Type
	if t == "array" && e.Items == nil {
		t = "json"
	}
	switch t {
	case "boolean":
		switch strings.ToLower(strings.TrimSpace(raw)) {
		case "true", "on", "yes", "1":
			return true, nil
		case "false", "off", "no", "0":
			return false, nil
		}
		return nil, fmt.Errorf("%s is a boolean: use true or false, got %q", e.Key, raw)
	case "number":
		f, err := strconv.ParseFloat(strings.TrimSpace(raw), 64)
		if err != nil {
			return nil, fmt.Errorf("%s is a number, got %q", e.Key, raw)
		}
		return f, nil
	case "string":
		if strings.HasPrefix(raw, `"`) && strings.HasSuffix(raw, `"`) && len(raw) >= 2 {
			var s string
			if json.Unmarshal([]byte(raw), &s) == nil {
				return s, nil
			}
		}
		return raw, nil
	case "array":
		r := strings.TrimSpace(raw)
		if strings.HasPrefix(r, "[") {
			return parseJSON(r)
		}
		if r == "" {
			return []any{}, nil
		}
		if e.Items.Type != "" && e.Items.Type != "string" {
			return nil, fmt.Errorf("%s is an array of %s: pass JSON, e.g. [1,2]", e.Key, e.Items.Type)
		}
		var out []any
		for _, part := range strings.Split(r, ",") {
			out = append(out, strings.TrimSpace(part))
		}
		return out, nil
	}
	return parseJSON(raw)
}

// ParseItem parses one array element for --add/--remove.
func ParseItem(e *Entry, raw string) (any, error) {
	if e.Items != nil && (e.Items.Type == "string" || (e.Items.Type == "" && len(e.Items.Enum) > 0)) {
		return raw, nil
	}
	if v, err := parseJSON(raw); err == nil {
		return v, nil
	}
	return raw, nil
}

func parseJSON(raw string) (any, error) {
	var v any
	if err := json.Unmarshal([]byte(raw), &v); err != nil {
		return nil, fmt.Errorf("not valid JSON (%v): %s", err, raw)
	}
	return v, nil
}
