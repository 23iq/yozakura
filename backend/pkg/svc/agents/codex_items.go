package agents

import (
	"encoding/json"
	"strings"
)

// Codex thread items (commands, file changes, MCP calls, ...) -> events.

type codexItem struct {
	Type             string           `json:"type"`
	ID               string           `json:"id"`
	Text             string           `json:"text"`
	Command          string           `json:"command"`
	Cwd              string           `json:"cwd"`
	CommandActions   []map[string]any `json:"commandActions"`
	AggregatedOutput *string          `json:"aggregatedOutput"`
	ExitCode         *int             `json:"exitCode"`
	Status           string           `json:"status"`
	Changes          []struct {
		Path string `json:"path"`
		Diff string `json:"diff"`
	} `json:"changes"`
	Server    string          `json:"server"`
	Tool      string          `json:"tool"`
	Arguments json.RawMessage `json:"arguments"`
	Result    json.RawMessage `json:"result"`
	Error     json.RawMessage `json:"error"`
	Query     string          `json:"query"`
	Summary   []string        `json:"summary"`
}

func (c *codexConn) itemStarted(it codexItem) {
	switch it.Type {
	case "commandExecution":
		cmd := unwrapShell(it.Command)
		in := map[string]any{"command": cmd, "cwd": it.Cwd}
		c.sink.Emit(Event{Kind: KindToolCall, ID: it.ID, Tool: "shell", Input: in, Title: "$ " + oneLine(cmd, 120),
			Category: commandCategory(cmd, it.CommandActions)})
	case "fileChange":
		var paths []string
		for _, ch := range it.Changes {
			paths = append(paths, c.rel(ch.Path))
		}
		c.sink.Emit(Event{Kind: KindToolCall, ID: it.ID, Tool: "apply_patch", Input: map[string]any{"paths": paths},
			Title: "Edit " + strings.Join(paths, ", "), Category: CatWrite})
		for _, ch := range it.Changes {
			if ch.Diff != "" {
				c.sink.Emit(Event{Kind: KindDiff, ID: it.ID, Tool: "apply_patch", Path: c.rel(ch.Path), Diff: withHeader(c.rel(ch.Path), ch.Diff)})
			}
		}
	case "mcpToolCall":
		var args map[string]any
		_ = json.Unmarshal(it.Arguments, &args)
		tool := "mcp__" + it.Server + "__" + it.Tool
		c.sink.Emit(Event{Kind: KindToolCall, ID: it.ID, Tool: tool, Input: args, Title: it.Server + ": " + it.Tool, Category: Classify(tool, args)})
	case "webSearch":
		c.sink.Emit(Event{Kind: KindToolCall, ID: it.ID, Tool: "WebSearch", Input: map[string]any{"query": it.Query},
			Title: "Search " + oneLine(it.Query, 80), Category: CatNetwork})
	}
}

func (c *codexConn) itemCompleted(it codexItem) {
	switch it.Type {
	case "agentMessage":
		if !c.deltas[it.ID] && it.Text != "" {
			c.text(it.Text)
		}
		c.sep = true // separate consecutive messages (commentary, final answer)
	case "reasoning":
		if len(it.Summary) > 0 {
			c.sink.Emit(Event{Kind: KindThinking, Text: strings.Join(it.Summary, "\n"), Delta: true})
		}
	case "commandExecution":
		out := ""
		if it.AggregatedOutput != nil {
			out = *it.AggregatedOutput
		}
		isErr := it.Status == "failed" || it.Status == "declined" || (it.ExitCode != nil && *it.ExitCode != 0)
		if it.Status == "declined" && out == "" {
			out = "Declined by the user."
		}
		c.sink.Emit(Event{Kind: KindToolResult, ID: it.ID, Tool: "shell", Output: truncate(out), IsError: isErr})
	case "fileChange":
		c.sink.Emit(Event{Kind: KindToolResult, ID: it.ID, Tool: "apply_patch", Output: it.Status, IsError: it.Status != "completed"})
	case "mcpToolCall":
		out := string(it.Result)
		var r struct {
			Content any `json:"content"`
		}
		if json.Unmarshal(it.Result, &r) == nil && r.Content != nil {
			out = contentText(r.Content)
		}
		isErr := len(it.Error) > 0 && string(it.Error) != "null"
		if isErr {
			out = string(it.Error)
		}
		c.sink.Emit(toolResultEvent(it.ID, "mcp__"+it.Server+"__"+it.Tool, out, isErr))
	case "webSearch":
		c.sink.Emit(Event{Kind: KindToolResult, ID: it.ID, Tool: "WebSearch", Output: it.Query})
	}
}
