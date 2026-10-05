package main

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"sync/atomic"
	"testing"
)

const fakeMatugen = `{"colors":{
 "primary":{"dark":{"color":"#ffb1c3"},"default":{"color":"#ffb1c3"},"light":{"color":"#9a405b"}},
 "on_primary":{"dark":{"color":"#5e1129"},"light":{"color":"#ffffff"}},
 "surface_container_high":{"dark":{"color":"#2b2124"},"light":{"color":"#f2dde1"}},
 "not_a_preview_role":{"dark":{"color":"#000000"}}
}}`

func TestShellRoleName(t *testing.T) {
	cases := map[string]string{
		"primary":                "primary",
		"on_primary":             "overPrimary",
		"surface_container_high": "surfaceContainerHigh",
		"on_surface_variant":     "overSurfaceVariant",
	}
	for in, want := range cases {
		if got := shellRoleName(in); got != want {
			t.Errorf("shellRoleName(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestParseSchemePalette(t *testing.T) {
	p, err := parseSchemePalette([]byte(fakeMatugen))
	if err != nil {
		t.Fatal(err)
	}
	if p["dark"]["primary"] != "#ffb1c3" || p["light"]["primary"] != "#9a405b" {
		t.Fatalf("primary not parsed: %v", p)
	}
	if p["dark"]["overPrimary"] != "#5e1129" || p["dark"]["surfaceContainerHigh"] != "#2b2124" {
		t.Fatalf("roles not mapped: %v", p["dark"])
	}
	if _, ok := p["dark"]["notAPreviewRole"]; ok {
		t.Fatal("unexpected role kept")
	}
	if _, err := parseSchemePalette([]byte(`{"colors":{}}`)); err == nil {
		t.Fatal("empty palette must fail")
	}
	if _, err := parseSchemePalette([]byte(`nope`)); err == nil {
		t.Fatal("invalid json must fail")
	}
}

func TestRunSchemesCachesPerImageVersion(t *testing.T) {
	dir := t.TempDir()
	image := filepath.Join(dir, "wall.png")
	if err := os.WriteFile(image, []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}
	var calls atomic.Int32
	orig := matugenPalette
	defer func() { matugenPalette = orig }()
	matugenPalette = func(img, scheme string) ([]byte, error) {
		calls.Add(1)
		if scheme == "scheme-rainbow" {
			return nil, errors.New("boom")
		}
		return []byte(fakeMatugen), nil
	}

	cache := filepath.Join(dir, "cache")
	stdout := os.Stdout
	devnull, _ := os.Open(os.DevNull)
	os.Stdout = devnull
	defer func() { os.Stdout = stdout }()

	if code := runSchemes([]string{image}, cache); code != 0 {
		t.Fatalf("exit %d", code)
	}
	first := calls.Load()
	if int(first) != len(validMatugenSchemes) {
		t.Fatalf("expected one matugen run per scheme, got %d", first)
	}
	entries, _ := os.ReadDir(cache)
	if len(entries) != 1 {
		t.Fatalf("expected one cache file, got %d", len(entries))
	}
	data, _ := os.ReadFile(filepath.Join(cache, entries[0].Name()))
	var doc struct {
		Schemes map[string]map[string]map[string]string `json:"schemes"`
	}
	if err := json.Unmarshal(data, &doc); err != nil {
		t.Fatal(err)
	}
	if _, ok := doc.Schemes["scheme-rainbow"]; ok {
		t.Fatal("failed scheme must be left out")
	}
	if doc.Schemes["scheme-tonal-spot"]["light"]["primary"] != "#9a405b" {
		t.Fatalf("cached palette wrong: %v", doc.Schemes["scheme-tonal-spot"])
	}

	if code := runSchemes([]string{image}, cache); code != 0 {
		t.Fatalf("exit %d", code)
	}
	if calls.Load() != first {
		t.Fatal("second run must hit the cache")
	}

	if code := runSchemes([]string{filepath.Join(dir, "missing.png")}, cache); code == 0 {
		t.Fatal("missing image must fail")
	}
}
