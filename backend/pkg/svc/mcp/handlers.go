package mcp

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"sort"
	"sync"
	"yozakura/backend/pkg/brand"

	"yozakura/backend/pkg/mcp"
)

// --- IPC handlers ------------------------------------------------------

func (s *Service) configure(params json.RawMessage) (any, error) {
	cfg := Config{Sources: Sources{true, true, true}, Yozakura: true}
	if len(params) > 0 {
		if err := json.Unmarshal(params, &cfg); err != nil {
			return nil, err
		}
	}
	s.mu.Lock()
	s.cfg = cfg
	s.mu.Unlock()
	return s.servers(nil)
}

func (s *Service) servers(_ json.RawMessage) (any, error) {
	res := s.resolve()
	out := make([]mcp.Public, 0, len(res.Servers))
	for _, sp := range res.Servers {
		out = append(out, sp.Public())
	}
	return out, nil
}

func (s *Service) status(_ json.RawMessage) (any, error) {
	res := s.resolve()
	s.mu.Lock()
	running := []string{}
	for name := range s.pool {
		running = append(running, name)
	}
	errs := map[string]string{}
	for k, v := range s.lastErr {
		errs[k] = v
	}
	s.mu.Unlock()
	sort.Strings(running)
	return map[string]any{"duplicates": res.Duplicates, "importErrors": res.Errors, "running": running, "serverErrors": errs}, nil
}

func (s *Service) tools(params json.RawMessage) (any, error) {
	var p struct {
		Server string `json:"server"`
	}
	if err := json.Unmarshal(params, &p); err != nil || p.Server == "" {
		return nil, fmt.Errorf("mcp.tools: server is required")
	}
	ctx, cancel := context.WithTimeout(context.Background(), listTimeout)
	defer cancel()
	return s.ListTools(ctx, p.Server)
}

// ToolInfo is one row of mcp.all_tools.
type ToolInfo struct {
	Server      string          `json:"server"`
	Name        string          `json:"name"`
	Description string          `json:"description"`
	InputSchema json.RawMessage `json:"inputSchema"`
	ReadOnly    bool            `json:"readOnly"`
}

// AllTools lists the tools of every enabled server concurrently; servers
// that fail are skipped (see mcp.status).
func (s *Service) AllTools(ctx context.Context, only []string) []ToolInfo {
	want := set(only)
	var specs []mcp.ServerSpec
	for _, sp := range s.resolve().Servers {
		if sp.Enabled && (len(want) == 0 || want[sp.Name]) {
			specs = append(specs, sp)
		}
	}
	var mu sync.Mutex
	var wg sync.WaitGroup
	out := []ToolInfo{}
	for _, sp := range specs {
		wg.Add(1)
		go func(sp mcp.ServerSpec) {
			defer wg.Done()
			tools, err := s.ListTools(ctx, sp.Name)
			if err != nil {
				log.Printf("[mcp] %s: %v", sp.Name, err)
				return
			}
			mu.Lock()
			for _, t := range tools {
				out = append(out, ToolInfo{Server: sp.Name, Name: t.Name, Description: t.Description, InputSchema: t.InputSchema, ReadOnly: t.ReadOnly()})
			}
			mu.Unlock()
		}(sp)
	}
	wg.Wait()
	sort.Slice(out, func(i, j int) bool {
		if out[i].Server != out[j].Server {
			if out[i].Server == brand.AppID || out[j].Server == brand.AppID {
				return out[i].Server == brand.AppID
			}
			return out[i].Server < out[j].Server
		}
		return out[i].Name < out[j].Name
	})
	return out
}

func (s *Service) allTools(params json.RawMessage) (any, error) {
	var p struct {
		Servers []string `json:"servers"`
	}
	if len(params) > 0 {
		_ = json.Unmarshal(params, &p)
	}
	ctx, cancel := context.WithTimeout(context.Background(), listTimeout)
	defer cancel()
	return s.AllTools(ctx, p.Servers), nil
}

func (s *Service) call(params json.RawMessage) (any, error) {
	var p struct {
		Server    string          `json:"server"`
		Tool      string          `json:"tool"`
		Arguments json.RawMessage `json:"arguments"`
		// Builtin: a user action (Undo) on the built-in server, allowed
		// even when that server is off for AI engines.
		Builtin bool `json:"builtin"`
	}
	if err := json.Unmarshal(params, &p); err != nil {
		return nil, err
	}
	if p.Server == "" || p.Tool == "" {
		return nil, fmt.Errorf("mcp.call: server and tool are required")
	}
	ctx, cancel := context.WithTimeout(context.Background(), callTimeout)
	defer cancel()
	var res *mcp.CallToolResult
	var err error
	if p.Builtin && p.Server == brand.AppID {
		res, err = s.CallBuiltin(ctx, p.Tool, p.Arguments)
	} else {
		res, err = s.CallTool(ctx, p.Server, p.Tool, p.Arguments)
	}
	if err != nil {
		return map[string]any{"text": err.Error(), "content": []any{}, "isError": true}, nil
	}
	return map[string]any{"text": res.Text(), "content": res.Content, "isError": res.IsError}, nil
}
