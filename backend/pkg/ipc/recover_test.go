package ipc

import (
	"bufio"
	"encoding/json"
	"errors"
	"net"
	"os"
	"os/exec"
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

// panicChildEnv selects the panic case a re-executed test binary runs.
const panicChildEnv = "YOZAKURA_IPC_PANIC_CHILD"

// runPanicChild is the child half of TestServicePanicCrashesTheDaemon: it
// serves one service, sends the request that panics, and returns only if
// the process was not taken down.
func runPanicChild(t *testing.T, which string) {
	conn, r := startServer(t,
		&Service{
			Name: "t",
			Methods: map[string]HandlerFunc{
				"boom":    func(json.RawMessage) (any, error) { panic("handler boom") },
				"aboom":   func(json.RawMessage) (any, error) { panic(errors.New("async boom")) },
				"marshal": func(json.RawMessage) (any, error) { return panicMarshaler{}, nil },
			},
			Async: map[string]bool{"aboom": true},
		},
		&Service{Name: "bad", Subscribe: func(*Subscriber) { panic("subscribe boom") }},
		&Service{Name: "ev", Subscribe: func(sub *Subscriber) {
			sub.Send("ev", panicMarshaler{})
			<-sub.StopCh()
		}},
	)
	req := map[string]string{
		"handler":   `{"id":1,"method":"t.boom"}`,
		"async":     `{"id":1,"method":"t.aboom"}`,
		"result":    `{"id":1,"method":"t.marshal"}`,
		"subscribe": `{"id":1,"method":"subscribe","params":{"services":["bad"]}}`,
		"event":     `{"id":1,"method":"subscribe","params":{"services":["ev"]}}`,
	}[which]
	_, _ = conn.Write([]byte(req + "\n"))
	_, _ = r.ReadBytes('\n') // blocks until the process dies (or the deadline)
	time.Sleep(time.Second)
}

// A panic in service code is logged with its stack and then still kills the
// daemon (it is started again on the next call): recovering it would leave
// a mutex the handler held locked and the service deadlocked for good.
func TestServicePanicCrashesTheDaemon(t *testing.T) {
	if which := os.Getenv(panicChildEnv); which != "" {
		runPanicChild(t, which)
		return
	}
	cases := map[string]string{
		"handler":   "[ipc] panic in t.boom: handler boom",
		"async":     "[ipc] panic in t.aboom: async boom",
		"result":    "[ipc] panic in t.marshal: marshal boom",
		"subscribe": "[ipc] panic in bad subscribe: subscribe boom",
		"event":     "[ipc] panic in marshalling a ev event: marshal boom",
	}
	for which, wantLog := range cases {
		t.Run(which, func(t *testing.T) {
			t.Parallel()
			cmd := exec.Command(os.Args[0], "-test.run=^TestServicePanicCrashesTheDaemon$")
			cmd.Env = append(os.Environ(), panicChildEnv+"="+which)
			out, err := cmd.CombinedOutput()
			var exitErr *exec.ExitError
			if !errors.As(err, &exitErr) || exitErr.ExitCode() == 0 {
				t.Fatalf("the process survived the panic (err %v):\n%s", err, out)
			}
			if !strings.Contains(string(out), wantLog) || !strings.Contains(string(out), "runtime/debug.Stack") {
				t.Fatalf("missing the logged panic %q with its stack:\n%s", wantLog, out)
			}
		})
	}
}
