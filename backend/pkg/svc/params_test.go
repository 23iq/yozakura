package svc

import (
	"encoding/json"
	"testing"
)

func TestParams(t *testing.T) {
	p := ParseParams(json.RawMessage(`{"s":"hi","b":true,"n":42,"f":1.9,"x":"str"}`))
	if p.Str("s") != "hi" || p.Str("missing") != "" || p.Str("n") != "" {
		t.Fatal("Str")
	}
	if !p.Bool("b", false) || p.Bool("missing", true) != true || p.Bool("s", true) != true {
		t.Fatal("Bool")
	}
	if p.Int("n", 0) != 42 || p.Int("f", 0) != 1 || p.Int("missing", 7) != 7 || p.Int("x", 9) != 9 {
		t.Fatal("Int")
	}
}

func TestParamsBadInput(t *testing.T) {
	for _, raw := range []string{"", "not json", "[1,2]", "null", `"str"`} {
		p := ParseParams(json.RawMessage(raw))
		if p.Str("a") != "" || !p.Bool("a", true) || p.Int("a", 3) != 3 {
			t.Fatalf("defaults expected for %q", raw)
		}
	}
}

func TestDecode(t *testing.T) {
	type req struct {
		Name string `json:"name"`
		N    int    `json:"n"`
	}
	v, err := Decode[req](json.RawMessage(`{"name":"a","n":2}`))
	if err != nil || v.Name != "a" || v.N != 2 {
		t.Fatalf("%+v %v", v, err)
	}
	v, err = Decode[req](nil)
	if err != nil || v != (req{}) {
		t.Fatalf("empty: %+v %v", v, err)
	}
	if _, err = Decode[req](json.RawMessage(`{bad`)); err == nil {
		t.Fatal("want error")
	}
}

func TestUIRunUsesParams(t *testing.T) {
	u := NewUIService()
	if _, err := u.run(json.RawMessage(`{}`)); err == nil {
		t.Fatal("missing command must error")
	}
	if _, err := u.toggle(nil); err == nil {
		t.Fatal("missing command must error")
	}
	if r, err := u.run(json.RawMessage(`{"command":"x"}`)); err != nil || r != "ok" {
		t.Fatalf("%v %v", r, err)
	}
}
