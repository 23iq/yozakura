package mcp

import (
	"context"
	"encoding/json"
	"io"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"yozakura/backend/pkg/mcp"

	"github.com/stretchr/testify/assert"
)

const fixtures = "../../mcp/testdata"

func fakeConnect(connects *atomic.Int32) ConnectFunc {
	return func(ctx context.Context, sp mcp.ServerSpec) (*mcp.Client, error) {
		connects.Add(1)
		name := sp.Name
		srv := mcp.NewServer(mcp.Implementation{Name: name, Version: "1"}, "", []mcp.ToolDef{{
			Tool: mcp.Tool{Name: "whoami", Description: "server name", InputSchema: json.RawMessage(`{"type":"object"}`),
				Annotations: &mcp.ToolAnnotations{ReadOnlyHint: mcp.Bool(true)}},
			Handler: func(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
				return mcp.TextResult(name + " " + string(args)), nil
			},
		}})
		cr, sw := io.Pipe()
		sr, cw := io.Pipe()
		go func() { _ = srv.Serve(context.Background(), sr, sw); sw.Close() }()
		c := mcp.NewStreamClient(cr, cw)
		if _, err := c.Initialize(ctx, mcp.Implementation{Name: "t", Version: "1"}); err != nil {
			return nil, err
		}
		return c, nil
	}
}

func newTestService(t *testing.T) (*Service, *atomic.Int32) {
	s := NewService()
	t.Cleanup(s.Close)
	s.SetImportOptions(mcp.ImportOptions{
		Home:        t.TempDir(),
		ClaudeJSON:  fixtures + "/claude.json",
		CodexTOML:   fixtures + "/codex.toml",
		OpencodeDir: fixtures + "/opencode",
	})
	var n atomic.Int32
	s.SetConnect(fakeConnect(&n))
	return s, &n
}

func TestServersListIsRedactedAndOrdered(t *testing.T) {
	s, _ := newTestService(t)
	res, err := s.servers(nil)
	assert.NoError(t, err)
	list := res.([]mcp.Public)
	assert.Equal(t, "yozakura", list[0].Name)
	assert.True(t, list[0].Enabled)
	data, _ := json.Marshal(list)
	assert.NotContains(t, string(data), "k-123")
	assert.NotContains(t, string(data), "Bearer")
	assert.Contains(t, string(data), `"envKeys":["QUOTED.KEY","SEARCH_KEY"]`)
}

func TestConfigureDisablesAndEnables(t *testing.T) {
	s, _ := newTestService(t)
	_, err := s.configure(json.RawMessage(`{"disabled":["search"],"enabled":["off"],"sources":{"claude":true,"codex":true,"opencode":false},"yozakura":false}`))
	assert.NoError(t, err)
	enabled := map[string]mcp.ServerSpec{}
	for _, sp := range s.EnabledSpecs() {
		enabled[sp.Name] = sp
	}
	assert.NotContains(t, enabled, "yozakura")
	assert.NotContains(t, enabled, "search")
	assert.NotContains(t, enabled, "web", "opencode source off")
	assert.Contains(t, enabled, "off", "force-enabled")
	assert.Equal(t, "1", enabled["filesystem"].Env["DEBUG"], "agents get env values")

	_, err = s.ListTools(context.Background(), "search")
	assert.ErrorContains(t, err, "disabled")
	_, err = s.ListTools(context.Background(), "ghost")
	assert.ErrorContains(t, err, "unknown")
}

func TestYozakuraSpecUsesSelf(t *testing.T) {
	s, _ := newTestService(t)
	sp := s.EnabledSpecs()[0]
	assert.Equal(t, "yozakura", sp.Name)
	assert.Equal(t, []string{"mcp"}, sp.Args)
	assert.NotEmpty(t, sp.Command)
}

func TestToolsCallAndPooling(t *testing.T) {
	s, connects := newTestService(t)
	tools, err := s.tools(json.RawMessage(`{"server":"filesystem"}`))
	assert.NoError(t, err)
	assert.Len(t, tools, 1)
	out, err := s.call(json.RawMessage(`{"server":"filesystem","tool":"whoami","arguments":{"a":1}}`))
	assert.NoError(t, err)
	m := out.(map[string]any)
	assert.Equal(t, `filesystem {"a":1}`, m["text"])
	assert.Equal(t, false, m["isError"])
	assert.Equal(t, int32(1), connects.Load(), "one pooled connection")

	all, err := s.allTools(json.RawMessage(`{"servers":["filesystem","search","yozakura"]}`))
	assert.NoError(t, err)
	rows := all.([]ToolInfo)
	assert.Len(t, rows, 3)
	assert.Equal(t, "yozakura", rows[0].Server)
	assert.True(t, rows[0].ReadOnly)

	st, _ := s.status(nil)
	assert.Equal(t, []string{"filesystem", "search", "yozakura"}, st.(map[string]any)["running"])

	// a dead client is replaced transparently
	s.mu.Lock()
	s.pool["filesystem"].client.Close()
	s.mu.Unlock()
	out, _ = s.call(json.RawMessage(`{"server":"filesystem","tool":"whoami"}`))
	assert.Equal(t, false, out.(map[string]any)["isError"])
	assert.Equal(t, int32(4), connects.Load())

	// unknown tool -> isError result, not an IPC error
	out, err = s.call(json.RawMessage(`{"server":"filesystem","tool":"nope"}`))
	assert.NoError(t, err)
	assert.Equal(t, true, out.(map[string]any)["isError"])
	_, err = s.call(json.RawMessage(`{"server":"filesystem"}`))
	assert.Error(t, err)
}

func TestIdleReap(t *testing.T) {
	s, _ := newTestService(t)
	now := time.Now()
	s.now = func() time.Time { return now }
	_, err := s.ListTools(context.Background(), "filesystem")
	assert.NoError(t, err)
	now = now.Add(idleTimeout + time.Second)
	s.reap()
	s.mu.Lock()
	assert.Empty(t, s.pool)
	s.mu.Unlock()
}

func TestConnectFailureIsReported(t *testing.T) {
	s, _ := newTestService(t)
	s.SetConnect(func(context.Context, mcp.ServerSpec) (*mcp.Client, error) {
		return nil, io.ErrUnexpectedEOF
	})
	out, _ := s.call(json.RawMessage(`{"server":"filesystem","tool":"x"}`))
	assert.Equal(t, true, out.(map[string]any)["isError"])
	st, _ := s.status(nil)
	errs := st.(map[string]any)["serverErrors"].(map[string]string)
	assert.True(t, strings.Contains(errs["filesystem"], "unexpected EOF"))
}

func TestInProcessYozakura(t *testing.T) {
	s := NewService()
	defer s.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	c, err := s.defaultConnect(ctx, s.yozakuraSpec())
	assert.NoError(t, err)
	if c == nil {
		return
	}
	defer c.Close()
	tools, err := c.ListTools(ctx)
	assert.NoError(t, err)
	assert.Greater(t, len(tools), 20)
}
