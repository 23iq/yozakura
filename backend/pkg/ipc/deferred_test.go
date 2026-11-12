package ipc

import (
	"bufio"
	"encoding/json"
	"sync"
	"testing"
	"time"
)

// readResponse reads the next answer on a test connection.
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

// A Deferred result: the handler runs in order with the connection's
// ordered requests, its answer comes when the Deferred returns, and the
// requests behind it are answered meanwhile.
func TestDeferredRunsInOrderAndAnswersLater(t *testing.T) {
	var mu sync.Mutex
	var order []string
	note := func(s string) {
		mu.Lock()
		order = append(order, s)
		mu.Unlock()
	}
	release := make(chan struct{})
	conn, r := startServer(t, &Service{
		Name: "t",
		Methods: map[string]HandlerFunc{
			"slow": func(json.RawMessage) (any, error) {
				time.Sleep(50 * time.Millisecond)
				note("slow")
				return "slow", nil
			},
			"wait": func(json.RawMessage) (any, error) {
				note("wait")
				return Deferred(func() (any, error) { <-release; return "waited", nil }), nil
			},
			"fast": func(json.RawMessage) (any, error) { note("fast"); return "fast", nil },
		},
	})
	_, _ = conn.Write([]byte(`{"id":1,"method":"t.slow"}` + "\n" + `{"id":2,"method":"t.wait"}` + "\n" + `{"id":3,"method":"t.fast"}` + "\n"))
	if got := readResponse(t, r); string(got.ID) != "1" {
		t.Fatalf("first answer %s, want 1", got.ID)
	}
	if got := readResponse(t, r); string(got.ID) != "3" || string(got.Result) != `"fast"` {
		t.Fatalf("second answer %+v, want 3 (not held up by the wait)", got)
	}
	close(release)
	if got := readResponse(t, r); string(got.ID) != "2" || string(got.Result) != `"waited"` {
		t.Fatalf("third answer %+v, want 2 waited", got)
	}
	mu.Lock()
	defer mu.Unlock()
	if len(order) != 3 || order[0] != "slow" || order[1] != "wait" || order[2] != "fast" {
		t.Fatalf("handlers ran %v, want slow wait fast", order)
	}
}
