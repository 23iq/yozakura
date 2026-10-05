package mcp

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
)

// DefaultTimeout bounds a single request when the caller's ctx has none.
const DefaultTimeout = 60 * time.Second

// ErrClosed is returned for calls on a closed client.
var ErrClosed = errors.New("mcp client closed")

// Client talks to one MCP server over any transport.
type Client struct {
	mu      sync.Mutex
	next    int64
	pending map[string]chan *Message
	closed  chan struct{}
	once    sync.Once
	err     error

	send    func(ctx context.Context, m *Message) error
	closeFn func() error

	Info InitializeResult
}

func newClient() *Client {
	return &Client{pending: map[string]chan *Message{}, closed: make(chan struct{})}
}

// Done is closed when the transport dies or Close is called.
func (c *Client) Done() <-chan struct{} { return c.closed }

// Err returns the reason the client stopped, if any.
func (c *Client) Err() error {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.err
}

func (c *Client) fail(err error) {
	c.once.Do(func() {
		c.mu.Lock()
		if err == nil {
			err = ErrClosed
		}
		c.err = err
		c.mu.Unlock()
		close(c.closed)
	})
}

// Close shuts down the transport.
func (c *Client) Close() error {
	var err error
	if c.closeFn != nil {
		err = c.closeFn()
	}
	c.fail(ErrClosed)
	return err
}

// deliver routes an incoming frame: responses to their waiter, server
// requests get a minimal answer (we support no client features).
func (c *Client) deliver(m *Message) {
	if m.Method != "" {
		if !m.IsRequest() {
			return
		}
		resp := &Message{JSONRPC: "2.0", ID: m.ID}
		switch m.Method {
		case "ping":
			resp.Result = json.RawMessage("{}")
		case "roots/list":
			resp.Result = json.RawMessage(`{"roots":[]}`)
		default:
			resp.Error = &RPCError{Code: CodeMethodNotFound, Message: "client does not support " + m.Method}
		}
		go c.send(context.Background(), resp)
		return
	}
	key := string(m.ID)
	c.mu.Lock()
	ch := c.pending[key]
	delete(c.pending, key)
	c.mu.Unlock()
	if ch != nil {
		ch <- m
	}
}

func (c *Client) request(ctx context.Context, method string, params any) (json.RawMessage, error) {
	if _, ok := ctx.Deadline(); !ok {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(ctx, DefaultTimeout)
		defer cancel()
	}
	select {
	case <-c.closed:
		return nil, c.Err()
	default:
	}
	c.mu.Lock()
	c.next++
	id := json.RawMessage(strconv.FormatInt(c.next, 10))
	ch := make(chan *Message, 1)
	c.pending[string(id)] = ch
	c.mu.Unlock()
	m := &Message{JSONRPC: "2.0", ID: id, Method: method}
	if params != nil {
		data, err := json.Marshal(params)
		if err != nil {
			return nil, err
		}
		m.Params = data
	}
	drop := func() {
		c.mu.Lock()
		delete(c.pending, string(id))
		c.mu.Unlock()
	}
	if err := c.send(ctx, m); err != nil {
		drop()
		return nil, err
	}
	select {
	case resp := <-ch:
		if resp.Error != nil {
			return nil, resp.Error
		}
		return resp.Result, nil
	case <-ctx.Done():
		drop()
		go c.notify(context.Background(), "notifications/cancelled", map[string]any{"requestId": id, "reason": "timeout"})
		return nil, fmt.Errorf("%s: %w", method, ctx.Err())
	case <-c.closed:
		return nil, c.Err()
	}
}

func (c *Client) notify(ctx context.Context, method string, params any) error {
	m := &Message{JSONRPC: "2.0", Method: method}
	if params != nil {
		data, _ := json.Marshal(params)
		m.Params = data
	}
	return c.send(ctx, m)
}

// Initialize performs the handshake and sends notifications/initialized.
func (c *Client) Initialize(ctx context.Context, info Implementation) (*InitializeResult, error) {
	raw, err := c.request(ctx, "initialize", map[string]any{
		"protocolVersion": LatestProtocolVersion,
		"capabilities":    map[string]any{},
		"clientInfo":      info,
	})
	if err != nil {
		return nil, err
	}
	var res InitializeResult
	if err := json.Unmarshal(raw, &res); err != nil {
		return nil, fmt.Errorf("initialize result: %w", err)
	}
	c.Info = res
	if err := c.notify(ctx, "notifications/initialized", nil); err != nil {
		return nil, err
	}
	return &res, nil
}

// ListTools returns every tool, following pagination cursors.
func (c *Client) ListTools(ctx context.Context) ([]Tool, error) {
	var all []Tool
	cursor := ""
	for page := 0; page < 50; page++ {
		var params any
		if cursor != "" {
			params = map[string]any{"cursor": cursor}
		}
		raw, err := c.request(ctx, "tools/list", params)
		if err != nil {
			return nil, err
		}
		var res struct {
			Tools      []Tool `json:"tools"`
			NextCursor string `json:"nextCursor"`
		}
		if err := json.Unmarshal(raw, &res); err != nil {
			return nil, fmt.Errorf("tools/list result: %w", err)
		}
		all = append(all, res.Tools...)
		if res.NextCursor == "" {
			break
		}
		cursor = res.NextCursor
	}
	return all, nil
}

