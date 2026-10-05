package mcp

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"sync"
)

// Handler runs a tool. args is the raw "arguments" object (may be empty).
// Returning an error produces an isError result with the error text.
type Handler func(ctx context.Context, args json.RawMessage) (*CallToolResult, error)

// ToolDef is a tool plus its handler.
type ToolDef struct {
	Tool    Tool
	Handler Handler
}

// Server is a minimal MCP server speaking newline-delimited JSON-RPC.
type Server struct {
	Info         Implementation
	Instructions string
	tools        []ToolDef
	byName       map[string]int
	Logger       *log.Logger
}

// NewServer builds a server with the given tools.
func NewServer(info Implementation, instructions string, tools []ToolDef) *Server {
	s := &Server{Info: info, Instructions: instructions, byName: map[string]int{}}
	for _, t := range tools {
		s.byName[t.Tool.Name] = len(s.tools)
		s.tools = append(s.tools, t)
	}
	return s
}

// Tools returns the registered tool descriptors.
func (s *Server) Tools() []Tool {
	out := make([]Tool, len(s.tools))
	for i, t := range s.tools {
		out[i] = t.Tool
	}
	return out
}

// Serve reads frames from r and writes responses to w until EOF or ctx ends.
// Tool calls run concurrently; writes are serialized.
func (s *Server) Serve(ctx context.Context, r io.Reader, w io.Writer) error {
	ctx, cancel := context.WithCancel(ctx)
	defer cancel()
	var wmu sync.Mutex
	write := func(m Message) {
		m.JSONRPC = "2.0"
		data, err := json.Marshal(m)
		if err != nil {
			return
		}
		wmu.Lock()
		defer wmu.Unlock()
		w.Write(append(data, '\n'))
	}
	var wg sync.WaitGroup
	defer wg.Wait()

	sc := bufio.NewScanner(r)
	sc.Buffer(make([]byte, 0, 64*1024), 32*1024*1024)
	for sc.Scan() {
		line := sc.Bytes()
		if len(line) == 0 {
			continue
		}
		var m Message
		if err := json.Unmarshal(line, &m); err != nil {
			write(Message{ID: json.RawMessage("null"), Error: &RPCError{Code: CodeParseError, Message: "parse error"}})
			continue
		}
		if m.Method == "" {
			continue // a response to something we never sent
		}
		if m.IsNotification() {
			continue // notifications/initialized, cancelled, ...
		}
		msg := m
		if msg.Method == "tools/call" {
			wg.Add(1)
			go func() {
				defer wg.Done()
				write(s.dispatch(ctx, &msg))
			}()
			continue
		}
		write(s.dispatch(ctx, &msg))
	}
	return sc.Err()
}

func (s *Server) dispatch(ctx context.Context, m *Message) Message {
	resp := Message{ID: m.ID}
	result, rerr := s.handle(ctx, m.Method, m.Params)
	if rerr != nil {
		resp.Error = rerr
		return resp
	}
	data, err := json.Marshal(result)
	if err != nil {
		resp.Error = &RPCError{Code: CodeInternalError, Message: err.Error()}
		return resp
	}
	resp.Result = data
	return resp
}

func (s *Server) handle(ctx context.Context, method string, params json.RawMessage) (any, *RPCError) {
	switch method {
	case "initialize":
		var p struct {
			ProtocolVersion string `json:"protocolVersion"`
		}
		_ = json.Unmarshal(params, &p)
		return InitializeResult{
			ProtocolVersion: NegotiateVersion(p.ProtocolVersion),
			Capabilities:    map[string]any{"tools": map[string]any{"listChanged": false}},
			ServerInfo:      s.Info,
			Instructions:    s.Instructions,
		}, nil
	case "ping":
		return map[string]any{}, nil
	case "tools/list":
		return map[string]any{"tools": s.Tools()}, nil
	case "tools/call":
		var p struct {
			Name      string          `json:"name"`
			Arguments json.RawMessage `json:"arguments"`
		}
		if err := json.Unmarshal(params, &p); err != nil {
			return nil, &RPCError{Code: CodeInvalidParams, Message: "invalid params: " + err.Error()}
		}
		idx, ok := s.byName[p.Name]
		if !ok {
			return nil, &RPCError{Code: CodeInvalidParams, Message: fmt.Sprintf("unknown tool: %s", p.Name)}
		}
		return s.call(ctx, s.tools[idx], p.Arguments), nil
	case "resources/list":
		return map[string]any{"resources": []any{}}, nil
	case "prompts/list":
		return map[string]any{"prompts": []any{}}, nil
	}
	return nil, &RPCError{Code: CodeMethodNotFound, Message: "method not found: " + method}
}

func (s *Server) call(ctx context.Context, t ToolDef, args json.RawMessage) (res *CallToolResult) {
	defer func() {
		if r := recover(); r != nil {
			res = ErrorResult("tool %s panicked: %v", t.Tool.Name, r)
		}
	}()
	if len(args) == 0 || string(args) == "null" {
		args = json.RawMessage("{}")
	}
	out, err := t.Handler(ctx, args)
	if err != nil {
		if s.Logger != nil {
			s.Logger.Printf("tool %s: %v", t.Tool.Name, err)
		}
		return ErrorResult("%v", err)
	}
	if out == nil {
		return TextResult("ok")
	}
	if out.Content == nil {
		out.Content = []Content{}
	}
	return out
}

// NegotiateVersion picks the protocol revision to answer with.
func NegotiateVersion(requested string) string {
	for _, v := range ProtocolVersions {
		if v == requested {
			return v
		}
	}
	return ProtocolVersions[0]
}
