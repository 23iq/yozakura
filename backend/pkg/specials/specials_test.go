package specials

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

func TestSanitizeParityWithJS(t *testing.T) {
	data, err := os.ReadFile(filepath.Join(repoRoot, "tests/fixtures/special-names.json"))
	must(t, assert.NoError(t, err))
	var cases []struct{ In, Out string }
	must(t, assert.NoError(t, json.Unmarshal(data, &cases)))
	must(t, assert.NotEmpty(t, cases))
	for _, c := range cases {
		assert.Equal(t, c.Out, SanitizeName(c.In), "%q", c.In)
	}
}

func TestHyprNamesFindAndAdd(t *testing.T) {
	list := []Special{{ID: "a", Name: "Chat"}, {ID: "b", Name: "chat"}, {ID: "c", Name: ""}}
	assert.Equal(t, map[string]string{"a": "Chat", "b": "chat-2", "c": "special-3"}, HyprNames(list))
	i, ok := Find(list, "special:chat-2")
	assert.True(t, ok)
	assert.Equal(t, 1, i)
	list, it, err := Add(list[:1], "My Notes", "", "")
	must(t, assert.NoError(t, err))
	assert.Equal(t, "my-notes", it.ID)
	assert.Equal(t, "stack", it.Icon)
	_, _, err = Add(list, "my notes", "", "")
	assert.Error(t, err, "same Hyprland name")
	_, _, err = Add(list, "  ", "", "")
	assert.Error(t, err)
}

func TestParseCombo(t *testing.T) {
	c, err := ParseCombo("SUPER + ALT + s")
	must(t, assert.NoError(t, err))
	assert.Equal(t, Combo{Modifiers: []string{"SUPER", "ALT"}, Key: "S"}, c)
	c, err = ParseCombo("super,Tab")
	must(t, assert.NoError(t, err))
	assert.Equal(t, "SUPER+Tab", FormatCombo(c))
	_, err = ParseCombo("$mainMod Y")
	assert.Error(t, err)
	assert.Equal(t, ComboID(Combo{Modifiers: []string{"ALT", "SUPER"}, Key: "s"}), ComboID(Combo{Modifiers: []string{"SUPER", "MOD1"}, Key: "S"}))
}

func TestDesktopEntries(t *testing.T) {
	dirs := []string{"testdata/apps"}
	e, ok := Lookup(dirs, "discord.desktop")
	must(t, assert.True(t, ok))
	assert.Equal(t, App{ID: "discord", Name: "Discord", Icon: "discord", Match: "discord", Command: "/usr/bin/discord --url --", IfRunning: "nothing"}, e.App())
	_, ok = FindByName(dirs, "DISCORD")
	assert.True(t, ok)
	assert.Equal(t, "app 100%", StripFieldCodes("app 100%% %F"))
}

