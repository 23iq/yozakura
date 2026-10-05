package presets

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"

	"yozakura/backend/pkg/catalog"
)

const repoRoot = "../../.."

func newManager(t *testing.T) *Manager {
	t.Helper()
	cat, err := catalog.Load(repoRoot)
	if !assert.NoError(t, err) {
		t.FailNow()
	}
	dir := t.TempDir()
	return &Manager{
		Cat:           cat,
		Store:         &catalog.Store{Cat: cat, File: func(d string) string { return filepath.Join(dir, "config", d+".json") }},
		UserDir:       filepath.Join(dir, "presets"),
		OfficialDir:   filepath.Join(repoRoot, "assets", "presets"),
		WallpaperFile: filepath.Join(dir, "cache", "wallpapers.json"),
		StateDir:      filepath.Join(dir, "state"),
	}
}

func TestListFindApply(t *testing.T) {
	m := newManager(t)
	list := m.List()
	assert.NotEmpty(t, list)
	assert.True(t, list[0].Official, "official presets first")
	for _, p := range list {
		for _, d := range p.Domains {
			assert.False(t, Excluded[d], "%s lists excluded %s", p.Name, d)
		}
	}
	_, err := m.Find("does not exist")
	assert.ErrorContains(t, err, "presets:")
	p, err := m.Find("yozakura NIGHT")
	assert.NoError(t, err)
	assert.Equal(t, "Yozakura Night", p.Name)

	applied, problems, err := m.Apply("Yozakura Night")
	assert.NoError(t, err)
	assert.Empty(t, problems)
	assert.Equal(t, "Yozakura Night", m.Active())
	for _, d := range applied.Domains {
		want, _ := os.ReadFile(filepath.Join(applied.Path, d+".json"))
		got, err := os.ReadFile(m.Store.File(d))
		assert.NoError(t, err)
		assert.Equal(t, string(want), string(got), "files are copied verbatim")
	}
	for _, p := range m.List() {
		assert.Equal(t, p.Name == "Yozakura Night", p.Active, p.Name)
	}
}

func TestSaveExportImportDiff(t *testing.T) {
	m := newManager(t)
	_, _, err := m.Apply("Yozakura Night")
	assert.NoError(t, err)
	_, err = m.Store.Set("theme.roundness", 3.0, false)
	assert.NoError(t, err)

	saved, err := m.Save("Mine", nil, false)
	assert.NoError(t, err)
	assert.False(t, saved.Official)
	assert.Contains(t, saved.Domains, "theme")
	_, err = m.Save("Mine", nil, false)
	assert.ErrorContains(t, err, "already exists")
	_, err = m.Save("yozakura night", nil, true)
	assert.ErrorContains(t, err, "built-in")
	_, err = m.Save("../evil", nil, false)
	assert.ErrorContains(t, err, "invalid preset name")
	_, err = m.Save("x", []string{"system"}, false)
	assert.ErrorContains(t, err, "never stored")
	only, err := m.Save("Only theme", []string{"theme"}, false)
	assert.NoError(t, err)
	assert.Equal(t, []string{"theme"}, only.Domains)

	diffs, err := m.Compare("Yozakura Night", "Mine")
	assert.NoError(t, err)
	assert.Equal(t, []Diff{{Key: "theme.roundness", A: diffs[0].A, B: 3.0}}, diffs)
	diffs, err = m.Compare("Mine", Current)
	assert.NoError(t, err)
	assert.Empty(t, diffs)
	diffs, err = m.Compare("Only theme", "Mine")
	assert.NoError(t, err)
	assert.Contains(t, diffs, Diff{Key: "bar", OnlyIn: "b"})

	file := filepath.Join(t.TempDir(), "mine.json")
	b, err := m.Export("Mine", file)
	assert.NoError(t, err)
	assert.Equal(t, saved.Domains, b.DomainNames())
	raw, _ := os.ReadFile(file)
	var head map[string]any
	assert.NoError(t, json.Unmarshal(raw, &head))
	assert.Equal(t, BundleFormat, head["format"])

	imp, problems, err := m.Import(file, "Copy", false)
	assert.NoError(t, err)
	assert.Empty(t, problems)
	diffs, err = m.Compare("Copy", "Mine")
	assert.NoError(t, err)
	assert.Empty(t, diffs)
	diffs, err = m.Compare(file, "Copy")
	assert.NoError(t, err)
	assert.Empty(t, diffs, "a bundle file can be diffed directly")
	assert.Equal(t, "User", imp.Author)
	_, _, err = m.Import(file, "", false)
	assert.ErrorContains(t, err, "already exists", "defaults to the bundle name")

	cur, err := m.Export(Current, filepath.Join(t.TempDir(), "cur.json"))
	assert.NoError(t, err)
	assert.Contains(t, cur.DomainNames(), "bar")
}

