package main

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"yozakura/backend/pkg/deps"
)

func TestPrintDoctorReportsMissing(t *testing.T) {
	var out bytes.Buffer
	items := []doctorItem{
		{name: "hyprland", need: deps.NeedRequired, ok: false, pkgs: []string{"hyprland"}},
		{name: "cava", need: deps.Standard, ok: false, pkgs: []string{"cava"}},
		{name: "jq", need: deps.Standard, ok: true, pkgs: []string{"jq"}},
		{name: "Hyprland config", need: deps.Standard, ok: false, fix: "yozakura install hyprland"},
	}
	if code := printDoctor(&out, "arch", items, false); code != 1 {
		t.Fatalf("want exit 1 with a required dep missing, got %d", code)
	}
	s := out.String()
	for _, want := range []string{"3 missing (1 required)", "sudo pacman -S --needed hyprland cava", "yozakura install hyprland"} {
		if !strings.Contains(s, want) {
			t.Errorf("output lacks %q:\n%s", want, s)
		}
	}
	if strings.Contains(s, " jq ") {
		t.Errorf("present deps are hidden without -v:\n%s", s)
	}
}

func TestPrintDoctorAllGood(t *testing.T) {
	var out bytes.Buffer
	if code := printDoctor(&out, "fedora", []doctorItem{{name: "jq", need: deps.Standard, ok: true}}, true); code != 0 {
		t.Fatalf("got %d", code)
	}
	if !strings.Contains(out.String(), "Everything is in place") {
		t.Fatal(out.String())
	}
}

func TestDoctorRejectsUnknownFlags(t *testing.T) {
	if code := runDoctor([]string{"--bogus"}, &bytes.Buffer{}); code != 2 {
		t.Fatalf("got %d", code)
	}
}

func TestDoctorDepsScopedToCompositor(t *testing.T) {
	c := &deps.Checker{Distro: "arch", LookPath: func(string) (string, error) { return "", os.ErrNotExist }, Glob: func(string) ([]string, error) { return nil, nil }, Fonts: func() string { return "" }}
	names := func(comp string) map[string]string {
		m := map[string]string{}
		for _, it := range doctorDeps(c, map[string]bool{}, comp) {
			m[it.name] = it.need
		}
		return m
	}
	n := names("niri")
	if n["niri"] != deps.NeedRequired || n["xwayland-satellite"] != deps.Standard || n["hyprland"] != "" || n["portal-hyprland"] != "" || n["polkit-agent"] != deps.Standard {
		t.Errorf("niri: %v", n)
	}
	h := names("hyprland")
	if h["hyprland"] != deps.NeedRequired || h["portal-hyprland"] != deps.Standard || h["niri"] != "" {
		t.Errorf("hyprland: %v", h)
	}
}

func TestNormalizeCompositor(t *testing.T) {
	for in, want := range map[string]string{"niri\n": "niri", " Mango ": "mango", "hyprland": "hyprland", "": "hyprland", "sway": "hyprland"} {
		if got := normalizeCompositor(in); got != want {
			t.Errorf("%q: got %s want %s", in, got, want)
		}
	}
}

func TestReadCompositor(t *testing.T) {
	dir := t.TempDir()
	if got := readCompositor(dir); got != "hyprland" {
		t.Errorf("missing file: %s", got)
	}
	if err := os.WriteFile(filepath.Join(dir, "compositor"), []byte("niri\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if got := readCompositor(dir); got != "niri" {
		t.Errorf("got %s", got)
	}
}
