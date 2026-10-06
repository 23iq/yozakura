package yozakura

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestProvidersList(t *testing.T) {
	d, _, ipc := newDeps(t)
	ipc.result["providers.list"] = `{"providers":[{"provider":"ollama","local":true,"ok":false,"error":"connection refused","models":[]},
		{"provider":"openai","stored":true,"ok":true,"verified":true,"models":[{"id":"gpt-5"},{"id":"gpt-4o"},{"id":"o3"}]}]}`
	m := structured(t, callTool(t, d, "providers_list", `{"limit":2}`))
	ps := m["providers"].([]any)
	oa := ps[1].(map[string]any)
	assert.Equal(t, []any{"gpt-5", "gpt-4o"}, oa["models"])
	assert.Equal(t, float64(3), oa["modelCount"])
	assert.Equal(t, "connection refused", ps[0].(map[string]any)["error"])
	assert.Equal(t, map[string]any{}, ipc.calls[0].Params)

	structured(t, callTool(t, d, "providers_list", `{"provider":"openai"}`))
	assert.Equal(t, map[string]any{"provider": "openai"}, ipc.calls[1].Params)

	ipc.result["providers.ollama.probe"] = `{"endpoint":"http://127.0.0.1:11434","reachable":true,"models":[{"id":"qwen3:8b","capabilities":["tools"]}]}`
	m = structured(t, callTool(t, d, "ollama_models", `{}`))
	assert.Equal(t, true, m["reachable"])
	assert.Equal(t, "providers.ollama.probe", ipc.calls[2].Method)

	ro := ReadOnlyToolNames()
	assert.Contains(t, ro, "providers_list")
	assert.Contains(t, ro, "ollama_models")

	ipc.down = true
	assert.True(t, callTool(t, d, "providers_list", `{}`).IsError)
}