func TestImportRejectsBadBundles(t *testing.T) {
	m := newManager(t)
	dir := t.TempDir()
	write := func(name, body string) string {
		p := filepath.Join(dir, name)
		assert.NoError(t, os.WriteFile(p, []byte(body), 0o644))
		return p
	}
	_, _, err := m.Import(write("a.json", `{"format":"other","version":1}`), "", false)
	assert.ErrorContains(t, err, "not a preset bundle")
	_, _, err = m.Import(write("b.json", `{"format":"`+BundleFormat+`","version":2}`), "", false)
	assert.ErrorContains(t, err, "version")
	_, _, err = m.Import(write("c.json", `{"format":"`+BundleFormat+`","version":1,"name":"C","domains":{"nope":{}}}`), "", false)
	assert.ErrorContains(t, err, "unknown config domain")
	p, problems, err := m.Import(write("d.json", `{"format":"`+BundleFormat+`","version":1,"name":"D","domains":{"bar":{"position":"up"},"ai":{}}}`), "", false)
	assert.NoError(t, err)
	assert.Equal(t, "D", p.Name)
	var msgs []string
	for _, pr := range problems {
		msgs = append(msgs, pr.Key+": "+pr.Message)
	}
	joined := strings.Join(msgs, "\n")
	assert.Contains(t, joined, "bar.position: must be one of")
	assert.Contains(t, joined, "ai: excluded")
	_, _, err = m.Import(write("e.json", `{"format":"`+BundleFormat+`","version":1,"name":"Yozakura Night","domains":{"bar":{}}}`), "", false)
	assert.ErrorContains(t, err, "built-in")
}

func TestApplyKeepsFollowedKeys(t *testing.T) {
	m := newManager(t)
	m.OfficialDir = t.TempDir()
	dir := filepath.Join(m.OfficialDir, "Paper")
	assert.NoError(t, os.MkdirAll(dir, 0o755))
	assert.NoError(t, os.WriteFile(filepath.Join(dir, "theme.json"), []byte(`{"lightMode": false, "roundness": 4}`), 0o644))
	assert.NoError(t, os.WriteFile(filepath.Join(dir, "info.json"), []byte(`{"author": "x", "follows": ["theme.lightMode", "bar.position"]}`), 0o644))
	_, err := m.Store.Set("theme.lightMode", true, false)
	assert.NoError(t, err)

	p, err := m.Find("Paper")
	assert.NoError(t, err)
	assert.Equal(t, []string{"theme.lightMode", "bar.position"}, p.Follows)
	_, problems, err := m.Apply("Paper")
	assert.NoError(t, err)
	assert.Empty(t, problems)
	got, _, _ := m.Store.Get("theme.lightMode")
	assert.Equal(t, true, got, "the live light mode survives")
	r, _, _ := m.Store.Get("theme.roundness")
	assert.Equal(t, 4.0, r, "the rest of the preset applies")
	_, err = os.Stat(m.Store.File("bar"))
	assert.True(t, os.IsNotExist(err), "a followed key of a domain the preset lacks writes nothing")

	assert.NoError(t, os.WriteFile(filepath.Join(dir, "info.json"), []byte(`{"follows": ["theme.nope"]}`), 0o644))
	_, _, err = m.Apply("Paper")
	assert.ErrorContains(t, err, "follows")
}

