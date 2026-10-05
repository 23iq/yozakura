package agents

import (
	"encoding/json"
	"strconv"
	"sync"
)

// rpcError is a JSON-RPC error object.
type rpcError struct {
	Code    int             `json:"code"`
	Message string          `json:"message"`
	Data    json.RawMessage `json:"data,omitempty"`
}

func (e *rpcError) Error() string { return e.Message }

type rpcMessage struct {
	JSONRPC string          `json:"jsonrpc,omitempty"`
	ID      json.RawMessage `json:"id,omitempty"`
	Method  string          `json:"method,omitempty"`
	Params  json.RawMessage `json:"params,omitempty"`
	Result  json.RawMessage `json:"result,omitempty"`
	Error   *rpcError       `json:"error,omitempty"`
}

// rpcPeer is a minimal bidirectional JSON-RPC 2.0 peer over a line writer.
// Request ids are sequential integers starting at 1 (deterministic, which
// the recorded test fixtures rely on).
type rpcPeer struct {
	write     func(v any) error
	mu        sync.Mutex
	next      int64
	pending   map[string]func(json.RawMessage, *rpcError)
	onNotify  func(method string, params json.RawMessage)
	onRequest func(id json.RawMessage, method string, params json.RawMessage)
}

func newRPCPeer(write func(v any) error) *rpcPeer {
	return &rpcPeer{write: write, pending: map[string]func(json.RawMessage, *rpcError){}}
}

// Call sends a request; cb (may be nil) runs on the reader goroutine.
func (p *rpcPeer) Call(method string, params any, cb func(json.RawMessage, *rpcError)) error {
	p.mu.Lock()
	p.next++
	id := p.next
	if cb != nil {
		p.pending[strconv.FormatInt(id, 10)] = cb
	}
	p.mu.Unlock()
	return p.write(map[string]any{"jsonrpc": "2.0", "id": id, "method": method, "params": params})
}

// Notify sends a notification.
func (p *rpcPeer) Notify(method string, params any) error {
	msg := map[string]any{"jsonrpc": "2.0", "method": method}
	if params != nil {
		msg["params"] = params
	}
	return p.write(msg)
}

// Reply answers a server->client request.
func (p *rpcPeer) Reply(id json.RawMessage, result any) error {
	return p.write(map[string]any{"jsonrpc": "2.0", "id": id, "result": result})
}

// ReplyError answers a server->client request with an error.
func (p *rpcPeer) ReplyError(id json.RawMessage, code int, msg string) error {
	return p.write(map[string]any{"jsonrpc": "2.0", "id": id, "error": map[string]any{"code": code, "message": msg}})
}

// Handle dispatches one incoming line. Returns false if it was not JSON.
func (p *rpcPeer) Handle(line []byte) bool {
	var m rpcMessage
	if err := json.Unmarshal(line, &m); err != nil {
		return false
	}
	hasID := len(m.ID) > 0 && string(m.ID) != "null"
	switch {
	case m.Method != "" && hasID:
		if p.onRequest != nil {
			p.onRequest(m.ID, m.Method, m.Params)
		} else {
			_ = p.ReplyError(m.ID, -32601, "method not found")
		}
	case m.Method != "":
		if p.onNotify != nil {
			p.onNotify(m.Method, m.Params)
		}
	case hasID:
		key := string(m.ID)
		if s, err := strconv.Unquote(key); err == nil {
			key = s
		}
		p.mu.Lock()
		cb := p.pending[key]
		delete(p.pending, key)
		p.mu.Unlock()
		if cb != nil {
			cb(m.Result, m.Error)
		}
	}
	return true
}