// The migration of hand-written binds (fixture: the user's real
// keybinds.lua + a hyprland.conf-syntax file): scan, merge, comment out,
// and running it again changes nothing.
func TestImportBindsIdempotent(t *testing.T) {
	dir := t.TempDir()
	custom := filepath.Join(dir, "custom")
	must(t, assert.NoError(t, os.MkdirAll(custom, 0o755)))
	for _, f := range []string{"keybinds.lua", "legacy.conf"} {
		data, err := os.ReadFile(filepath.Join("testdata/hypr/custom", f))
		must(t, assert.NoError(t, err))
		must(t, assert.NoError(t, os.WriteFile(filepath.Join(custom, f), data, 0o644)))
	}
	files := DefaultFiles(dir)
	must(t, assert.Len(t, files, 2))

	found, warnings, err := ScanBinds(files)
	must(t, assert.NoError(t, err))
	names := []string{}
	for _, f := range found {
		names = append(names, f.Name)
	}
	assert.Equal(t, []string{"Telegram", "Discord", "Dev", "Music"}, names, "files in name order")
	assert.Len(t, warnings, 1, "the $mainMod line is reported, not imported")
	byName := map[string]Found{}
	for _, f := range found {
		byName[f.Name] = f
	}
	assert.Equal(t, Combo{Modifiers: []string{"SUPER"}, Key: "S"}, byName["Telegram"].Toggle)
	assert.Equal(t, Combo{Modifiers: []string{"SUPER", "ALT"}, Key: "S"}, byName["Telegram"].Send)
	assert.Equal(t, Combo{Modifiers: []string{"SUPER"}, Key: "C"}, byName["Dev"].Toggle)
	assert.Equal(t, Combo{Modifiers: []string{"SUPER", "SHIFT", "ALT"}, Key: "M"}, byName["Music"].Send)

	dirs := []string{"testdata/apps"}
	list, report := Merge(nil, found, dirs)
	assert.Equal(t, []string{"Telegram", "Discord", "Dev", "Music"}, report.Added)
	tg := list[0]
	assert.Equal(t, "telegram", tg.ID)
	assert.Equal(t, "telegram", tg.Icon)
	must(t, assert.Len(t, tg.Apps, 1))
	assert.Equal(t, "org.telegram.desktop", tg.Apps[0].Match)
	assert.Empty(t, tg.Apps[0].Command, "not installed: matched, never launched")
	must(t, assert.Len(t, list[1].Apps, 1))
	assert.Equal(t, "discord", list[1].Apps[0].Match)
	assert.Equal(t, "/usr/bin/discord --url --", list[1].Apps[0].Command)
	assert.Empty(t, list[2].Apps, "Dev starts empty")
	assert.Empty(t, Problems(list))

	backups, err := CommentOut(found)
	must(t, assert.NoError(t, err))
	assert.Len(t, backups, 2)
	lua, _ := os.ReadFile(filepath.Join(custom, "keybinds.lua"))
	text := string(lua)
	assert.Contains(t, text, "-- "+Marker)
	assert.Contains(t, text, `-- hl.bind("SUPER + S", hl.dsp.workspace.toggle_special("Telegram")`)
	assert.Contains(t, text, `hl.bind("SUPER + F", hl.dsp.window.fullscreen`, "other binds untouched")
	assert.Equal(t, 1, strings.Count(text, Marker))
	orig, _ := os.ReadFile("testdata/hypr/custom/keybinds.lua")
	bak, _ := os.ReadFile(filepath.Join(custom, "keybinds.lua.bak"))
	assert.Equal(t, string(orig), string(bak))
	conf, _ := os.ReadFile(filepath.Join(custom, "legacy.conf"))
	assert.Contains(t, string(conf), "# bind = SUPER SHIFT, M, togglespecialworkspace, Music")
	assert.Contains(t, string(conf), "bind = $mainMod, Y", "unreadable line left as is")

	// Second run: nothing left to import, the list is unchanged.
	again, _, err := ScanBinds(files)
	must(t, assert.NoError(t, err))
	assert.Empty(t, again)
	list2, report2 := Merge(list, again, dirs)
	assert.Equal(t, list, list2)
	assert.Empty(t, report2.Added)
	// Re-importing the same names into a list that has them keeps it.
	list3, report3 := Merge(list, found, dirs)
	assert.Equal(t, list, list3)
	assert.Len(t, report3.Kept, 4)
}

func TestConflicts(t *testing.T) {
	list := []Special{
		{ID: "telegram", Name: "Telegram", Toggle: Combo{Modifiers: []string{"SUPER"}, Key: "S"}, Send: Combo{Modifiers: []string{"SUPER", "ALT"}, Key: "S"}},
		{ID: "discord", Name: "Discord", Toggle: Combo{Modifiers: []string{"SUPER"}, Key: "D"}},
		{ID: "dev", Name: "Dev", Toggle: Combo{Modifiers: []string{"SUPER"}, Key: "C"}},
	}
	got, err := Conflicts("testdata/binds.json", list)
	must(t, assert.NoError(t, err))
	assert.Equal(t, []string{
		`SUPER+C (Dev toggle) is also the custom bind "Close Window"`,
		"SUPER+S (Telegram toggle) is also the core bind system.tools",
	}, got, "disabled core binds and disabled custom binds do not count")
	none, err := Conflicts(filepath.Join(t.TempDir(), "missing.json"), list)
	must(t, assert.NoError(t, err))
	assert.Empty(t, none)
}

func TestStoreRoundTrip(t *testing.T) {
	cat, err := catalog.Load(repoRoot)
	must(t, assert.NoError(t, err))
	dir := t.TempDir()
	s := Store{Config: &catalog.Store{Cat: cat, File: func(d string) string { return filepath.Join(dir, d+".json") }}}
	list, err := s.Load()
	must(t, assert.NoError(t, err))
	assert.Empty(t, list, "no specials by default")
	list, _, err = Add(list, "Telegram", "telegram", "primary")
	must(t, assert.NoError(t, err))
	list[0].Apps = []App{{ID: "org.telegram.desktop", Match: "org.telegram.desktop", Command: "Telegram"}}
	must(t, assert.NoError(t, s.Save(list)))
	back, err := s.Load()
	must(t, assert.NoError(t, err))
	assert.Equal(t, "nothing", back[0].Apps[0].IfRunning)
	assert.Equal(t, "Telegram", back[0].Name)
	bad := append(back, Special{ID: "x", Name: "telegram"})
	assert.Error(t, s.Save(bad), "clashing names are refused")
	back[0].Accent = "#ff0000"
	assert.Error(t, s.Save(back), "accents are palette roles")
}

// must stops the test when an assertion failed.
func must(t *testing.T, ok bool) {
	t.Helper()
	if !ok {
		t.FailNow()
	}
}

func TestAccentsMatchSchema(t *testing.T) {
	data, err := os.ReadFile(filepath.Join(repoRoot, "assets/schema/specials.schema.json"))
	must(t, assert.NoError(t, err))
	text := string(data)
	for _, a := range Accents {
		assert.Contains(t, text, `"`+a+`"`)
	}
}
