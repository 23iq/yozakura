package main

import (
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"
)

func TestUpdateArgsWithoutInstaller(t *testing.T) {
	if args := updateArgs(t.TempDir(), ""); args != nil {
		t.Fatalf("want nil without install.sh, got %v", args)
	}
}

func TestUpdateArgsReinstallsNextToBinary(t *testing.T) {
	src := t.TempDir()
	if err := os.WriteFile(filepath.Join(src, "install.sh"), []byte("#!/bin/sh\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	bin := t.TempDir()
	args := updateArgs(src, filepath.Join(bin, "app"))
	want := []string{filepath.Join(src, "install.sh"), "--update", "--dir", src, "--bin-dir", bin}
	if !slices.Equal(args, want) {
		t.Fatalf("got %v, want %v", args, want)
	}
}

func TestUpdateArgsSkipsReadOnlyBinDir(t *testing.T) {
	src := t.TempDir()
	if err := os.WriteFile(filepath.Join(src, "install.sh"), nil, 0o755); err != nil {
		t.Fatal(err)
	}
	args := updateArgs(src, "/nonexistent-dir/app")
	if slices.Contains(args, "--bin-dir") {
		t.Fatalf("unwritable dir must fall back to the installer default: %v", args)
	}
}

func TestInstallerURL(t *testing.T) {
	url := installerURL()
	if !strings.HasPrefix(url, "https://raw.githubusercontent.com/") || !strings.HasSuffix(url, "/main/install.sh") {
		t.Fatalf("unexpected installer URL %q", url)
	}
}
