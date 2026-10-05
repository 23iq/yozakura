package main

import "testing"

func TestPathWithDir(t *testing.T) {
	cases := []struct {
		path, dir, want string
		changed         bool
	}{
		{"/usr/bin:/bin", "/home/u/.local/bin", "/usr/bin:/bin:/home/u/.local/bin", true},
		{"/usr/bin:/home/u/.local/bin", "/home/u/.local/bin", "/usr/bin:/home/u/.local/bin", false},
		{"/usr/bin:/home/u/.local/bin/", "/home/u/.local/bin", "/usr/bin:/home/u/.local/bin/", false},
		{"", "/home/u/.local/bin", "/home/u/.local/bin", true},
		{"/usr/bin:", "/opt/y", "/usr/bin:/opt/y", true},
		{"/usr/bin", "", "/usr/bin", false},
	}
	for _, c := range cases {
		got, changed := pathWithDir(c.path, c.dir)
		if got != c.want || changed != c.changed {
			t.Errorf("pathWithDir(%q, %q) = %q, %v; want %q, %v", c.path, c.dir, got, changed, c.want, c.changed)
		}
	}
}