func TestApplyKeepsSymlinkedConfigFiles(t *testing.T) {
	m := newManager(t)
	real := filepath.Join(t.TempDir(), "dotfiles", "theme.json")
	assert.NoError(t, os.MkdirAll(filepath.Dir(real), 0o755))
	assert.NoError(t, os.WriteFile(real, []byte(`{"roundness": 3}`), 0o644))
	assert.NoError(t, os.MkdirAll(filepath.Dir(m.Store.File("theme")), 0o755))
	assert.NoError(t, os.Symlink(real, m.Store.File("theme")))
	_, _, err := m.Apply("Yozakura Night")
	assert.NoError(t, err)
	st, err := os.Lstat(m.Store.File("theme"))
	assert.NoError(t, err)
	assert.True(t, st.Mode()&os.ModeSymlink != 0, "applying a preset keeps a symlinked config file a symlink")
	data, _ := os.ReadFile(real)
	assert.NotContains(t, string(data), `"roundness": 3}`, "the link target holds the preset")
}

func TestForceSaveFailureKeepsOldPreset(t *testing.T) {
	m := newManager(t)
	_, err := m.write("Mine", map[string][]byte{"theme": []byte(`{"roundness": 4}` + "\n")}, info{Author: "User"}, false)
	assert.NoError(t, err)
	// A write that fails half way (an unwritable file name) must leave the
	// previous preset as it was.
	_, err = m.write("Mine", map[string][]byte{"bar": []byte("{}\n"), "bad\x00": []byte("{}")}, info{Author: "User"}, true)
	assert.Error(t, err)
	data, rerr := os.ReadFile(filepath.Join(m.UserDir, "Mine", "theme.json"))
	assert.NoError(t, rerr, "the old preset survives a failed overwrite")
	assert.Contains(t, string(data), `"roundness": 4`)
	_, serr := os.Stat(filepath.Join(m.UserDir, "Mine", "bar.json"))
	assert.True(t, os.IsNotExist(serr), "nothing of the failed write is visible")

	_, err = m.write("Mine", map[string][]byte{"bar": []byte("{}\n")}, info{Author: "User"}, true)
	assert.NoError(t, err)
	_, serr = os.Stat(filepath.Join(m.UserDir, "Mine", "theme.json"))
	assert.True(t, os.IsNotExist(serr), "a successful overwrite replaces the whole preset")
	entries, _ := os.ReadDir(m.UserDir)
	for _, e := range entries {
		assert.False(t, strings.HasPrefix(e.Name(), "."), "no staging dirs left: %s", e.Name())
	}
}

func TestActiveFallsBackForMissingPreset(t *testing.T) {
	m := newManager(t)
	assert.Equal(t, "", m.Active(), "no marker, no active preset")

	assert.NoError(t, os.MkdirAll(m.UserDir, 0o755))
	assert.NoError(t, os.WriteFile(m.ActiveFile(), []byte("Removed Upstream Look\n"), 0o644))
	assert.Equal(t, DefaultPreset, m.Active(), "a marker naming a removed preset falls back")
	var active []string
	for _, p := range m.List() {
		if p.Active {
			active = append(active, p.Name)
		}
	}
	assert.Equal(t, []string{DefaultPreset}, active)
	_, err := m.Find(m.Active())
	assert.NoError(t, err)

	assert.NoError(t, os.WriteFile(m.ActiveFile(), []byte("../Sumi-e\n"), 0o644))
	assert.Equal(t, DefaultPreset, m.Active(), "never resolves outside the preset dirs")
	assert.NoError(t, os.WriteFile(m.ActiveFile(), []byte("Sumi-e\n"), 0o644))
	assert.Equal(t, "Sumi-e", m.Active(), "an existing preset stays active")

	m.OfficialDir = t.TempDir()
	assert.NoError(t, os.WriteFile(m.ActiveFile(), []byte("Gone\n"), 0o644))
	assert.Equal(t, "", m.Active(), "no default to fall back to")
}
