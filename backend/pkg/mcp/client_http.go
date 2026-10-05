package mcp

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"
)

// StartHTTP connects to a Streamable HTTP server: every frame is a POST,
// answered with JSON or an SSE stream carrying the response.
func StartHTTP(endpoint string, headers map[string]string, hc *http.Client) *Client {
	if hc == nil {
		hc = &http.Client{}
	}
	c := newClient()
	var smu sync.Mutex
	session := ""
	proto := ""
	c.send = func(ctx context.Context, m *Message) error {
		body, err := json.Marshal(m)
		if err != nil {
			return err
		}
		req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(body))
		if err != nil {
			return err
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Accept", "application/json, text/event-stream")
		for k, v := range headers {
			req.Header.Set(k, v)
		}
		smu.Lock()
		if session != "" {
			req.Header.Set("Mcp-Session-Id", session)
		}
		if proto != "" {
			req.Header.Set("MCP-Protocol-Version", proto)
		}
		smu.Unlock()
		resp, err := hc.Do(req)
		if err != nil {
			return err
		}
		if sid := resp.Header.Get("Mcp-Session-Id"); sid != "" {
			smu.Lock()
			session = sid
			smu.Unlock()
		}
		if resp.StatusCode >= 300 {
			data, _ := io.ReadAll(io.LimitReader(resp.Body, 2048))
			resp.Body.Close()
			return fmt.Errorf("http %d: %s", resp.StatusCode, strings.TrimSpace(string(data)))
		}
		if m.Method == "" || len(m.ID) == 0 {
			resp.Body.Close() // notification or our response: 202 expected
			return nil
		}
		ct := resp.Header.Get("Content-Type")
		if strings.HasPrefix(ct, "text/event-stream") {
			go func() {
				defer resp.Body.Close()
				readSSE(resp.Body, func(event, data string) bool {
					var f Message
					if json.Unmarshal([]byte(data), &f) == nil {
						c.deliver(&f)
						if f.Method == "" && string(f.ID) == string(m.ID) {
							return false
						}
					}
					return true
				})
			}()
			return nil
		}
		defer resp.Body.Close()
		data, err := io.ReadAll(io.LimitReader(resp.Body, 64*1024*1024))
		if err != nil {
			return err
		}
		data = bytes.TrimSpace(data)
		if len(data) > 0 && data[0] == '[' {
			var batch []Message
			if json.Unmarshal(data, &batch) == nil {
				for i := range batch {
					c.deliver(&batch[i])
				}
			}
			return nil
		}
		var f Message
		if err := json.Unmarshal(data, &f); err != nil {
			return fmt.Errorf("invalid response: %w", err)
		}
		if m.Method == "initialize" && f.Result != nil {
			var ir InitializeResult
			if json.Unmarshal(f.Result, &ir) == nil && ir.ProtocolVersion != "" {
				smu.Lock()
				proto = ir.ProtocolVersion
				smu.Unlock()
			}
		}
		c.deliver(&f)
		return nil
	}
	c.closeFn = func() error {
		smu.Lock()
		sid := session
		smu.Unlock()
		if sid == "" {
			return nil
		}
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		defer cancel()
		req, err := http.NewRequestWithContext(ctx, http.MethodDelete, endpoint, nil)
		if err == nil {
			req.Header.Set("Mcp-Session-Id", sid)
			if resp, err := hc.Do(req); err == nil {
				resp.Body.Close()
			}
		}
		return nil
	}
	return c
}

// StartSSE connects to a legacy HTTP+SSE server (2024-11-05): a GET stream
// announces a POST endpoint; responses arrive on the stream.
func StartSSE(ctx context.Context, endpoint string, headers map[string]string, hc *http.Client) (*Client, error) {
	if hc == nil {
		hc = &http.Client{}
	}
	sctx, cancel := context.WithCancel(context.Background())
	req, err := http.NewRequestWithContext(sctx, http.MethodGet, endpoint, nil)
	if err != nil {
		cancel()
		return nil, err
	}
	req.Header.Set("Accept", "text/event-stream")
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	resp, err := hc.Do(req)
	if err != nil {
		cancel()
		return nil, err
	}
	if resp.StatusCode >= 300 {
		resp.Body.Close()
		cancel()
		return nil, fmt.Errorf("sse connect: http %d", resp.StatusCode)
	}
	c := newClient()
	postURL := make(chan string, 1)
	go func() {
		defer resp.Body.Close()
		sent := false
		readSSE(resp.Body, func(event, data string) bool {
			if event == "endpoint" && !sent {
				sent = true
				postURL <- resolveURL(endpoint, strings.TrimSpace(data))
				return true
			}
			var f Message
			if json.Unmarshal([]byte(data), &f) == nil {
				c.deliver(&f)
			}
			return true
		})
		c.fail(errors.New("sse stream closed"))
	}()
	var post string
	select {
	case post = <-postURL:
	case <-ctx.Done():
		cancel()
		return nil, ctx.Err()
	case <-time.After(15 * time.Second):
		cancel()
		return nil, errors.New("sse: no endpoint event")
	}
	c.send = func(ctx context.Context, m *Message) error {
		body, _ := json.Marshal(m)
		req, err := http.NewRequestWithContext(ctx, http.MethodPost, post, bytes.NewReader(body))
		if err != nil {
			return err
		}
		req.Header.Set("Content-Type", "application/json")
		for k, v := range headers {
			req.Header.Set(k, v)
		}
		r, err := hc.Do(req)
		if err != nil {
			return err
		}
		r.Body.Close()
		if r.StatusCode >= 300 {
			return fmt.Errorf("sse post: http %d", r.StatusCode)
		}
		return nil
	}
	c.closeFn = func() error { cancel(); return nil }
	return c, nil
}

func resolveURL(base, ref string) string {
	b, err := url.Parse(base)
	if err != nil {
		return ref
	}
	r, err := url.Parse(ref)
	if err != nil {
		return ref
	}
	return b.ResolveReference(r).String()
}

// readSSE parses an event stream; fn returns false to stop.
func readSSE(r io.Reader, fn func(event, data string) bool) {
	sc := bufio.NewScanner(r)
	sc.Buffer(make([]byte, 0, 64*1024), 32*1024*1024)
	event, data := "", []string{}
	for sc.Scan() {
		line := sc.Text()
		if line == "" {
			if len(data) > 0 {
				if !fn(event, strings.Join(data, "\n")) {
					return
				}
			}
			event, data = "", data[:0]
			continue
		}
		if strings.HasPrefix(line, ":") {
			continue
		}
		field, value, _ := strings.Cut(line, ":")
		value = strings.TrimPrefix(value, " ")
		switch field {
		case "event":
			event = value
		case "data":
			data = append(data, value)
		}
	}
	if len(data) > 0 {
		fn(event, strings.Join(data, "\n"))
	}
}
