package main

import (
	"bytes"
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"

	"yozakura/backend/pkg/brand"
)

func TestParseCLI(t *testing.T) {
	a := parseCLI([]string{"set", "theme.terminalOpacity", "-1", "--force", "--add=x", "--name", "My Look", "--", "--json"},
		[]string{"force", "json"}, []string{"add", "name"})
	assert.Equal(t, []string{"set", "theme.terminalOpacity", "-1", "--json"}, a.pos)
	assert.True(t, a.has("force"))
	assert.False(t, a.has("json"))
	v, _ := a.value("add")
	assert.Equal(t, "x", v)
	v, _ = a.value("name")
	assert.Equal(t, "My Look", v)
}

// sandbox points every XDG dir at a temp dir and the shell source at the repo.
func sandbox(t *testing.T) string {
	home := t.TempDir()
	t.Setenv("HOME", home)
	for _, v := range []string{"XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_STATE_HOME", "XDG_CACHE_HOME", "XDG_RUNTIME_DIR"} {
		t.Setenv(v, filepath.Join(home, strings.ToLower(v)))
	}
	root, _ := filepath.Abs("../../..")
	t.Setenv(brand.EnvPrefix+"SHELL", root)
	return home
}

func run(t *testing.T, f func([]string, *bytes.Buffer, *bytes.Buffer) int, args ...string) (int, string, string) {
	t.Helper()
	var out, errOut bytes.Buffer
	code := f(args, &out, &errOut)
	return code, out.String(), errOut.String()
}

func cfg(args []string, out, errOut *bytes.Buffer) int    { return runConfig(args, out, errOut) }
func preset(args []string, out, errOut *bytes.Buffer) int { return runPreset(args, out, errOut) }

func TestConfigCommands(t *testing.T) {
	home := sandbox(t)
	code, out, _ := run(t, cfg, "list")
	assert.Equal(t, 0, code)
	assert.Contains(t, out, "theme ")

	code, out, _ = run(t, cfg, "get", "bar.position")
	assert.Equal(t, 0, code)
	assert.Equal(t, "top\n", out)

	code, out, _ = run(t, cfg, "set", "bar.position", "left")
	assert.Equal(t, 0, code)
	assert.Equal(t, "bar.position: \"top\" -> \"left\"\n", out)
	data, err := os.ReadFile(filepath.Join(home, "xdg_config_home", brand.AppID, "config", "bar.json"))
	assert.NoError(t, err)
	assert.Contains(t, string(data), `"position": "left"`)

	code, _, errOut := run(t, cfg, "set", "bar.position", "up")
	assert.Equal(t, 1, code)
	assert.Contains(t, errOut, "must be one of")

	code, out, _ = run(t, cfg, "set", "theme.terminalOpacity", "0.5")
	assert.Equal(t, 0, code, out)
	code, out, _ = run(t, cfg, "set", "theme.terminalOpacity", "-1")
	assert.Equal(t, 0, code, "negative numbers are values, not flags")
	assert.Contains(t, out, "-> -1")

	code, out, _ = run(t, cfg, "set", "bar.layout.left", "--add", "clock")
	assert.Equal(t, 0, code)
	assert.Contains(t, out, `"pin","clock"]`)
	code, out, _ = run(t, cfg, "set", "bar.layout.left", "--remove", "pin")
	assert.Equal(t, 0, code)
	assert.NotContains(t, strings.SplitN(out, "->", 2)[1], "pin")
	code, _, errOut = run(t, cfg, "set", "bar.layout.left", "--remove", "pin")
	assert.Equal(t, 1, code)
	assert.Contains(t, errOut, "does not contain")

	code, out, _ = run(t, cfg, "set", "bar.compact", "true", "--dry-run")
	assert.Equal(t, 0, code)
	assert.Contains(t, out, "dry run")
	_, out, _ = run(t, cfg, "get", "bar.compact")
	assert.Equal(t, "false\n", out)
	code, out, _ = run(t, cfg, "toggle", "bar.compact")
	assert.Equal(t, 0, code)
	assert.Equal(t, "bar.compact: false -> true\n", out)

	code, out, _ = run(t, cfg, "describe", "bar.layout.style")
	assert.Equal(t, 0, code)
	assert.Contains(t, out, "allowed:   classic, islands")
	assert.Contains(t, out, "settings:  Bar & Islands")
	code, out, _ = run(t, cfg, "describe", "bar.position", "--json")
	assert.Equal(t, 0, code)
	assert.Contains(t, out, `"current": "left"`)

	code, out, _ = run(t, cfg, "search", "rounded", "corners", "-n", "3")
	assert.Equal(t, 0, code)
	assert.Contains(t, out, "theme.roundness")

	code, _, errOut = run(t, cfg, "reset", "bar")
	assert.Equal(t, 1, code)
	assert.Contains(t, errOut, "--yes")
	code, out, _ = run(t, cfg, "reset", "bar", "--yes")
	assert.Equal(t, 0, code)
	assert.Contains(t, out, "bar.position: \"left\" -> \"top\"")
	code, out, _ = run(t, cfg, "list", "notch.liveActivities", "--json")
	assert.Equal(t, 0, code)
	assert.Contains(t, out, `"key": "notch.liveActivities.enabled"`)

	code, out, _ = run(t, cfg, "schema", "notch")
	assert.Equal(t, 0, code)
	assert.Contains(t, out, `"$schema": "https://json-schema.org/draft/2020-12/schema"`)
	code, out, _ = run(t, cfg, "__values", "bar.position")
	assert.Equal(t, 0, code)
	assert.Equal(t, "top\nbottom\nleft\nright\n", out)
	code, _, errOut = run(t, cfg, "nope")
	assert.Equal(t, 1, code)
	assert.Contains(t, errOut, "unknown config command")
}

