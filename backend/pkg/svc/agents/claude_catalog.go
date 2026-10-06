package agents

import (
	"context"
	"encoding/json"
	"errors"
	"os"
	"os/exec"
	"strings"
)

// Claude's SDK initialize response is the native source of model/effort
// capabilities. It does not start a model turn or require a user prompt.
func (claudeAdapter) Models(ctx context.Context, o StartOptions) (ModelCatalog, error) {
	fallback := ModelCatalog{Models: []ModelInfo{}, ManualModel: true}
	helpCmd := exec.CommandContext(ctx, o.Binary, "--help")
	helpCmd.Env = append(os.Environ(), o.Env...)
	help, helpErr := helpCmd.Output()
	effortFlag := helpErr == nil && strings.Contains(string(help), "--effort")
	done := make(chan ModelCatalog, 1)
	o.Mode = "oneshot"
	o.MCP = nil
	o.ExtraArgs = nil
	cfg, err := writePrivateFile("catalog-mcp-*.json", claudeMCPConfig(o))
	if err != nil {
		return fallback, err
	}
	defer os.Remove(cfg)
	p, err := startProc(o.Binary, claudeArgs(o, cfg), o.Cwd, o.Env, func(line []byte) {
		var response struct {
			Type     string `json:"type"`
			Response struct {
				Subtype   string `json:"subtype"`
				RequestID string `json:"request_id"`
				Response  struct {
					Models []struct {
						Value       string   `json:"value"`
						Name        string   `json:"displayName"`
						Description string   `json:"description"`
						ResolvedID  string   `json:"resolvedModel"`
						Effort      bool     `json:"supportsEffort"`
						Levels      []string `json:"supportedEffortLevels"`
						Default     string   `json:"defaultEffort"`
					} `json:"models"`
				} `json:"response"`
			} `json:"response"`
		}
		if json.Unmarshal(line, &response) != nil || response.Type != "control_response" || response.Response.RequestID != "catalog" {
			return
		}
		result := fallback
		if response.Response.Subtype != "success" {
			result.Error = "Claude Code rejected capability discovery"
		} else {
			for _, entry := range response.Response.Response.Models {
				model := ModelInfo{ID: entry.Value, Name: entry.Name, Efforts: []string{}, DefaultEffort: entry.Default, IsDefault: entry.Value == "default"}
				if model.IsDefault {
					model.Resolved = claudeResolvedName(entry.Description, entry.ResolvedID)
				}
				if entry.Effort && effortFlag && len(entry.Levels) > 0 {
					model.Efforts = entry.Levels
				}
				result.Models = append(result.Models, model)
			}
			if len(result.Models) == 0 {
				result.Error = "Installed Claude Code does not report model capabilities; enter a model ID manually"
			}
		}
		select {
		case done <- result:
		default:
		}
	}, func(err error, _ string) {
		select {
		case done <- ModelCatalog{Models: []ModelInfo{}, ManualModel: true, Error: "Claude Code discovery exited"}:
		default:
		}
	})
	if err != nil {
		return fallback, err
	}
	defer p.stop()
	if err := p.writeJSON(map[string]any{"type": "control_request", "request_id": "catalog", "request": map[string]any{"subtype": "initialize"}}); err != nil {
		return fallback, err
	}
	select {
	case result := <-done:
		return result, nil
	case <-ctx.Done():
		return fallback, errors.New("claude code model discovery timed out")
	}
}

// claudeResolvedName is the concrete model behind Claude's "default" alias:
// the head of its description ("Opus 5.5 · Best for everyday, complex
// tasks"), else the resolved model id.
func claudeResolvedName(description, resolvedID string) string {
	head, _, _ := strings.Cut(description, "·")
	if head = strings.TrimSpace(head); head != "" && len(head) <= 40 {
		return head
	}
	return resolvedID
}
