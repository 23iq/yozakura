package yozakura

import (
	"errors"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestExtrasToolsRegistered(t *testing.T) {
	d, _, _ := newDeps(t)
	names := map[string]bool{}
	for _, td := range Tools(d) {
		names[td.Tool.Name] = true
		if td.Tool.Name == "extras_install" {
			assert.False(t, td.Tool.ReadOnly())
			assert.Contains(t, string(td.Tool.InputSchema), `"required":["ids"]`)
		}
	}
	assert.True(t, names["extras_list"] && names["extras_install"])
	ro := ReadOnlyToolNames()
	assert.Contains(t, ro, "extras_list")
	assert.NotContains(t, ro, "extras_install")
}

func TestExtrasList(t *testing.T) {
	d, _, ipc := newDeps(t)
	ipc.result["extras.catalog"] = `{"entries":[{"id":"firefox","name":"Firefox","category":"browsers","description":"d","recommended":true},
		{"id":"nodejs","name":"Node","category":"dev","hidden":true},{"id":"codex","name":"Codex","category":"ai"}],"platform":{"distro":"arch"}}`
	ipc.result["extras.status"] = `{"firefox":{"id":"firefox","state":"installed","source":"pkg"},"codex":{"id":"codex","state":"unavailable","reason":"no_method"}}`
	m := structured(t, callTool(t, d, "extras_list", `{}`))
	es := m["entries"].([]any)
	assert.Len(t, es, 2, "hidden entries are not listed")
	assert.Equal(t, "codex", es[0].(map[string]any)["id"], "sorted by category")
	assert.Equal(t, "no_method", es[0].(map[string]any)["reason"])
	assert.Equal(t, "pkg", es[1].(map[string]any)["source"])

	m = structured(t, callTool(t, d, "extras_list", `{"state":"installed"}`))
	assert.Len(t, m["entries"].([]any), 1)
	m = structured(t, callTool(t, d, "extras_list", `{"category":"ai"}`))
	assert.Equal(t, "codex", m["entries"].([]any)[0].(map[string]any)["id"])

	ipc.down = true
	assert.True(t, callTool(t, d, "extras_list", `{}`).IsError)
}

func TestExtrasInstall(t *testing.T) {
	d, _, ipc := newDeps(t)
	ipc.result["extras.install"] = `{"jobs":[{"id":"system-1","kind":"system","entries":["steam"]}]}`
	m := structured(t, callTool(t, d, "extras_install", `{"ids":["steam"],"confirmMultilib":true}`))
	last := ipc.calls[len(ipc.calls)-1]
	assert.Equal(t, "extras.install", last.Method)
	assert.Equal(t, map[string]any{"ids": []string{"steam"}, "confirmMultilib": true}, last.Params)
	assert.Len(t, m["jobs"].([]any), 1)

	ipc.result["extras.install"] = `{"jobs":[]}`
	m = structured(t, callTool(t, d, "extras_install", `{"ids":["steam"]}`))
	assert.Contains(t, m["message"], "already installed")

	assert.True(t, callTool(t, d, "extras_install", `{"ids":[]}`).IsError)
	assert.True(t, callTool(t, d, "extras_install", `{}`).IsError)
}

func TestExtrasInstallErrors(t *testing.T) {
	err := extrasInstallErr(errors.New(`needs_confirm: {"entries":["steam"],"kind":"multilib"}`))
	assert.Contains(t, err.Error(), "confirmMultilib true")
	err = extrasInstallErr(errors.New(`unavailable: {"reasons":{"zen":"needs_aur_helper","a":"unknown"}}`))
	assert.Contains(t, err.Error(), "a: unknown, zen: needs_aur_helper")
	assert.EqualError(t, extrasInstallErr(errors.New("boom")), "boom")
}
