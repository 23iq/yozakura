package mcp

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func echoServer() *Server {
	return NewServer(Implementation{Name: "test", Version: "1"}, "be nice", []ToolDef{
		{
			Tool: Tool{Name: "echo", Description: "echo text", InputSchema: json.RawMessage(`{"type":"object"}`),
				Annotations: &ToolAnnotations{ReadOnlyHint: Bool(true)}},
			Handler: func(_ context.Context, args json.RawMessage) (*CallToolResult, error) {
				var a struct{ Text string }
				_ = json.Unmarshal(args, &a)
				return TextResult("echo: " + a.Text), nil
			},
		},
		{
			Tool: Tool{Name: "fail", InputSchema: json.RawMessage(`{"type":"object"}`)},
			Handler: func(context.Context, json.RawMessage) (*CallToolResult, error) {
				return nil, fmt.Errorf("boom")
			},
		},
		{
			Tool: Tool{Name: "panic", InputSchema: json.RawMessage(`{"type":"object"}`)},
			Handler: func(context.Context, json.RawMessage) (*CallToolResult, error) {
				panic("oops")
			},
		},
	})
}

// TestMain doubles as a stdio MCP server when spawned by the stdio test.
func TestMain(m *testing.M) {
	if os.Getenv("YZ_MCP_TEST_SERVER") == "1" {
		fmt.Println("banner line that is not JSON")
		_ = echoServer().Serve(context.Background(), os.Stdin, os.Stdout)
		os.Exit(0)
	}
	os.Exit(m.Run())
}

func pipeClient(t *testing.T, srv *Server) *Client {
	cr, sw := io.Pipe()
	sr, cw := io.Pipe()
	go func() {
		_ = srv.Serve(context.Background(), sr, sw)
		sw.Close()
	}()
	c := NewStreamClient(cr, cw)
	t.Cleanup(func() { c.Close() })
	return c
}

func exercise(t *testing.T, c *Client) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	info, err := c.Initialize(ctx, Implementation{Name: "t", Version: "1"})
	if !assert.NoError(t, err) {
		return
	}
	assert.Equal(t, LatestProtocolVersion, info.ProtocolVersion)
	assert.Equal(t, "be nice", info.Instructions)
	tools, err := c.ListTools(ctx)
	assert.NoError(t, err)
	assert.Len(t, tools, 3)
	assert.True(t, tools[0].ReadOnly())
	assert.False(t, tools[1].ReadOnly())
	res, err := c.CallTool(ctx, "echo", map[string]any{"text": "hi"})
	assert.NoError(t, err)
	assert.Equal(t, "echo: hi", res.Text())
	res, err = c.CallTool(ctx, "fail", nil)
	assert.NoError(t, err)
	assert.True(t, res.IsError)
	assert.Equal(t, "boom", res.Text())
	res, err = c.CallTool(ctx, "panic", nil)
	assert.NoError(t, err)
	assert.True(t, res.IsError)
	_, err = c.CallTool(ctx, "missing", nil)
	var rpcErr *RPCError
	assert.ErrorAs(t, err, &rpcErr)
}

func TestPipeRoundTrip(t *testing.T) {
	exercise(t, pipeClient(t, echoServer()))
}

func TestServerProtocolDetails(t *testing.T) {
	in := strings.Join([]string{
		`{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05"}}`,
		`{"jsonrpc":"2.0","method":"notifications/initialized"}`,
		`not json`,
		`{"jsonrpc":"2.0","id":"s","method":"ping"}`,
		`{"jsonrpc":"2.0","id":3,"method":"nope"}`,
		`{"jsonrpc":"2.0","id":4,"method":"initialize","params":{"protocolVersion":"1999-01-01"}}`,
	}, "\n") + "\n"
	var out strings.Builder
	assert.NoError(t, echoServer().Serve(context.Background(), strings.NewReader(in), &out))
	lines := strings.Split(strings.TrimSpace(out.String()), "\n")
	assert.Len(t, lines, 5)
	assert.Contains(t, lines[0], `"protocolVersion":"2024-11-05"`)
	assert.Contains(t, lines[1], `"code":-32700`)
	assert.Contains(t, lines[2], `"id":"s","result":{}`)
	assert.Contains(t, lines[3], `"code":-32601`)
	assert.Contains(t, lines[4], `"protocolVersion":"2025-06-18"`)
}

func TestStdioClient(t *testing.T) {
	t.Setenv("YZ_MCP_TEST_SERVER", "1")
	c, err := StartStdio(os.Args[0], []string{"-test.run=^$"}, map[string]string{"EXTRA": "1"}, "")
	if !assert.NoError(t, err) {
		return
	}
	exercise(t, c)
	assert.NoError(t, c.Close())
	select {
	case <-c.Done():
	case <-time.After(3 * time.Second):
		t.Fatal("client not closed")
	}
}

