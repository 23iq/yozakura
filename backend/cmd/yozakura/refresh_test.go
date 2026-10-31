package main

import "testing"

func TestProfileElement(t *testing.T) {
	cases := []struct {
		name, json, want string
	}{
		{"by name", `{"elements":{"yozakura":{"storePaths":["/nix/store/aaaa-other-1"]}},"version":3}`, "yozakura"},
		{"by store path", `{"elements":{"hello":{"storePaths":["/nix/store/bbbb-hello-2.12"]},"default":{"storePaths":["/nix/store/cccc-yozakura-0.1.3"]}},"version":3}`, "default"},
		{"legacy capitalised name", `{"elements":{"x":{"storePaths":["/nix/store/dddd-Yozakura-0.1.2"]}},"version":3}`, "x"},
		{"sibling packages", `{"elements":{"a":{"storePaths":["/nix/store/eeee-yozakura-sddm-theme-0.1.3"]},"b":{"storePaths":["/nix/store/ffff-yozakura-env"]}},"version":3}`, ""},
		{"absent", `{"elements":{"hello":{"storePaths":["/nix/store/bbbb-hello-2.12"]}},"version":3}`, ""},
		{"garbage", `not json`, ""},
	}
	for _, c := range cases {
		if got := profileElement([]byte(c.json)); got != c.want {
			t.Errorf("%s: got %q, want %q", c.name, got, c.want)
		}
	}
}
