package catalog

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
)

// repoRoot holds assets/schema and config/defaults.
const repoRoot = "../../.."

func load(t *testing.T) *Catalog {
	t.Helper()
	c, err := Load(repoRoot)
	must(t, err)
	return c
}

func TestGeneratedCatalogMatchesDefaults(t *testing.T) {
	c := load(t)
	assert.Contains(t, c.Source, SchemaFile)
	raw, err := FromDefaults(repoRoot)
	must(t, err)
	assert.Equal(t, raw.DomainNames(), c.DomainNames(), "one schema domain per config/defaults file")
	for _, e := range raw.Keys("", true) {
		g, ok := c.Entry(e.Key)
		if !assert.True(t, ok, "%s missing from the generated catalog (run `make schema`)", e.Key) {
			continue
		}
		assert.Equal(t, Compact(e.Default), Compact(g.Default), "default of %s", e.Key)
		if e.Type != "any" {
			assert.Equal(t, e.Type, g.Type, "type of %s", e.Key)
		}
	}
	assert.Equal(t, len(raw.Keys("", false)), len(c.Keys("", false)))
}

func TestEveryKeyIsDescribed(t *testing.T) {
	for _, e := range load(t).Keys("", true) {
		assert.NotEmpty(t, e.Title, e.Key)
		assert.NotEmpty(t, e.Description, e.Key)
	}
}

func TestBuiltinPresetsValidate(t *testing.T) {
	c := load(t)
	// sets and their parts: assets/presets/{sets,layouts,styles,palettes}/<Name>/
	files, _ := filepath.Glob(filepath.Join(repoRoot, "assets", "presets", "*", "*", "*.json"))
	legacy, _ := filepath.Glob(filepath.Join(repoRoot, "assets", "presets", "*", "*.json"))
	files = append(files, legacy...)
	mustTrue(t, len(files) > 0)
	for _, f := range files {
		domain := strings.TrimSuffix(filepath.Base(f), ".json")
		if !c.HasDomain(domain) {
			continue
		}
		data, err := os.ReadFile(f)
		must(t, err)
		var doc any
		must(t, json.Unmarshal(data, &doc), f)
		for _, p := range c.ValidateDocument(domain, doc) {
			if strings.Contains(p.Message, "unknown key") {
				continue // stale keys in presets are dropped by the shell
			}
			t.Errorf("%s: %s: %s (catalog range/enum too strict?)", f, p.Key, p.Message)
		}
	}
}

func TestEntryMetadata(t *testing.T) {
	c := load(t)
	e, ok := c.Entry("bar.position")
	mustTrue(t, ok)
	assert.Equal(t, "string", e.Type)
	assert.Equal(t, []any{"top", "bottom", "left", "right"}, e.Enum)
	assert.NotNil(t, e.Settings)
	assert.Equal(t, "bar", e.Settings.Category)
	assert.Equal(t, "Bar & Islands", c.CategoryTitle("bar"))

	r, _ := c.Entry("theme.roundness")
	assert.Equal(t, 0.0, *r.Min)
	assert.Equal(t, 24.0, *r.Max, "config/meta range wins over the slider range")

	left, _ := c.Entry("bar.layout.left")
	assert.Contains(t, left.Items.Enum, "clock")
	assert.True(t, left.UniqueItems)

	act, _ := c.Entry("notch.liveActivities")
	assert.Equal(t, "object", act.Type)
	assert.Contains(t, act.Children, "maxVisible")
	def := act.Default.(map[string]any)
	assert.Equal(t, 4.0, def["maxVisible"])

	sec, _ := c.Entry("notch.liveActivities.downloads.secrets.deluge")
	assert.True(t, sec.Secret)
	lbl, _ := c.Entry("theme.srBg.label")
	assert.True(t, lbl.ReadOnly)
}

func TestParseDefaultsLenient(t *testing.T) {
	d, err := ParseDefaults(`.pragma library
.import "x.js" as X
// header
var data = {
    "url": "https://example.com//x", // trailing
    "list": [1, 2,],
    "b": {"z": 1, "a": 2},
};
function helper() { return {}; }
`)
	must(t, err)
	assert.Equal(t, []string{"url", "list", "b"}, d.Keys())
	m := Plain(d).(map[string]any)
	assert.Equal(t, "https://example.com//x", m["url"])
	assert.Len(t, m["list"], 2)
	b, _ := d.Get("b")
	assert.Equal(t, []string{"z", "a"}, b.(*Object).Keys(), "nested order kept")
}

func TestLookup(t *testing.T) {
	c := load(t)
	r, err := c.Lookup(" bar.layout.left[2] ")
	must(t, err)
	assert.Equal(t, "bar.layout.left", r.Entry.Key)
	assert.Equal(t, 2, r.Index)
	r, err = c.Lookup("bar.position")
	must(t, err)
	assert.Equal(t, -1, r.Index)

	_, err = c.Lookup("bar.positon")
	assert.ErrorContains(t, err, "did you mean bar.position")
	_, err = c.Lookup("nope.x")
	assert.ErrorContains(t, err, "unknown config domain")
	_, err = c.Lookup("theme.mode")
	assert.ErrorContains(t, err, "theme.lightMode")
	_, err = c.Lookup("bar.position.0")
	assert.Error(t, err, "index on a non-array")
	_, err = c.Lookup("")
	assert.ErrorContains(t, err, "domains:")
}

