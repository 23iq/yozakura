package agents

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"time"
	"yozakura/backend/pkg/brand"
)

type ModelInfo struct {
	ID            string   `json:"id"`
	Name          string   `json:"name"`
	Efforts       []string `json:"efforts"`
	DefaultEffort string   `json:"defaultEffort"`
	IsDefault     bool     `json:"isDefault,omitempty"`
	// Resolved names the concrete model behind an alias such as Claude's
	// "default" ("Opus 5.5"), so the UI can show it before the first turn.
	Resolved string `json:"resolved,omitempty"`
}
type ModelCatalog struct {
	Models      []ModelInfo `json:"models"`
	ManualModel bool        `json:"manualModel"`
	Error       string      `json:"error,omitempty"`
}
type modelDiscoverer interface {
	Models(context.Context, StartOptions) (ModelCatalog, error)
}

func (m *Manager) Models(agent, cwd string) ModelCatalog {
	result := ModelCatalog{Models: []ModelInfo{}}
	a := Lookup(agent)
	if a == nil {
		result.Error = "unknown agent: " + agent
		return result
	}
	m.mu.Lock()
	cfg := m.agentCfg(agent)
	env := append([]string{}, m.extraEnv...)
	m.mu.Unlock()
	if cfg.Enabled != nil && !*cfg.Enabled {
		result.Error = "agent is disabled"
		return result
	}
	bin := ResolveBinary(cfg.Binary, a.DefaultBinary())
	if bin == "" {
		result.Error = "agent is not installed"
		return result
	}
	if cwd == "" {
		cwd, _ = os.UserHomeDir()
	}
	d, ok := a.(modelDiscoverer)
	if !ok {
		result.Error = "model discovery is unsupported"
		return result
	}
	ctx, cancel := context.WithTimeout(context.Background(), 6*time.Second)
	defer cancel()
	result, err := d.Models(ctx, StartOptions{Binary: bin, Cwd: cwd, Env: env})
	if result.Models == nil {
		result.Models = []ModelInfo{}
	}
	if err != nil {
		result.Error = err.Error()
	}
	return result
}
func (m *Manager) validateSettings(agent, cwd, model, effort string) error {
	if model == "" && effort == "" {
		return nil
	}
	cat := m.Models(agent, cwd)
	for _, entry := range cat.Models {
		if entry.ID != model && !(model == "" && entry.IsDefault) {
			continue
		}
		if effort == "" {
			return nil
		}
		for _, value := range entry.Efforts {
			if value == effort {
				return nil
			}
		}
		return fmt.Errorf("unsupported effort %q for model %q", effort, model)
	}
	if effort == "" && cat.ManualModel {
		return nil
	}
	if cat.Error != "" {
		return errors.New(cat.Error)
	}
	return fmt.Errorf("model or effort is not supported: %q / %q", model, effort)
}

// discoveryPeer is a short-lived, timeout-bound process. Codex discovery never
// opens a thread. ACP must open a disposable session to discover its options.
func discoveryPeer(ctx context.Context, o StartOptions, args []string, initialize any, notify bool, discover func(*rpcPeer, func(json.RawMessage, error))) (json.RawMessage, error) {
	type reply struct {
		data json.RawMessage
		err  error
	}
	done := make(chan reply, 1)
	finish := func(data json.RawMessage, err error) {
		select {
		case done <- reply{data, err}:
		default:
		}
	}
	var rpc *rpcPeer
	p, err := startProc(o.Binary, args, o.Cwd, o.Env, func(line []byte) { rpc.Handle(line) }, func(err error, tail string) {
		if err == nil {
			err = errors.New("discovery process exited")
		}
		finish(nil, err)
	})
	if err != nil {
		return nil, err
	}
	defer p.stop()
	rpc = newRPCPeer(p.writeJSON)
	err = rpc.Call("initialize", initialize, func(_ json.RawMessage, e *rpcError) {
		if e != nil {
			finish(nil, e)
			return
		}
		if notify {
			_ = rpc.Notify("initialized", nil)
		}
		discover(rpc, finish)
	})
	if err != nil {
		return nil, err
	}
	select {
	case r := <-done:
		return r.data, r.err
	case <-ctx.Done():
		return nil, ctx.Err()
	}
}
func (codexAdapter) Models(ctx context.Context, o StartOptions) (ModelCatalog, error) {
	result := ModelCatalog{Models: []ModelInfo{}}
	raw, err := discoveryPeer(ctx, o, []string{"app-server"}, map[string]any{"clientInfo": map[string]any{"name": brand.AppID, "version": "1.0"}}, true, func(rpc *rpcPeer, finish func(json.RawMessage, error)) {
		var data []json.RawMessage
		var page func(string)
		page = func(cursor string) {
			params := map[string]any{"limit": 100}
			if cursor != "" {
				params["cursor"] = cursor
			}
			e := rpc.Call("model/list", params, func(raw json.RawMessage, e *rpcError) {
				if e != nil {
					finish(nil, e)
					return
				}
				var r struct {
					Data       []json.RawMessage `json:"data"`
					NextCursor string            `json:"nextCursor"`
				}
				if err := json.Unmarshal(raw, &r); err != nil {
					finish(nil, err)
					return
				}
				data = append(data, r.Data...)
				if r.NextCursor != "" {
					page(r.NextCursor)
					return
				}
				all, _ := json.Marshal(data)
				finish(all, nil)
			})
			if e != nil {
				finish(nil, e)
			}
		}
		page("")
	})
	if err != nil {
		return result, err
	}
	var entries []struct {
		ID        string `json:"id"`
		Model     string `json:"model"`
		Name      string `json:"displayName"`
		Default   string `json:"defaultReasoningEffort"`
		IsDefault bool   `json:"isDefault"`
		Efforts   []struct {
			Effort string `json:"reasoningEffort"`
		} `json:"supportedReasoningEfforts"`
	}
	if err = json.Unmarshal(raw, &entries); err != nil {
		return result, err
	}
	for _, entry := range entries {
		id := entry.Model
		if id == "" {
			id = entry.ID
		}
		model := ModelInfo{ID: id, Name: entry.Name, Efforts: []string{}, DefaultEffort: entry.Default, IsDefault: entry.IsDefault}
		for _, e := range entry.Efforts {
			model.Efforts = append(model.Efforts, e.Effort)
		}
		result.Models = append(result.Models, model)
	}
	return result, nil
}
