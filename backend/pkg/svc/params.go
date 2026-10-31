package svc

import "encoding/json"

// Decode unmarshals a handler's params into T. Empty params give the zero T
// and no error (a call without params is valid); malformed JSON returns the
// decoder error. Use it when a handler reads several keys: the payload is
// parsed once into a typed struct.
func Decode[T any](raw json.RawMessage) (T, error) {
	var v T
	if len(raw) == 0 {
		return v, nil
	}
	err := json.Unmarshal(raw, &v)
	return v, err
}

// Params is a loosely typed view of a params object, parsed once. Missing
// keys, wrong types and malformed payloads all fall back to the default,
// like a handler that never fails on optional input.
type Params struct {
	m map[string]any
}

// ParseParams parses raw once. It never fails: bad input yields an empty view.
func ParseParams(raw json.RawMessage) Params {
	if len(raw) == 0 {
		return Params{}
	}
	var m map[string]any
	if json.Unmarshal(raw, &m) != nil {
		return Params{}
	}
	return Params{m: m}
}

// Str returns the string at key, or "".
func (p Params) Str(key string) string {
	v, _ := p.m[key].(string)
	return v
}

// Bool returns the bool at key, or def.
func (p Params) Bool(key string, def bool) bool {
	if v, ok := p.m[key].(bool); ok {
		return v
	}
	return def
}

// Int returns the number at key truncated to int, or def.
func (p Params) Int(key string, def int) int {
	if v, ok := p.m[key].(float64); ok {
		return int(v)
	}
	return def
}
