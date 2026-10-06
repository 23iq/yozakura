package ipc

import (
	"bufio"
	"encoding/json"
	"net"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestAsyncMethodsDoNotBlockTheConnection(t *testing.T) {
	sock := filepath.Join(t.TempDir(), "s.sock")
	srv := NewServer(sock)
	release := make(chan struct{})
	srv.Register(&Service{
		Name: "t",
		Methods: map[string]HandlerFunc{
			"slow": func(json.RawMessage) (any, error) { <-release; return "slow", nil },
			"fast": func(json.RawMessage) (any, error) { return "fast", nil },
		},
		Async: map[string]bool{"slow": true},
	})
	assert.NoError(t, srv.Listen())
	defer srv.Close()
	go srv.Serve()

	conn, err := net.Dial("unix", sock)
	assert.NoError(t, err)
	defer conn.Close()
	_, _ = conn.Write([]byte(`{"id":1,"method":"t.slow"}` + "\n" + `{"id":2,"method":"t.fast"}` + "\n"))
	r := bufio.NewReader(conn)
	_ = conn.SetReadDeadline(time.Now().Add(3 * time.Second))
	line, err := r.ReadBytes('\n')
	assert.NoError(t, err)
	assert.JSONEq(t, `{"id":2,"result":"fast"}`, string(line))
	close(release)
	line, err = r.ReadBytes('\n')
	assert.NoError(t, err)
	assert.JSONEq(t, `{"id":1,"result":"slow"}`, string(line))
}

// A stopping instance must not delete the socket its successor bound at
// the same path (the reload race that left the survivor unreachable).
func TestCloseKeepsSuccessorSocket(t *testing.T) {
	sock := filepath.Join(t.TempDir(), "s.sock")
	old := NewServer(sock)
	if err := old.Listen(); err != nil {
		t.Fatal(err)
	}
	next := NewServer(sock)
	if err := next.Listen(); err != nil {
		t.Fatal(err)
	}
	defer next.Close()
	old.Close()
	if _, err := os.Lstat(sock); err != nil {
		t.Fatalf("successor socket was removed: %v", err)
	}
	next.Close()
	if _, err := os.Lstat(sock); !os.IsNotExist(err) {
		t.Fatalf("owner Close must remove its socket, err=%v", err)
	}
}
