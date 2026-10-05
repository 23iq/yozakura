package yozakura

import (
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestShellCommands(t *testing.T) {
	d, r, ipc := newDeps(t)
	list := callTool(t, d, "shell_commands", `{}`)
	assert.False(t, list.IsError, list.Text())
	assert.Contains(t, list.Text(), `"id": "glass"`)
	assert.Contains(t, list.Text(), `"max": 24`)

	dnd := callTool(t, d, "shell_command", `{"command":"dnd"}`)
	assert.False(t, dnd.IsError, dnd.Text())
	if assert.Len(t, ipc.calls, 1) {
		assert.Equal(t, "ui.run", ipc.calls[0].Method)
		assert.Equal(t, map[string]any{"command": "dnd-toggle"}, ipc.calls[0].Params)
	}

	glass := callTool(t, d, "shell_command", `{"command":"glass","arg":"0.6"}`)
	assert.False(t, glass.IsError, glass.Text())
	data, _ := os.ReadFile(d.ConfigFile("theme"))
	assert.Contains(t, string(data), `"amount": 0.6`)

	preset := callTool(t, d, "shell_command", `{"command":"preset","arg":"Sumi-e"}`)
	assert.False(t, preset.IsError, preset.Text())
	assert.Equal(t, []string{"preset", "apply", "Sumi-e"}, r.last().Args)

	bad := callTool(t, d, "shell_command", `{"command":"glass","arg":"3"}`)
	assert.True(t, bad.IsError)
	assert.Contains(t, bad.Text(), "out of range")

	unknown := callTool(t, d, "shell_command", `{"command":"nope"}`)
	assert.True(t, unknown.IsError)
	assert.Contains(t, unknown.Text(), "unknown command")
}
