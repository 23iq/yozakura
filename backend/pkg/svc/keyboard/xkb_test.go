package keyboard

import (
	"path/filepath"
	"reflect"
	"testing"

	"yozakura/backend/pkg/yozd/ipc"
)

func testCatalog(t *testing.T) *Catalog {
	t.Helper()
	c, err := LoadCatalog(filepath.Join("testdata", "missing.lst"), filepath.Join("testdata", "evdev.lst"))
	if err != nil {
		t.Fatal(err)
	}
	return c
}

func TestParseRules(t *testing.T) {
	c := testCatalog(t)
	want := []Layout{
		{Name: "us", Description: "English (US)", Variants: []Variant{{"intl", "English (US, intl., with dead keys)"}}},
		{Name: "ru", Description: "Russian", Variants: []Variant{{"phonetic", "Russian (phonetic)"}, {"typo", "Russian (typewriter)"}}},
		{Name: "gb", Description: "English (UK)", Variants: []Variant{{"intl", "English (UK, intl., with dead keys)"}}},
	}
	if !reflect.DeepEqual(c.Layouts, want) {
		t.Fatalf("layouts = %+v", c.Layouts)
	}
	wantOpts := []Option{
		{Group: "grp", Name: "grp:switch", Description: "Right Alt (while pressed)"},
		{Group: "grp", Name: "grp:alt_shift_toggle", Description: "Alt+Shift"},
		{Group: "caps", Name: "caps:escape", Description: "Make Caps Lock an additional Esc"},
	}
	if !reflect.DeepEqual(c.Options, wantOpts) {
		t.Fatalf("options = %+v", c.Options)
	}
	wantGroups := []Group{{"grp", "Switching to another layout"}, {"caps", "Caps Lock behavior"}}
	if !reflect.DeepEqual(c.Groups, wantGroups) {
		t.Fatalf("groups = %+v", c.Groups)
	}
}

func TestLoadCatalogNoFile(t *testing.T) {
	if _, err := LoadCatalog(filepath.Join("testdata", "missing.lst")); err == nil {
		t.Fatal("want error")
	}
}

func TestResolveActive(t *testing.T) {
	c := testCatalog(t)
	cases := []struct {
		name string
		st   ipc.KeyboardLayoutState
		want Active
	}{
		// Hyprland: codes in Names, Index always 0, Name a description.
		{"hypr ru", ipc.KeyboardLayoutState{Names: []string{"us", "ru"}, Name: "Russian"}, Active{Name: "Russian", Index: 1, Code: "ru", Short: "RU"}},
		{"hypr us", ipc.KeyboardLayoutState{Names: []string{"us", "ru"}, Name: "English (US)"}, Active{Name: "English (US)", Index: 0, Code: "us", Short: "EN"}},
		{"hypr variant", ipc.KeyboardLayoutState{Names: []string{"us", "ru"}, Name: "Russian (phonetic)"}, Active{Name: "Russian (phonetic)", Index: 1, Code: "ru", Short: "RU"}},
		// niri: descriptions in Names, Index correct.
		{"niri", ipc.KeyboardLayoutState{Names: []string{"English (US)", "Russian"}, Index: 1, Name: "Russian"}, Active{Name: "Russian", Index: 1, Code: "ru", Short: "RU"}},
		// No names: code from the description alone.
		{"bare", ipc.KeyboardLayoutState{Name: "English (UK)"}, Active{Name: "English (UK)", Index: 0, Code: "gb", Short: "GB"}},
		{"unknown", ipc.KeyboardLayoutState{Name: "Klingon"}, Active{Name: "Klingon", Index: 0}},
	}
	for _, tc := range cases {
		if got := c.Resolve(tc.st); got != tc.want {
			t.Errorf("%s: got %+v, want %+v", tc.name, got, tc.want)
		}
	}
}
