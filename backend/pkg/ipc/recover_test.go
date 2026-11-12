package ipc

import (
	"bufio"
	"encoding/json"
	"errors"
	"net"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

type panicMarshaler struct{}

func (panicMarshaler) MarshalJSON() ([]byte, error) { panic("marshal boom") }

func startServer(t *testing.T, svcs ...*Service) (net.Conn, *bufio.Reader) {
	t.Helper()
	sock := filepath.Join(t.TempDir(), "s.sock")
	srv := NewServer(sock)
	for _, s := range svcs {
		srv.Register(s)
	}
	if err := srv.Listen(); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(srv.Close)
	go srv.Serve()
	conn, err := net.Dial("unix", sock)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { conn.Close() })
	_ = conn.SetReadDeadline(time.Now().Add(3 * time.Second))
	return conn, bufio.NewReader(conn)
}

func readResponse(t *testing.T, r *bufio.Reader) Response {
	t.Helper()
	line, err := r.ReadBytes('\n')
	if err != nil {
		t.Fatalf("read: %v", err)
	}
	var resp Response
	if err := json.Unmarshal(line, &resp); err != nil {
		t.Fatalf("decode %q: %v", line, err)
	}
	return resp
}

// A panicking handler (ordered or async, or a result that panics while
// marshalling) answers an error and the connection keeps serving.
func TestHandlerPanicIsAnsweredAsError(t *testing.T) {
	conn, r := startServer(t, &Service{
		Name: "t",
		Methods: map[string]HandlerFunc{
			"boom":    func(json.RawMessage) (any, error) { panic("handler boom") },
			"aboom":   func(json.RawMessage) (any, error) { panic(errors.New("async boom")) },
			"marshal": func(json.RawMessage) (any, error) { return panicMarshaler{}, nil },
			"ok":      func(json.RawMessage) (any, error) { return "fine", nil },
		},
		Async: map[string]bool{"aboom": true},
	})
	for i, method := range []string{"t.boom", "t.aboom", "t.marshal"} {
		req, _ := json.Marshal(Request{ID: json.RawMessage(`1`), Method: method})
		_, _ = conn.Write(append(req, '\n'))
		resp := readResponse(t, r)
		if !strings.Contains(resp.Error, "internal error in "+method) {
			t.Fatalf("case %d %s: error = %q", i, method, resp.Error)
		}
	}
	_, _ = conn.Write([]byte(`{"id":2,"method":"t.ok"}` + "\n"))
	if resp := readResponse(t, r); resp.Error != "" || string(resp.Result) != `"fine"` {
		t.Fatalf("after panics: %+v", resp)
	}
}

// A service whose Subscribe panics does not end the stream of the others.
func TestSubscribePanicKeepsOtherServicesStreaming(t *testing.T) {
	conn, r := startServer(t,
		&Service{Name: "bad", Subscribe: func(*Subscriber) { panic("subscribe boom") }},
		&Service{Name: "good", Subscribe: func(sub *Subscriber) {
			time.Sleep(50 * time.Millisecond) // after the panic
			sub.Send("good", "hello")
			sub.Send("good", panicMarshaler{})
			sub.Send("good", "still here")
			<-sub.StopCh()
		}},
	)
	_, _ = conn.Write([]byte(`{"id":1,"method":"subscribe","params":{"services":["bad","good"]}}` + "\n"))
	want := []string{`{"service":"good","data":"hello"}`, `{"error":"marshal failed"}`, `{"service":"good","data":"still here"}`}
	for _, w := range want {
		resp := readResponse(t, r)
		if string(resp.Result) != w {
			t.Fatalf("event = %s, want %s", resp.Result, w)
		}
	}
}