func TestPresetCommands(t *testing.T) {
	home := sandbox(t)
	code, out, _ := run(t, preset)
	assert.Equal(t, 0, code)
	assert.Contains(t, out, "[official]")
	code, out, _ = run(t, preset, "Yozakura", "Night")
	assert.Equal(t, 0, code, "legacy form applies")
	assert.Contains(t, out, "Preset applied: Yozakura Night")
	_, out, _ = run(t, preset, "active")
	assert.Equal(t, "Yozakura Night\n", out)
	run(t, cfg, "set", "theme.roundness", "2")
	code, out, _ = run(t, preset, "diff", "Yozakura Night", "current")
	assert.Equal(t, 0, code)
	assert.Contains(t, out, "theme.roundness:")
	code, out, _ = run(t, preset, "save", "Mine", "--domains", "theme,bar")
	assert.Equal(t, 0, code)
	assert.Contains(t, out, "Saved preset Mine (bar, theme)")
	file := filepath.Join(home, "mine.json")
	code, _, _ = run(t, preset, "export", "Mine", file)
	assert.Equal(t, 0, code)
	code, out, _ = run(t, preset, "import", file, "--name", "Copy")
	assert.Equal(t, 0, code)
	assert.Contains(t, out, "Imported preset Copy")
	code, out, _ = run(t, preset, "diff", "Mine", "Copy")
	assert.Equal(t, 0, code)
	assert.Equal(t, "No differences.\n", out)
	code, _, errOut := run(t, preset, "apply", "nope")
	assert.Equal(t, 1, code)
	assert.Contains(t, errOut, "no preset")
}

