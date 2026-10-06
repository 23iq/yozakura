package yozakura

import (
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
)

const mcpOutputs = `[{"id":"LG|27GP|1","name":"DP-1","enabled":true,"width":2560,"height":1440,"refresh":144,"scale":1,
 "modes":[{"width":2560,"height":1440,"refresh":144},{"width":2560,"height":1440,"refresh":165},{"width":1920,"height":1080,"refresh":60}]}]`

func TestDisplaysApplyNeverPersistsWithoutKeep(t *testing.T) {
	d, _, ipc := newDeps(t)
	ipc.result["displays.list"] = mcpOutputs
	ipc.result["displays.apply"] = `{"session":"s1","revertIn":15,"live":true}`
	ipc.result["displays.keep"] = `{"ok":true}`
	ipc.result["displays.revert"] = `{"ok":true}`

	m := structured(t, callTool(t, d, "displays_apply", `{"outputs":[{"name":"DP-1","mode":"2560x1440@165"}]}`))
	assert.Equal(t, "pending", m["state"])
	assert.Equal(t, "s1", m["session"])
	assert.Equal(t, float64(15), m["revertIn"])
	for _, c := range ipc.calls {
		assert.NotEqual(t, "displays.keep", c.Method, "no keep without keep:true")
	}
	_, err := os.Stat(d.ConfigFile("displays"))
	assert.True(t, os.IsNotExist(err), "layout not saved")

	m = structured(t, callTool(t, d, "displays_apply", `{"keep":true,"outputs":[{"name":"DP-1","mode":"1920x1080","scale":1.25}]}`))
	assert.Equal(t, "kept", m["state"])
	assert.Equal(t, "displays.keep", ipc.calls[len(ipc.calls)-1].Method)
	saved, err := os.ReadFile(d.ConfigFile("displays"))
	assert.NoError(t, err)
	assert.Contains(t, string(saved), `"id": "LG|27GP|1"`)
	assert.Contains(t, string(saved), `"scale": 1.25`)

	m = structured(t, callTool(t, d, "displays_confirm", `{"session":"s1","keep":false}`))
	assert.Equal(t, "reverted", m["state"])
	m = structured(t, callTool(t, d, "displays_confirm", `{"session":"s1","keep":true}`))
	assert.Equal(t, "kept", m["state"])
}

func TestDisplaysApplyRejects(t *testing.T) {
	d, _, ipc := newDeps(t)
	ipc.result["displays.list"] = mcpOutputs
	assert.True(t, callTool(t, d, "displays_apply", `{"outputs":[{"name":"HDMI-9","scale":1}]}`).IsError)
	assert.True(t, callTool(t, d, "displays_apply", `{"outputs":[{"name":"DP-1","mode":"3840x2160@60"}]}`).IsError)
	assert.True(t, callTool(t, d, "displays_apply", `{"outputs":[]}`).IsError)
	for _, c := range ipc.calls {
		assert.NotEqual(t, "displays.apply", c.Method)
	}
	m := structured(t, callTool(t, d, "displays_list", `{}`))
	assert.Len(t, m["displays"], 1)
	ipc.down = true
	assert.True(t, callTool(t, d, "displays_list", `{}`).IsError)
}

func TestKeyboardTools(t *testing.T) {
	d, _, ipc := newDeps(t)
	ipc.result["keyboard.catalog"] = `{"layouts":[{"name":"us","variants":[]},{"name":"ru","variants":[]}]}`
	ipc.result["keyboard.active"] = `{"name":"English (US)","index":0,"code":"us","short":"EN"}`
	ipc.result["keyboard.next"] = `{"ok":true}`

	m := structured(t, callTool(t, d, "keyboard_get", `{}`))
	assert.Equal(t, "alt_shift", m["switchBind"])
	assert.Len(t, m["layouts"], 1)

	m = structured(t, callTool(t, d, "keyboard_set", `{"add":"ru"}`))
	assert.Len(t, m["layouts"], 2)
	assert.Equal(t, map[string]any{"tool": "keyboard_set", "args": map[string]any{"remove": "ru"}}, m["undo"])
	m = structured(t, callTool(t, d, "keyboard_set", `{"switchBind":"caps","next":true}`))
	assert.Equal(t, "caps", m["switchBind"])
	assert.Equal(t, "keyboard.next", ipc.calls[len(ipc.calls)-1].Method)

	assert.True(t, callTool(t, d, "keyboard_set", `{}`).IsError)
	assert.True(t, callTool(t, d, "keyboard_set", `{"add":"zz"}`).IsError)
	assert.True(t, callTool(t, d, "keyboard_set", `{"switchBind":"hyper"}`).IsError)
	structured(t, callTool(t, d, "keyboard_set", `{"remove":"ru"}`))
	assert.True(t, callTool(t, d, "keyboard_set", `{"remove":"us"}`).IsError, "last layout")
}
