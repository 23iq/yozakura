package main

import (
	"bytes"
	"strings"
	"testing"

	"yozakura/backend/pkg/deps"
)

func TestPrintDoctorReportsMissing(t *testing.T) {
	var out bytes.Buffer
	items := []doctorItem{
		{name: "hyprland", need: deps.Required, ok: false, pkgs: []string{"hyprland"}},
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
