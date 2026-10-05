package main

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
)

func specialRun(t *testing.T, env *specialEnv, args ...string) (string, string, int) {
	t.Helper()
	var out, errOut bytes.Buffer
	code := env.run(args, &out, &errOut)
	return out.String(), errOut.String(), code
}

func testSpecialEnv(t *testing.T) (*specialEnv, *[]string) {
	t.Helper()
	home := sandbox(t)
	env, err := defaultSpecialEnv()
	if !assert.NoError(t, err) {
		t.FailNow()
	}
	env.dirs = []string{"../../pkg/specials/testdata/apps"}
	env.hypr = filepath.Join(home, "hypr")
	env.binds = "../../pkg/specials/testdata/binds.json"
	opened := []string{}
	env.open = func(id, name string) error {
		opened = append(opened, id+"="+name)
		return nil
	}
	return env, &opened
}

func TestSpecialCommands(t *testing.T) {
	env, opened := testSpecialEnv(t)
	out, _, code := specialRun(t, env, "list")
	assert.Equal(t, 0, code)
	assert.Contains(t, out, "No special workspaces")

	out, errOut, code := specialRun(t, env, "add", "My Chat", "--toggle", "SUPER+S", "--send", "SUPER+ALT+S", "--accent", "tertiary")
	assert.Equal(t, 0, code, errOut)
	assert.Contains(t, out, "Added My Chat (special:My-Chat)")
	assert.Contains(t, out, "Conflict: SUPER+S (My Chat toggle) is also the core bind system.tools")

	_, errOut, code = specialRun(t, env, "add", "my chat")
	assert.Equal(t, 1, code)
	assert.Contains(t, errOut, "already exists")
	_, errOut, code = specialRun(t, env, "set", "My-Chat", "--accent", "#ff0000")
	assert.Equal(t, 1, code, "hex accents are refused")
	assert.Contains(t, errOut, "accent")

	_, errOut, code = specialRun(t, env, "app", "add", "my-chat", "discord", "--if-running", "move", "--rule")
	assert.Equal(t, 0, code, errOut)
	_, errOut, code = specialRun(t, env, "app", "add", "my-chat", "nope")
	assert.Equal(t, 1, code)
	assert.Contains(t, errOut, "no installed app")
	out, errOut, code = specialRun(t, env, "app", "add", "my-chat", "--match", "foot", "--command", "foot")
	assert.Equal(t, 0, code, errOut)
	assert.Contains(t, out, "added foot")

	out, _, _ = specialRun(t, env, "list", "--json")
	var list []map[string]any
	assert.NoError(t, json.Unmarshal([]byte(out), &list))
	if assert.Len(t, list, 1) {
		assert.Equal(t, "special:My-Chat", list[0]["workspace"])
		apps := list[0]["apps"].([]any)
		assert.Len(t, apps, 2)
		assert.Equal(t, "move", apps[0].(map[string]any)["ifRunning"])
		assert.Equal(t, true, apps[0].(map[string]any)["rule"])
	}

	_, errOut, code = specialRun(t, env, "set", "my-chat", "--name", "Talk", "--preload", "on")
	assert.Equal(t, 0, code, errOut)
	_, _, code = specialRun(t, env, "open", "talk")
	assert.Equal(t, 0, code)
	assert.Equal(t, []string{"my-chat=Talk"}, *opened, "id stays, Hyprland name follows the rename")

	_, _, code = specialRun(t, env, "app", "remove", "Talk", "foot")
	assert.Equal(t, 0, code)
	_, _, code = specialRun(t, env, "remove", "Talk")
	assert.Equal(t, 0, code)
	_, errOut, code = specialRun(t, env, "open", "Talk")
	assert.Equal(t, 1, code)
	assert.Contains(t, errOut, "no special workspace")
}

func TestSpecialImportBinds(t *testing.T) {
	env, _ := testSpecialEnv(t)
	custom := filepath.Join(env.hypr, "custom")
	assert.NoError(t, os.MkdirAll(custom, 0o755))
	src, _ := os.ReadFile("../../pkg/specials/testdata/hypr/custom/keybinds.lua")
	assert.NoError(t, os.WriteFile(filepath.Join(custom, "keybinds.lua"), src, 0o644))

	out, errOut, code := specialRun(t, env, "import-binds", "--dry-run")
	assert.Equal(t, 0, code, errOut)
	assert.Contains(t, out, "Would import Telegram")
	after, _ := os.ReadFile(filepath.Join(custom, "keybinds.lua"))
	assert.Equal(t, string(src), string(after), "dry run writes nothing")

	out, errOut, code = specialRun(t, env, "import-binds")
	assert.Equal(t, 0, code, errOut)
	for _, n := range []string{"Imported Telegram", "Imported Discord", "Imported Dev", "Backup: "} {
		assert.Contains(t, out, n)
	}
	assert.Contains(t, out, "Conflict: SUPER+C (Dev toggle) is also the custom bind \"Close Window\"")
	out, _, _ = specialRun(t, env, "list")
	assert.Contains(t, out, "Telegram  (special:Telegram, id telegram)  toggle SUPER+S, send SUPER+ALT+S")
	assert.Contains(t, out, "apps: Discord")

	out, _, code = specialRun(t, env, "import-binds")
	assert.Equal(t, 0, code)
	assert.Contains(t, out, "No special workspace binds found")
	assert.False(t, strings.Contains(out, "Imported"))
}
