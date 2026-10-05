package main

import (
	"bytes"
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

func launchTestEnv(t *testing.T, have map[string]bool) (launchEnv, *[][]string) {
	t.Helper()
	dir := t.TempDir()
	for _, f := range []string{"firefox.desktop", "kde/dolphin.desktop"} {
		p := filepath.Join(dir, f)
		if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(p, []byte("[Desktop Entry]\nName=X\nExec=x %U\n"), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	var started [][]string
	return launchEnv{
		dirs: []string{filepath.Join(dir, "missing"), dir},
		lookPath: func(name string) (string, error) {
			if have[name] {
				return "/usr/bin/" + name, nil
			}
			return "", errors.New("not found")
		},
		start: func(argv []string) error { started = append(started, argv); return nil },
	}, &started
}

func TestLaunchUsesGioWithTheDesktopFile(t *testing.T) {
	env, started := launchTestEnv(t, map[string]bool{"gio": true, "gtk-launch": true})
	var errOut bytes.Buffer
	if code := runLaunch([]string{"firefox.desktop"}, env, &errOut); code != 0 {
		t.Fatalf("exit %d: %s", code, errOut.String())
	}
	if code := runLaunch([]string{"kde-dolphin"}, env, &errOut); code != 0 {
		t.Fatalf("subdirectory id: exit %d: %s", code, errOut.String())
	}
	want := [][]string{
		{"gio", "launch", filepath.Join(env.dirs[1], "firefox.desktop")},
		{"gio", "launch", filepath.Join(env.dirs[1], "kde", "dolphin.desktop")},
	}
	if !reflect.DeepEqual(*started, want) {
		t.Fatalf("started %v, want %v", *started, want)
	}
}

func TestLaunchFallsBackToGtkLaunch(t *testing.T) {
	env, started := launchTestEnv(t, map[string]bool{"gtk-launch": true})
	if code := runLaunch([]string{"firefox"}, env, &bytes.Buffer{}); code != 0 {
		t.Fatalf("exit %d", code)
	}
	if !reflect.DeepEqual(*started, [][]string{{"gtk-launch", "firefox"}}) {
		t.Fatalf("started %v", *started)
	}
}

func TestLaunchRejectsUnknownAndBadArgs(t *testing.T) {
	env, started := launchTestEnv(t, map[string]bool{"gio": true})
	for _, args := range [][]string{{}, {""}, {"--help"}, {"a", "b"}, {"nothere"}, {"../firefox"}} {
		if code := runLaunch(args, env, &bytes.Buffer{}); code == 0 {
			t.Errorf("%q: exit 0", args)
		}
	}
	if len(*started) != 0 {
		t.Fatalf("started %v", *started)
	}
}
