package yozakura

import (
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestTermToolsRegistered(t *testing.T) {
	d, _, _ := newDeps(t)
	names := map[string]bool{}
	for _, td := range Tools(d) {
		names[td.Tool.Name] = true
	}
	assert.True(t, names["term_presets"] && names["term_set"])
	ro := ReadOnlyToolNames()
	assert.Contains(t, ro, "term_presets")
	assert.NotContains(t, ro, "term_set")
}

func TestTermPresets(t *testing.T) {
	d, _, ipc := newDeps(t)
	ipc.result["term.presets"] = `[{"id":"zen","name":"Zen","lines":1,"nerdFont":true}]`
	ipc.result["term.status"] = `{"enabled":false,"fishInstalled":true}`
	m := structured(t, callTool(t, d, "term_presets", `{}`))
	assert.Len(t, m["presets"].([]any), 1)
	assert.Equal(t, true, m["status"].(map[string]any)["fishInstalled"])
	ipc.down = true
	assert.True(t, callTool(t, d, "term_presets", `{}`).IsError)
}

func TestTermSet(t *testing.T) {
	d, _, ipc := newDeps(t)
	ipc.result["term.presets"] = `[{"id":"zen"},{"id":"pure"}]`
	ipc.result["term.apply"] = `{"enabled":true,"engine":"ohmyposh","engineInstalled":{"starship":true,"ohmyposh":false},"fishInstalled":true,"fishIsLoginShell":false,"foreignPromptInit":true}`
	m := structured(t, callTool(t, d, "term_set", `{"preset":"zen","engine":"ohmyposh"}`))
	assert.Equal(t, true, m["ok"])
	assert.Equal(t, "term.apply", ipc.calls[len(ipc.calls)-1].Method)
	data, err := os.ReadFile(d.ConfigFile("terminal"))
	assert.NoError(t, err)
	assert.Contains(t, string(data), `"prompt": "zen"`)
	assert.Contains(t, string(data), `"engine": "ohmyposh"`)
	assert.Contains(t, string(data), `"enabled": true`)
	todo := m["todo"].([]any)
	assert.Len(t, todo, 3)
	assert.Contains(t, todo[0], "oh-my-posh")

	assert.True(t, callTool(t, d, "term_set", `{"preset":"nope"}`).IsError)
	assert.True(t, callTool(t, d, "term_set", `{"preset":"../x"}`).IsError)
	assert.True(t, callTool(t, d, "term_set", `{"preset":"zen","engine":"zsh"}`).IsError)
	assert.True(t, callTool(t, d, "term_set", `{}`).IsError)

	m = structured(t, callTool(t, d, "term_set", `{"enabled":false}`))
	data, _ = os.ReadFile(d.ConfigFile("terminal"))
	assert.Contains(t, string(data), `"enabled": false`)
	assert.Empty(t, m["todo"])
}