// CallTool invokes a tool. args may be nil.
func (c *Client) CallTool(ctx context.Context, name string, args any) (*CallToolResult, error) {
	if args == nil {
		args = map[string]any{}
	}
	raw, err := c.request(ctx, "tools/call", map[string]any{"name": name, "arguments": args})
	if err != nil {
		return nil, err
	}
	var res CallToolResult
	if err := json.Unmarshal(raw, &res); err != nil {
		return nil, fmt.Errorf("tools/call result: %w", err)
	}
	return &res, nil
}

// readLines feeds newline-delimited JSON frames to the client.
func (c *Client) readLines(r io.Reader) error {
	sc := bufio.NewScanner(r)
	sc.Buffer(make([]byte, 0, 64*1024), 32*1024*1024)
	for sc.Scan() {
		line := bytes.TrimSpace(sc.Bytes())
		if len(line) == 0 || line[0] != '{' {
			continue // some servers print banners on stdout
		}
		var m Message
		if json.Unmarshal(line, &m) == nil {
			c.deliver(&m)
		}
	}
	return sc.Err()
}

// NewStreamClient wraps an existing pipe pair (tests, in-process servers).
func NewStreamClient(r io.Reader, w io.WriteCloser) *Client {
	c := newStreamClient(r, w)
	go func() {
		err := c.readLines(r)
		if err == nil {
			err = io.EOF
		}
		c.fail(fmt.Errorf("server stream ended: %w", err))
	}()
	return c
}

func newStreamClient(r io.Reader, w io.WriteCloser) *Client {
	c := newClient()
	var wmu sync.Mutex
	c.send = func(_ context.Context, m *Message) error {
		data, err := json.Marshal(m)
		if err != nil {
			return err
		}
		wmu.Lock()
		defer wmu.Unlock()
		_, err = w.Write(append(data, '\n'))
		return err
	}
	c.closeFn = w.Close
	return c
}

// StartStdio spawns a stdio server. env entries are added to the
// inherited environment. Stderr is kept (last 4 KiB) for error reports.
func StartStdio(command string, args []string, env map[string]string, dir string) (*Client, error) {
	cmd := exec.Command(command, args...)
	cmd.Env = os.Environ()
	for k, v := range env {
		cmd.Env = append(cmd.Env, k+"="+v)
	}
	cmd.Dir = dir
	// Own process group so Close can stop npx-style launchers together with
	// the grandchildren that inherit our pipes; die with the daemon.
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true, Pdeathsig: syscall.SIGTERM}
	// Don't let a lingering grandchild holding stderr block Wait forever.
	cmd.WaitDelay = 2 * time.Second
	stdin, err := cmd.StdinPipe()
	if err != nil {
		return nil, err
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return nil, err
	}
	tail := &tailBuffer{max: 4096}
	cmd.Stderr = tail
	if err := cmd.Start(); err != nil {
		return nil, err
	}
	c := newStreamClient(stdout, stdin)
	exited := make(chan struct{})
	go func() {
		_ = c.readLines(stdout)
		select { // let the exit status explain why the stream ended
		case <-exited:
		case <-time.After(2 * time.Second):
			c.fail(errors.New("server closed stdout"))
		}
	}()
	go func() {
		werr := cmd.Wait()
		close(exited)
		msg := strings.TrimSpace(tail.String())
		if msg != "" {
			c.fail(fmt.Errorf("server exited (%v): %s", werr, msg))
		} else {
			c.fail(fmt.Errorf("server exited: %v", werr))
		}
	}()
	pgid := cmd.Process.Pid
	c.closeFn = func() error {
		stdin.Close()
		select {
		case <-exited:
		case <-time.After(2 * time.Second):
			_ = syscall.Kill(-pgid, syscall.SIGTERM)
			select {
			case <-exited:
			case <-time.After(time.Second):
				_ = syscall.Kill(-pgid, syscall.SIGKILL)
				<-exited
			}
		}
		// The server is gone; take down anything it left in its group.
		_ = syscall.Kill(-pgid, syscall.SIGKILL)
		return nil
	}
	return c, nil
}

type tailBuffer struct {
	mu  sync.Mutex
	buf []byte
	max int
}

func (t *tailBuffer) Write(p []byte) (int, error) {
	t.mu.Lock()
	defer t.mu.Unlock()
	t.buf = append(t.buf, p...)
	if len(t.buf) > t.max {
		t.buf = t.buf[len(t.buf)-t.max:]
	}
	return len(p), nil
}

func (t *tailBuffer) String() string {
	t.mu.Lock()
	defer t.mu.Unlock()
	return string(t.buf)
}

// Connect starts a client for spec and runs the initialize handshake.
func Connect(ctx context.Context, spec ServerSpec, info Implementation) (*Client, error) {
	var c *Client
	var err error
	switch spec.Transport {
	case TransportHTTP:
		c = StartHTTP(spec.URL, spec.Headers, nil)
	case TransportSSE:
		c, err = StartSSE(ctx, spec.URL, spec.Headers, nil)
	default:
		if spec.Command == "" {
			return nil, fmt.Errorf("server %s: no command", spec.Name)
		}
		c, err = StartStdio(spec.Command, spec.Args, spec.Env, spec.Cwd)
	}
	if err != nil {
		return nil, err
	}
	if _, err := c.Initialize(ctx, info); err != nil {
		c.Close()
		return nil, err
	}
	return c, nil
}