func TestStdioClientReportsExit(t *testing.T) {
	c, err := StartStdio("sh", []string{"-c", "echo fatal problem >&2; exit 3"}, nil, "")
	if !assert.NoError(t, err) {
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_, err = c.Initialize(ctx, Implementation{Name: "t", Version: "1"})
	assert.Error(t, err)
	<-c.Done()
	assert.Contains(t, c.Err().Error(), "fatal problem")
}

func TestRequestTimeout(t *testing.T) {
	srv := NewServer(Implementation{Name: "slow", Version: "1"}, "", []ToolDef{{
		Tool: Tool{Name: "slow", InputSchema: json.RawMessage(`{}`)},
		Handler: func(ctx context.Context, _ json.RawMessage) (*CallToolResult, error) {
			time.Sleep(300 * time.Millisecond)
			return TextResult("late"), nil
		},
	}})
	c := pipeClient(t, srv)
	ctx, cancel := context.WithTimeout(context.Background(), 50*time.Millisecond)
	defer cancel()
	_, err := c.CallTool(ctx, "slow", nil)
	assert.ErrorIs(t, err, context.DeadlineExceeded)
}

// httpHandler implements Streamable HTTP over echoServer; sse=true answers
// requests as an event stream.
func httpHandler(t *testing.T, sse bool) http.Handler {
	srv := echoServer()
	var mu sync.Mutex
	sessions := 0
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodDelete {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		body, _ := io.ReadAll(r.Body)
		var m Message
		_ = json.Unmarshal(body, &m)
		if m.Method == "initialize" {
			mu.Lock()
			sessions++
			w.Header().Set("Mcp-Session-Id", fmt.Sprintf("sess-%d", sessions))
			mu.Unlock()
		} else if r.Header.Get("Mcp-Session-Id") == "" {
			http.Error(w, "missing session", http.StatusBadRequest)
			return
		} else if r.Header.Get("MCP-Protocol-Version") == "" && !sse {
			http.Error(w, "missing protocol version", http.StatusBadRequest)
			return
		}
		if m.IsNotification() {
			w.WriteHeader(http.StatusAccepted)
			return
		}
		var out strings.Builder
		_ = srv.Serve(context.Background(), strings.NewReader(string(body)+"\n"), &out)
		resp := strings.TrimSpace(out.String())
		if sse {
			w.Header().Set("Content-Type", "text/event-stream")
			fmt.Fprintf(w, ": keepalive\n\nevent: message\ndata: %s\n\n", resp)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprint(w, resp)
	})
}

func TestHTTPClientJSON(t *testing.T) {
	ts := httptest.NewServer(httpHandler(t, false))
	defer ts.Close()
	c := StartHTTP(ts.URL, map[string]string{"X-Test": "1"}, ts.Client())
	defer c.Close()
	exercise(t, c)
}

func TestHTTPClientSSE(t *testing.T) {
	ts := httptest.NewServer(httpHandler(t, true))
	defer ts.Close()
	c := StartHTTP(ts.URL, nil, ts.Client())
	defer c.Close()
	exercise(t, c)
}

func TestHTTPClientError(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, "nope", http.StatusUnauthorized)
	}))
	defer ts.Close()
	c := StartHTTP(ts.URL, nil, ts.Client())
	defer c.Close()
	_, err := c.Initialize(context.Background(), Implementation{Name: "t", Version: "1"})
	assert.ErrorContains(t, err, "401")
}

func TestLegacySSEClient(t *testing.T) {
	srv := echoServer()
	frames := make(chan string, 16)
	mux := http.NewServeMux()
	mux.HandleFunc("/sse", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/event-stream")
		fmt.Fprint(w, "event: endpoint\ndata: /messages?sid=1\n\n")
		w.(http.Flusher).Flush()
		for {
			select {
			case f := <-frames:
				fmt.Fprintf(w, "event: message\ndata: %s\n\n", f)
				w.(http.Flusher).Flush()
			case <-r.Context().Done():
				return
			}
		}
	})
	mux.HandleFunc("/messages", func(w http.ResponseWriter, r *http.Request) {
		assert.Equal(t, "1", r.URL.Query().Get("sid"))
		body, _ := io.ReadAll(r.Body)
		w.WriteHeader(http.StatusAccepted)
		go func() {
			var out strings.Builder
			_ = srv.Serve(context.Background(), strings.NewReader(string(body)+"\n"), &out)
			sc := bufio.NewScanner(strings.NewReader(out.String()))
			for sc.Scan() {
				frames <- sc.Text()
			}
		}()
	})
	ts := httptest.NewServer(mux)
	defer ts.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	c, err := StartSSE(ctx, ts.URL+"/sse", nil, ts.Client())
	if !assert.NoError(t, err) {
		return
	}
	defer c.Close()
	exercise(t, c)
}

func TestConnectDispatch(t *testing.T) {
	_, err := Connect(context.Background(), ServerSpec{Name: "x", Transport: TransportStdio}, Implementation{})
	assert.ErrorContains(t, err, "no command")
	ts := httptest.NewServer(httpHandler(t, false))
	defer ts.Close()
	c, err := Connect(context.Background(), ServerSpec{Name: "h", Transport: TransportHTTP, URL: ts.URL}, Implementation{Name: "t", Version: "1"})
	if assert.NoError(t, err) {
		tools, err := c.ListTools(context.Background())
		assert.NoError(t, err)
		assert.Len(t, tools, 3)
		c.Close()
	}
}

func TestResultHelpers(t *testing.T) {
	r := JSONResult([]int{1, 2})
	assert.Equal(t, map[string]any{"result": []int{1, 2}}, r.StructuredContent)
	r = &CallToolResult{Content: []Content{{Type: "text", Text: "a"}, {Type: "image", MimeType: "image/png"}}}
	assert.Equal(t, "a\n[image image/png]", r.Text())
}
