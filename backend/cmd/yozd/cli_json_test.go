package main

import "testing"

func TestMergeJSONParams(t *testing.T) {
	p := map[string]interface{}{}
	if err := mergeJSONParams(p, `{"name":"DP-1","width":1920}`); err != nil {
		t.Fatal(err)
	}
	if p["name"] != "DP-1" || p["width"] != float64(1920) {
		t.Fatalf("got %v", p)
	}
	if err := mergeJSONParams(p, `[1]`); err == nil {
		t.Fatal("array accepted")
	}
	if err := mergeJSONParams(p, `{`); err == nil {
		t.Fatal("bad json accepted")
	}
}
