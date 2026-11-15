package ipc

import (
	"bufio"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"path/filepath"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

type codedErr struct{}

func (codedErr) Error() string       { return "cannot write to /ro" }
func (codedErr) ErrorCode() string   { return "no_write" }
func (codedErr) ErrorArgs() []string { return []string{"/ro"} }

// A coded error goes out with its code and arguments next to the message
// (also wrapped, also from an async method); a plain one as before; an
// unknown method has a code too. The client keeps them.
func TestErrorCodes(t *testing.T) {
	sock := filepath.Join(t.TempDir(), "s.sock")
	srv := NewServer(sock)
	srv.Register(&Service{
		Name: "t",
		Methods: map[string]HandlerFunc{
			"coded":   func(json.RawMessage) (any, error) { return nil, fmt.Errorf("wrapped: %w", codedErr{}) },
			"async":   func(json.RawMessage) (any, error) { return nil, codedErr{} },
			"plain":   func(json.RawMessage) (any, error) { return nil, errors.New("boom") },
			"success": func(json.RawMessage) (any, error) { return 1, nil },
		},
		Async: map[string]bool{"async": true},
	})
	assert.NoError(t, srv.Listen())
	defer srv.Close()
	go srv.Serve()

	conn, err := net.Dial("unix", sock)
	assert.NoError(t, err)
	defer conn.Close()
	r := bufio.NewReader(conn)
	_ = conn.SetReadDeadline(time.Now().Add(3 * time.Second))
	for _, c := range []struct{ method, want string }{
		{"t.coded", `{"id":1,"error":"wrapped: cannot write to /ro","code":"no_write","errorArgs":["/ro"]}`},
		{"t.async", `{"id":1,"error":"cannot write to /ro","code":"no_write","errorArgs":["/ro"]}`},
		{"t.plain", `{"id":1,"error":"boom"}`},
		{"t.nope", `{"id":1,"error":"unknown method: t.nope","code":"unknown_method"}`},
		{"t.success", `{"id":1,"result":1}`},
	} {
		_, _ = conn.Write([]byte(`{"id":1,"method":"` + c.method + `"}` + "\n"))
		line, err := r.ReadBytes('\n')
		assert.NoError(t, err)
		assert.JSONEq(t, c.want, string(line), c.method)
	}

	_, err = NewClient(sock).Call("t.async", nil)
	var re *RemoteError
	if assert.ErrorAs(t, err, &re) {
		assert.Equal(t, "no_write", re.Code)
		assert.Equal(t, []string{"/ro"}, re.Args)
		assert.Equal(t, "cannot write to /ro", err.Error())
	}
}
