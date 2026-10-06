package main

import (
	"bytes"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestProvidersCLI(t *testing.T) {
	f := &fakeUsageIPC{results: map[string]string{
		"providers.list": `{"providers":[{"provider":"ollama","local":true,"ok":false,"error":"connection refused","models":[]},
			{"provider":"openai","stored":true,"ok":true,"verified":true,"models":[{"id":"gpt-5"},{"id":"gpt-4o","name":"GPT-4o"}]}]}`,
		"providers.ollama.probe": `{"endpoint":"http://127.0.0.1:11434","reachable":true,"version":"0.12.0",
			"models":[{"id":"qwen3:8b","sizeLabel":"8.2B","contextLength":40960,"capabilities":["completion","tools"]}]}`,
	}}
	var out, errOut bytes.Buffer
	assert.Equal(t, 0, runProviders(nil, f, &out, &errOut))
	assert.Equal(t, "providers.list", f.method)
	assert.Contains(t, out.String(), "connection refused")
	assert.Regexp(t, `openai\s+ok\s+2`, out.String())

	out.Reset()
	f.results["providers.list"] = `{"providers":[{"provider":"openai","stored":true,"ok":true,"verified":true,"models":[{"id":"gpt-5"},{"id":"gpt-4o","name":"GPT-4o"}]}]}`
	assert.Equal(t, 0, runProviders([]string{"test", "openai"}, f, &out, &errOut))
	assert.Equal(t, map[string]any{"provider": "openai"}, f.params)
	assert.Contains(t, out.String(), "gpt-4o (GPT-4o)")

	out.Reset()
	assert.Equal(t, 0, runProviders([]string{"ollama"}, f, &out, &errOut))
	assert.Contains(t, out.String(), "qwen3:8b")
	assert.Contains(t, out.String(), "completion,tools")

	out.Reset()
	assert.Equal(t, 0, runProviders([]string{"list", "--json"}, f, &out, &errOut))
	assert.Contains(t, out.String(), `"provider": "openai"`)

	assert.Equal(t, 2, runProviders([]string{"bogus"}, f, &out, &errOut))
	assert.Equal(t, 1, runProviders(nil, &fakeUsageIPC{}, &out, &errOut), "shell down")
}
