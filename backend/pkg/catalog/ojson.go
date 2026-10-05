package catalog

import (
	"bytes"
	"encoding/json"
	"fmt"
	"strconv"
)

// Object is a JSON object that keeps its key order, so rewriting a config
// file only changes the edited lines.
type Object struct {
	keys []string
	vals map[string]any
}

// NewObject returns an empty ordered object.
func NewObject() *Object { return &Object{vals: map[string]any{}} }

// Get returns a member.
func (o *Object) Get(k string) (any, bool) {
	v, ok := o.vals[k]
	return v, ok
}

// Set adds or replaces a member (new keys go last).
func (o *Object) Set(k string, v any) {
	if _, ok := o.vals[k]; !ok {
		o.keys = append(o.keys, k)
	}
	o.vals[k] = v
}

// Delete removes a member; it reports whether it was there.
func (o *Object) Delete(k string) bool {
	if _, ok := o.vals[k]; !ok {
		return false
	}
	delete(o.vals, k)
	for i, x := range o.keys {
		if x == k {
			o.keys = append(o.keys[:i], o.keys[i+1:]...)
			break
		}
	}
	return true
}

// Keys in order.
func (o *Object) Keys() []string { return append([]string{}, o.keys...) }

// MarshalJSON writes the members in order.
func (o *Object) MarshalJSON() ([]byte, error) {
	var buf bytes.Buffer
	buf.WriteByte('{')
	for i, k := range o.keys {
		if i > 0 {
			buf.WriteByte(',')
		}
		kb, _ := json.Marshal(k)
		buf.Write(kb)
		buf.WriteByte(':')
		vb, err := json.Marshal(o.vals[k])
		if err != nil {
			return nil, err
		}
		buf.Write(vb)
	}
	buf.WriteByte('}')
	return buf.Bytes(), nil
}

// DecodeOrdered parses JSON keeping object order (objects become *Object,
// numbers json.Number).
func DecodeOrdered(data []byte) (any, error) {
	dec := json.NewDecoder(bytes.NewReader(data))
	dec.UseNumber()
	v, err := decodeValue(dec)
	if err != nil {
		return nil, err
	}
	if dec.More() {
		return nil, fmt.Errorf("trailing data after JSON value")
	}
	return v, nil
}

func decodeValue(dec *json.Decoder) (any, error) {
	tok, err := dec.Token()
	if err != nil {
		return nil, err
	}
	switch t := tok.(type) {
	case json.Delim:
		switch t {
		case '{':
			o := NewObject()
			for dec.More() {
				kt, err := dec.Token()
				if err != nil {
					return nil, err
				}
				k, _ := kt.(string)
				v, err := decodeValue(dec)
				if err != nil {
					return nil, err
				}
				o.Set(k, v)
			}
			if _, err := dec.Token(); err != nil {
				return nil, err
			}
			return o, nil
		case '[':
			arr := []any{}
			for dec.More() {
				v, err := decodeValue(dec)
				if err != nil {
					return nil, err
				}
				arr = append(arr, v)
			}
			if _, err := dec.Token(); err != nil {
				return nil, err
			}
			return arr, nil
		}
		return nil, fmt.Errorf("unexpected %v", t)
	default:
		return tok, nil
	}
}

// objectKeys returns the member names of a JSON object in order.
func objectKeys(data []byte) ([]string, error) {
	v, err := DecodeOrdered(data)
	if err != nil {
		return nil, err
	}
	o, ok := v.(*Object)
	if !ok {
		return nil, fmt.Errorf("not a JSON object")
	}
	return o.Keys(), nil
}

// Plain converts an ordered value to plain Go JSON values (map[string]any,
// []any, float64, string, bool, nil).
func Plain(v any) any {
	switch t := v.(type) {
	case *Object:
		out := make(map[string]any, len(t.keys))
		for _, k := range t.keys {
			out[k] = Plain(t.vals[k])
		}
		return out
	case []any:
		out := make([]any, len(t))
		for i, x := range t {
			out[i] = Plain(x)
		}
		return out
	case json.Number:
		f, err := strconv.ParseFloat(string(t), 64)
		if err != nil {
			return string(t)
		}
		return f
	}
	return v
}