func TestCompletionScripts(t *testing.T) {
	for _, sh := range []string{"bash", "zsh", "fish"} {
		var out, errOut bytes.Buffer
		assert.Equal(t, 0, runCompletion([]string{sh}, &out, &errOut), sh)
		s := out.String()
		assert.Contains(t, s, brand.AppID+" config __keys", sh)
		assert.Contains(t, s, brand.AppID+" preset __names", sh)
		for _, ph := range []string{"{bin}", "{top}", "{configSubs}", "{presetSubs}", "{keyedSubs}", "{keyedSubsBash}"} {
			assert.NotContains(t, s, ph, sh)
		}
		if path, err := exec.LookPath(sh); err == nil {
			f := filepath.Join(t.TempDir(), "c."+sh)
			assert.NoError(t, os.WriteFile(f, []byte(s), 0o644))
			o, err := exec.Command(path, "-n", f).CombinedOutput()
			assert.NoError(t, err, "%s -n: %s", sh, o)
		}
	}
	var out, errOut bytes.Buffer
	assert.Equal(t, 2, runCompletion([]string{"tcsh"}, &out, &errOut))
}

func TestPresetStudioCommands(t *testing.T) {
	sandbox(t)
	code, out, _ := run(t, preset, "list", "--json")
	assert.Equal(t, 0, code)
	var list []map[string]any
	assert.NoError(t, json.Unmarshal([]byte(out), &list))
	assert.NotEmpty(t, list[0]["tags"])
	assert.NotEmpty(t, list[0]["look"])
	assert.NotEmpty(t, list[0]["hash"])

	code, out, _ = run(t, preset, "aspects", "--json")
	assert.Equal(t, 0, code)
	assert.Contains(t, out, `"id": "layout"`)

	code, out, _ = run(t, preset, "duplicate", "Neon Tokyo", "Neon Mine")
	assert.Equal(t, 0, code, out)
	assert.Contains(t, out, "Created preset Neon Mine")
	code, _, errOut := run(t, preset, "edit", "Neon Tokyo")
	assert.Equal(t, 1, code)
	assert.Contains(t, errOut, "read-only")

	code, out, _ = run(t, preset, "mix", "Blend", "--layout", "Kaze", "--colors", "Neon Mine", "--json")
	assert.Equal(t, 0, code, out)
	assert.Contains(t, out, `"name": "Blend"`)
	code, out, _ = run(t, preset, "show", "Blend")
	assert.Equal(t, 0, code)
	assert.Contains(t, out, "same as Kaze")
	assert.Contains(t, out, "not set (keeps your values)")
	code, out, _ = run(t, preset, "show", "Blend", "--json", "--against", "Kaze")
	assert.Equal(t, 0, code)
	assert.Contains(t, out, `"against": "Kaze"`)

	code, out, _ = run(t, preset, "rename", "Blend", "Blend 2")
	assert.Equal(t, 0, code, out)
	code, out, _ = run(t, preset, "delete", "Blend 2", "--json")
	assert.Equal(t, 0, code, out)
	var tr map[string]any
	assert.NoError(t, json.Unmarshal([]byte(out), &tr))
	code, out, _ = run(t, preset, "restore", tr["id"].(string))
	assert.Equal(t, 0, code, out)
	assert.Contains(t, out, "Restored preset Blend 2")

	code, out, _ = run(t, preset, "try", "CRT")
	assert.Equal(t, 0, code, out)
	_, out, _ = run(t, preset, "try", "--status", "--json")
	assert.Contains(t, out, `"preset": "CRT"`)
	code, out, _ = run(t, preset, "try", "--revert")
	assert.Equal(t, 0, code, out)
	_, out, _ = run(t, preset, "try", "--status", "--json")
	assert.Equal(t, "null\n", out)

	code, out, _ = run(t, preset, "edit", "Neon Mine")
	assert.Equal(t, 0, code, out)
	run(t, cfg, "set", "theme.roundness", "5")
	code, out, _ = run(t, preset, "edit", "--save")
	assert.Equal(t, 0, code, out)
	assert.Contains(t, out, "Saved into Neon Mine")
	_, out, _ = run(t, preset, "diff", "Neon Tokyo", "Neon Mine")
	assert.Contains(t, out, "theme.roundness:")
}
