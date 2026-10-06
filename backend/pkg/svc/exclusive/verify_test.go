package exclusive

import (
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"yozakura/backend/pkg/exclusive"
)

func fakeHyprland(t *testing.T, script string) {
	dir := t.TempDir()
	if script != "" {
		p := filepath.Join(dir, "Hyprland")
		if err := os.WriteFile(p, []byte("#!/bin/sh\n"+script), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	t.Setenv("PATH", dir)
	hyprlandBin = "Hyprland"
}

func TestVerifyConfigClean(t *testing.T) {
	fakeHyprland(t, `[ "$1" = --verify-config ] && [ "$2" = -c ] || exit 3
printf 'DEBUG noise\n\n======== Config parsing result:\n\nconfig ok\n'`)
	warn, err := verifyConfig("/x/hyprland.lua")
	if err != nil || warn != "" {
		t.Fatalf("clean: %q %v", warn, err)
	}
}

func TestVerifyConfigErrors(t *testing.T) {
	fakeHyprland(t, `printf '======== Config parsing result:\n\nConfig error in file /x line 3: bad value\nConfig error in file /x line 9: worse\n'`)
	_, err := verifyConfig("/x/hyprland.conf")
	if err == nil || !strings.Contains(err.Error(), "line 3: bad value; Config error in file /x line 9") {
		t.Fatalf("want config errors, got %v", err)
	}
}

func TestVerifyConfigFlagUnsupportedOrMissing(t *testing.T) {
	fakeHyprland(t, `echo "usage: Hyprland [arg]"; exit 1`)
	warn, err := verifyConfig("/x")
	if err != nil || !strings.Contains(warn, "checked on next Hyprland start") || !strings.Contains(warn, "install --restore") {
		t.Fatalf("unsupported: %q %v", warn, err)
	}
	fakeHyprland(t, "")
	warn, err = verifyConfig("/x")
	if err != nil || !strings.Contains(warn, "Hyprland not found") {
		t.Fatalf("missing: %q %v", warn, err)
	}
}

func TestReloadWithoutCompositorIsNoCompositor(t *testing.T) {
	if err := reloadWith(&fakeYozd{nameErr: errors.New("refused")}); !errors.Is(err, exclusive.ErrNoCompositor) {
		t.Fatalf("%v", err)
	}
	if err := reloadWith(&fakeYozd{name: "niri"}); !errors.Is(err, exclusive.ErrNoCompositor) {
		t.Fatalf("%v", err)
	}
}