func TestAssignValidation(t *testing.T) {
	c := load(t)
	cases := []struct {
		key   string
		value any
		err   string
	}{
		{"bar.position", "bottom", ""},
		{"bar.position", "up", "must be one of top, bottom, left, right"},
		{"bar.position", 3.0, "must be a string"},
		{"theme.roundness", 24.0, ""},
		{"theme.roundness", 25.0, "must be in 0..24"},
		{"theme.animDuration", 0.0, ""},
		{"compositor.shadowOffset", "2 -3", ""},
		{"compositor.shadowOffset", "2,3", "must match"},
		{"bar.layout.left", []any{"clock", "launcher"}, ""},
		{"bar.layout.left", []any{"clock", "clock"}, "duplicate"},
		{"bar.layout.left", []any{"clock", "zzz"}, "bar.layout.left[1] must be one of"},
		{"bar.screenList", []any{1.0}, "must be a string"},
		{"notch.liveActivities", map[string]any{"enabled": false}, ""},
		{"notch.liveActivities", map[string]any{"bogus": 1.0}, "unknown key notch.liveActivities.bogus"},
		{"notch.liveActivities", "x", "must be an object"},
		{"theme.srBg.label", "x", "read-only"},
		{"theme.glass.amount", 0.5, ""},
		{"theme.glass.amount", -1.0, ""},
		{"theme.glass.amount", 1.5, "must be in 0..1 or -1"},
		{"theme.glass.advanced.opacity", -1.0, ""},
		{"theme.glass.advanced.opacity", -2.0, "or -1"},
		{"theme.glass.surfaces.dock.amount", -1.0, ""},
		{"theme.glass.surfaces.windows.activeOpacity", 0.2, "0.3..1"},
	}
	for _, tc := range cases {
		leaves, err := c.Assign(tc.key, tc.value, false)
		if tc.err == "" {
			assert.NoError(t, err, tc.key)
			assert.NotEmpty(t, leaves, tc.key)
		} else {
			assert.ErrorContains(t, err, tc.err, tc.key)
		}
	}
	_, err := c.Assign("theme.roundness", 99.0, true)
	assert.NoError(t, err, "force skips the range")
	_, err = c.Assign("theme.roundness", "x", true)
	assert.Error(t, err, "force never skips the type")
}

func TestParseValue(t *testing.T) {
	c := load(t)
	get := func(k string) *Entry { e, _ := c.Entry(k); return e }
	v, err := ParseValue(get("bar.compact"), "on", false)
	assert.NoError(t, err)
	assert.Equal(t, true, v)
	_, err = ParseValue(get("bar.compact"), "maybe", false)
	assert.Error(t, err)
	v, _ = ParseValue(get("theme.roundness"), "12.5", false)
	assert.Equal(t, 12.5, v)
	_, err = ParseValue(get("theme.roundness"), "big", false)
	assert.Error(t, err)
	v, _ = ParseValue(get("theme.font"), "Inter Display", false)
	assert.Equal(t, "Inter Display", v)
	v, _ = ParseValue(get("theme.font"), `"quoted"`, false)
	assert.Equal(t, "quoted", v)
	v, _ = ParseValue(get("bar.layout.left"), "launcher, clock", false)
	assert.Equal(t, []any{"launcher", "clock"}, v)
	v, _ = ParseValue(get("bar.layout.left"), `["a"]`, false)
	assert.Equal(t, []any{"a"}, v)
	v, _ = ParseValue(get("bar.layout.left"), "", false)
	assert.Equal(t, []any{}, v)
	v, _ = ParseValue(get("notch.liveActivities"), `{"enabled":false}`, false)
	assert.Equal(t, map[string]any{"enabled": false}, v)
	v, _ = ParseValue(get("bar.position"), `"x"`, true)
	assert.Equal(t, "x", v)
	_, err = ParseValue(get("layout.dashboard.grid.cells"), "surface", false)
	assert.Error(t, err, "arrays without item type need JSON")
	it, _ := ParseItem(get("bar.layout.left"), "clock")
	assert.Equal(t, "clock", it)
}

func TestSearch(t *testing.T) {
	c := load(t)
	top := func(q string) []string {
		var keys []string
		for _, h := range c.Search(q, 5) {
			keys = append(keys, h.Entry.Key)
		}
		return keys
	}
	assert.Contains(t, top("rounded corners"), "theme.roundness")
	assert.Contains(t, top("gaps"), "compositor.gapsIn")
	assert.Contains(t, top("dark mode"), "theme.lightMode")
	assert.Equal(t, "bar.position", top("bar position")[0])
	assert.Empty(t, c.Search("   ", 5))
	assert.Empty(t, c.Search("zzzqqq", 5))
}

func must(t *testing.T, err error, msg ...any) {
	t.Helper()
	if !assert.NoError(t, err, msg...) {
		t.FailNow()
	}
}

func mustTrue(t *testing.T, ok bool, msg ...any) {
	t.Helper()
	if !assert.True(t, ok, msg...) {
		t.FailNow()
	}
}
