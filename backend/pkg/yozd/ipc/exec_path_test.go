package ipc

import (
	"os"
	"path/filepath"
	"testing"
)

func TestResolveExecCommand(t *testing.T) {
	dir := t.TempDir()
	app := filepath.Join(dir, "yozakura")
	if err := os.WriteFile(app, []byte("#!/bin/sh\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	old := execBinDir
	execBinDir = func() string { return dir }
	defer func() { execBinDir = old }()

	cases := map[string]string{
		"yozakura run launcher":   app + " run launcher",
		"yozakura":                app,
		"  yozakura run notes":    app + " run notes",
		"yozd window close":       "yozd window close", // no yozd binary in dir
		"yozakura-helper x":       "yozakura-helper x",
		"kitty":                   "kitty",
		"pkill x || yozakura run": "pkill x || yozakura run",
		"":                        "",
	}
	for in, want := range cases {
		if got := ResolveExecCommand(in); got != want {
			t.Errorf("ResolveExecCommand(%q) = %q, want %q", in, got, want)
		}
	}

	spaced := filepath.Join(t.TempDir(), "my bin")
	os.MkdirAll(spaced, 0o755)
	os.WriteFile(filepath.Join(spaced, "yozakura"), []byte(""), 0o755)
	execBinDir = func() string { return spaced }
	if got, want := ResolveExecCommand("yozakura run launcher"), "'"+spaced+"/yozakura' run launcher"; got != want {
		t.Errorf("spaced dir: got %q, want %q", got, want)
	}

	execBinDir = func() string { return "" }
	if got := ResolveExecCommand("yozakura run launcher"); got != "yozakura run launcher" {
		t.Errorf("unknown dir must leave the command alone, got %q", got)
	}
}
