// Package mcp implements the pieces of the Model Context Protocol the shell
// needs: a stdio server framework (used by `yozakura mcp`), a client for stdio
// and HTTP servers, and importers for the MCP server lists of other AI tools.
package mcp

import (
	"encoding/json"
	"fmt"
)

// Supported protocol revisions, newest first. The server answers with the
// client's version when it knows it and with the newest one otherwise.
var ProtocolVersions = []string{"2025-06-18", "2025-03-26", "2024-11-05"}

// LatestProtocolVersion is what the client asks for.
const LatestProtocolVersion = "2025-06-18"

// JSON-RPC error codes.
const (
	CodeParseError     = -32700
	CodeInvalidRequest = -32600
	CodeMethodNotFound = -32601
	CodeInvalidParams  = -32602
	CodeInternalError  = -32603
)

// Message is one JSON-RPC 2.0 frame (request, notification or response).
type Message struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      json.RawMessage `json:"id,omitempty"`
	Method  string          `json:"method,omitempty"`
	Params  json.RawMessage `json:"params,omitempty"`
	Result  json.RawMessage `json:"result,omitempty"`
	Error   *RPCError       `json:"error,omitempty"`
}

// IsRequest reports a frame that expects a response.
func (m *Message) IsRequest() bool { return m.Method != "" && len(m.ID) > 0 && string(m.ID) != "null" }

// IsNotification reports a frame without id.
func (m *Message) IsNotification() bool {
	return m.Method != "" && (len(m.ID) == 0 || string(m.ID) == "null")
}

// RPCError is a JSON-RPC error object.
type RPCError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
	Data    any    `json:"data,omitempty"`
}

func (e *RPCError) Error() string { return fmt.Sprintf("mcp error %d: %s", e.Code, e.Message) }

// ToolAnnotations are behaviour hints for clients (MCP 2025-03-26+).
type ToolAnnotations struct {
	Title           string `json:"title,omitempty"`
	ReadOnlyHint    *bool  `json:"readOnlyHint,omitempty"`
	DestructiveHint *bool  `json:"destructiveHint,omitempty"`
	IdempotentHint  *bool  `json:"idempotentHint,omitempty"`
	OpenWorldHint   *bool  `json:"openWorldHint,omitempty"`
}

// Tool describes a callable tool.
type Tool struct {
	Name        string           `json:"name"`
	Title       string           `json:"title,omitempty"`
	Description string           `json:"description,omitempty"`
	InputSchema json.RawMessage  `json:"inputSchema"`
	Annotations *ToolAnnotations `json:"annotations,omitempty"`
}

// ReadOnly reports the readOnlyHint (false when absent).
func (t Tool) ReadOnly() bool {
	return t.Annotations != nil && t.Annotations.ReadOnlyHint != nil && *t.Annotations.ReadOnlyHint
}

// Content is one item of a tool result.
type Content struct {
	Type     string `json:"type"`
	Text     string `json:"text,omitempty"`
	Data     string `json:"data,omitempty"`
	MimeType string `json:"mimeType,omitempty"`
	URI      string `json:"uri,omitempty"`
	Resource any    `json:"resource,omitempty"`
}

// CallToolResult is the result of tools/call.
type CallToolResult struct {
	Content           []Content `json:"content"`
	StructuredContent any       `json:"structuredContent,omitempty"`
	IsError           bool      `json:"isError,omitempty"`
}

// Text flattens the text items of a result (images become a placeholder).
func (r *CallToolResult) Text() string {
	out := ""
	for i, c := range r.Content {
		if i > 0 {
			out += "\n"
		}
		switch c.Type {
		case "text":
			out += c.Text
		case "image":
			out += "[image " + c.MimeType + "]"
		case "resource", "resource_link":
			out += "[resource " + c.URI + "]"
		default:
			out += "[" + c.Type + "]"
		}
	}
	return out
}

// TextResult builds a successful single-text result.
func TextResult(text string) *CallToolResult {
	return &CallToolResult{Content: []Content{{Type: "text", Text: text}}}
}

// ErrorResult builds an isError result: tool failures are reported to the
// model as content, not as protocol errors, so it can correct itself.
func ErrorResult(format string, args ...any) *CallToolResult {
	return &CallToolResult{Content: []Content{{Type: "text", Text: fmt.Sprintf(format, args...)}}, IsError: true}
}

// JSONResult renders v as indented JSON text plus structuredContent.
func JSONResult(v any) *CallToolResult {
	data, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return ErrorResult("marshal result: %v", err)
	}
	return &CallToolResult{Content: []Content{{Type: "text", Text: string(data)}}, StructuredContent: wrapStructured(v)}
}

// structuredContent must be an object.
func wrapStructured(v any) any {
	data, err := json.Marshal(v)
	if err != nil || len(data) == 0 || data[0] != '{' {
		return map[string]any{"result": v}
	}
	return v
}

// Bool returns a pointer for annotation literals.
func Bool(b bool) *bool { return &b }

// Implementation identifies a client or server.
type Implementation struct {
	Name    string `json:"name"`
	Version string `json:"version"`
}

// InitializeResult is the server's answer to initialize.
type InitializeResult struct {
	ProtocolVersion string         `json:"protocolVersion"`
	Capabilities    map[string]any `json:"capabilities"`
	ServerInfo      Implementation `json:"serverInfo"`
	Instructions    string         `json:"instructions,omitempty"`
}
