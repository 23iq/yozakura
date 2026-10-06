package yozakura

import (
	"context"
	"encoding/json"
	"fmt"

	"yozakura/backend/pkg/mcp"
)

// Provider tools read the chat providers the user connected (the
// `providers` daemon service): which ones have a stored key, whether they
// answer and their models. Keys never leave the daemon.

func providerTools(d Deps) []mcp.ToolDef {
	return []mcp.ToolDef{
		define("providers_list", "List AI providers",
			`The chat providers the user connected (a stored API key or endpoint) plus the local servers (Ollama, LM Studio): whether each answers and its model ids. Only free model-listing requests are made; keys are never returned. "provider" checks one provider; "limit" caps the models listed per provider (default 50).`,
			`{"type":"object","properties":{"provider":{"type":"string"},"limit":{"type":"integer","minimum":1,"maximum":1000,"default":50}},"additionalProperties":false}`,
			toolOpts{readOnly: true, openWorld: true}, d.providersList),
		define("ollama_models", "List Ollama models",
			`The models installed in the local Ollama server with size, family, context length and capabilities (tools, vision, thinking...). Reads metadata only; never loads a model. "endpoint" defaults to the user's setting (ai.ollama.endpoint) or http://127.0.0.1:11434.`,
			`{"type":"object","properties":{"endpoint":{"type":"string"}},"additionalProperties":false}`,
			toolOpts{readOnly: true}, d.ollamaModels),
	}
}

// ProviderEntry mirrors providers.Connected (the daemon's providers.list).
type ProviderEntry struct {
	Provider string `json:"provider"`
	Local    bool   `json:"local"`
	Stored   bool   `json:"stored"`
	Endpoint string `json:"endpoint,omitempty"`
	OK       bool   `json:"ok"`
	Verified bool   `json:"verified"`
	Error    string `json:"error,omitempty"`
	Models   []struct {
		ID   string `json:"id"`
		Name string `json:"name"`
	} `json:"models"`
}

// ListProviders calls providers.list (one provider when only != "").
func ListProviders(c Caller, only string) ([]ProviderEntry, error) {
	if c == nil {
		return nil, errNoDaemon
	}
	params := map[string]any{}
	if only != "" {
		params["provider"] = only
	}
	raw, err := c.Call("providers.list", params)
	if err != nil {
		return nil, err
	}
	var r struct {
		Providers []ProviderEntry `json:"providers"`
	}
	if err := json.Unmarshal(raw, &r); err != nil {
		return nil, fmt.Errorf("providers.list: %v", err)
	}
	return r.Providers, nil
}

func (d Deps) providersList(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct {
		Provider string
		Limit    int
	}
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	if a.Limit <= 0 {
		a.Limit = 50
	}
	list, err := ListProviders(d.IPC, a.Provider)
	if err != nil {
		return nil, err
	}
	out := []map[string]any{}
	for _, p := range list {
		ids := []string{}
		for i, m := range p.Models {
			if i >= a.Limit {
				break
			}
			ids = append(ids, m.ID)
		}
		e := map[string]any{"provider": p.Provider, "local": p.Local, "stored": p.Stored, "ok": p.OK,
			"verified": p.Verified, "models": ids, "modelCount": len(p.Models)}
		if p.Error != "" {
			e["error"] = p.Error
		}
		if p.Endpoint != "" {
			e["endpoint"] = p.Endpoint
		}
		out = append(out, e)
	}
	return mcp.JSONResult(map[string]any{"providers": out}), nil
}

func (d Deps) ollamaModels(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ Endpoint string }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	params := map[string]any{}
	if a.Endpoint != "" {
		params["endpoint"] = a.Endpoint
	}
	raw, err := d.call("providers.ollama.probe", params)
	if err != nil {
		return nil, err
	}
	var probe map[string]any
	if err := json.Unmarshal(raw, &probe); err != nil {
		return nil, fmt.Errorf("providers.ollama.probe: %v", err)
	}
	return mcp.JSONResult(probe), nil
}
