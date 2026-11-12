package preview

import (
	"bufio"
	"encoding/json"
	"fmt"
	"net"
	"path/filepath"
	"testing"
	"time"

	"yozakura/backend/pkg/ipc"
)

// The real ipc.Server with the real service: a window writes preview.set
// and preview.commit in one burst on one connection (as BackendService
// does when Apply follows a change at once). The commit must end the
// staging after the set: the main shell (a subscriber) holds the value
// when it is told to write, the answer is "written", nothing stays staged.
// With commit async on the server, it overtook the set in most runs.
func TestCommitNeverOvertakesAnEarlierSet(t *testing.T) {
	for _, slowFirst := range []bool{false, true} {
		t.Run(fmt.Sprintf("slowFirst=%v", slowFirst), func(t *testing.T) {
			s := NewService()
			sock := filepath.Join(t.TempDir(), "s.sock")
			srv := ipc.NewServer(sock)
			s.Register(srv)
			// an ordered call that takes a while in front of the burst
			srv.Register(&ipc.Service{Name: "slow", Methods: map[string]ipc.HandlerFunc{
				"op": func(json.RawMessage) (any, error) { time.Sleep(2 * time.Millisecond); return true, nil },
			}})
			if err := srv.Listen(); err != nil {
				t.Fatal(err)
			}
			t.Cleanup(srv.Close)
			go srv.Serve()

			shell := fakeShell(t, sock)
			deadline := time.Now().Add(5 * time.Second)
			for {
				s.mu.Lock()
				n := len(s.subs)
				s.mu.Unlock()
				if n > 0 {
					break
				}
				if time.Now().After(deadline) {
					t.Fatal("the main shell did not subscribe")
				}
				time.Sleep(time.Millisecond)
			}
			win := dial(t, sock)
			r := bufio.NewReader(win)
			const runs = 200
			for i := 0; i < runs; i++ {
				want := fmt.Sprintf(`"v%d"`, i)
				burst := ""
				if slowFirst {
					burst += `{"id":1,"method":"slow.op"}` + "\n"
				}
				burst += `{"id":2,"method":"preview.set","params":{"owner":"settings","key":"bar.position","value":` + want + "}}\n" +
					`{"id":3,"method":"preview.commit","params":{"owner":"settings"}}` + "\n"
				if _, err := win.Write([]byte(burst)); err != nil {
					t.Fatal(err)
				}
				n := 2
				if slowFirst {
					n = 3
				}
				var commit ipc.Response
				for j := 0; j < n; j++ {
					resp := read(t, r)
					if string(resp.ID) == "3" {
						commit = resp
					}
				}
				if commit.Error != "" || string(commit.Result) == "" {
					t.Fatalf("run %d: commit answered %+v", i, commit)
				}
				var res struct{ OK, Written bool }
				_ = json.Unmarshal(commit.Result, &res)
				got := <-shell
				if !res.OK || !res.Written || got != want {
					t.Fatalf("run %d: commit %s, the main shell wrote bar.position=%s, want %s", i, commit.Result, got, want)
				}
				if st := s.Staged(); len(st) != 0 {
					t.Fatalf("run %d: still staged after the commit: %v", i, st)
				}
			}
		})
	}
}

// The main shell's request socket also carries slow ordered calls: its
// preview.written behind one still reaches the waiting commit in time.
func TestWrittenIsNotQueuedBehindSlowCalls(t *testing.T) {
	old := AckWait
	AckWait = 500 * time.Millisecond
	t.Cleanup(func() { AckWait = old })
	s := NewService()
	sock := filepath.Join(t.TempDir(), "s.sock")
	srv := ipc.NewServer(sock)
	s.Register(srv)
	release := make(chan struct{})
	srv.Register(&ipc.Service{Name: "slow", Methods: map[string]ipc.HandlerFunc{
		"op": func(json.RawMessage) (any, error) { <-release; return true, nil },
	}})
	if err := srv.Listen(); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(srv.Close)
	t.Cleanup(func() { close(release) })
	go srv.Serve()

	sub := ipc.NewSubscriber(8)
	sub.ClientID = ShellClient
	go s.subscribe(sub)
	t.Cleanup(sub.Stop)
	deadline := time.Now().Add(5 * time.Second)
	for {
		s.mu.Lock()
		n := len(s.subs)
		s.mu.Unlock()
		if n > 0 {
			break
		}
		if time.Now().After(deadline) {
			t.Fatal("not subscribed")
		}
		time.Sleep(time.Millisecond)
	}
	done := make(chan bool, 1)
	go func() { _, w := s.CommitAndWait("settings"); done <- w }()
	var d Done
	select {
	case e := <-sub.Events:
		b, _ := json.Marshal(e.Data)
		_ = json.Unmarshal(b, &d)
	case <-time.After(2 * time.Second):
		t.Fatal("no commit event")
	}
	shell := dial(t, sock)
	fmt.Fprintf(shell, `{"id":1,"method":"slow.op"}`+"\n"+`{"id":2,"method":"preview.written","params":{"id":%d}}`+"\n", d.ID)
	if !<-done {
		t.Fatal("the main shell's answer waited behind its slow call: not written")
	}
}

func dial(t *testing.T, sock string) net.Conn {
	t.Helper()
	c, err := net.Dial("unix", sock)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { c.Close() })
	_ = c.SetDeadline(time.Now().Add(60 * time.Second))
	return c
}

func read(t *testing.T, r *bufio.Reader) ipc.Response {
	t.Helper()
	line, err := r.ReadBytes('\n')
	if err != nil {
		t.Fatalf("read: %v", err)
	}
	var resp ipc.Response
	if err := json.Unmarshal(line, &resp); err != nil {
		t.Fatalf("decode %q: %v", line, err)
	}
	return resp
}

// fakeShell is the main shell's PreviewSink: it subscribes to "preview"
// as the main shell, applies every preview.set to its own copy and, on
// preview.commit, "writes" (sends the value it holds of bar.position on
// the returned channel) and answers preview.written on its request socket.
func fakeShell(t *testing.T, sock string) <-chan string {
	t.Helper()
	stream := dial(t, sock)
	req := dial(t, sock)
	if _, err := stream.Write([]byte(`{"id":1,"method":"subscribe","params":{"clientId":"shell","services":["preview"]}}` + "\n")); err != nil {
		t.Fatal(err)
	}
	out := make(chan string, 1)
	go func() {
		r := bufio.NewReader(stream)
		rr := bufio.NewReader(req)
		held := map[string]string{}
		next := 100
		for {
			line, err := r.ReadBytes('\n')
			if err != nil {
				return
			}
			var resp struct {
				Result struct {
					Service string          `json:"service"`
					Data    json.RawMessage `json:"data"`
				} `json:"result"`
			}
			if json.Unmarshal(line, &resp) != nil {
				continue
			}
			switch resp.Result.Service {
			case "preview.set":
				var e Entry
				_ = json.Unmarshal(resp.Result.Data, &e)
				held[e.Key] = string(e.Value)
			case "preview.commit":
				var d Done
				_ = json.Unmarshal(resp.Result.Data, &d)
				out <- held["bar.position"]
				delete(held, "bar.position")
				next++
				_, _ = fmt.Fprintf(req, `{"id":%d,"method":"preview.written","params":{"id":%d}}`+"\n", next, d.ID)
				if _, err := rr.ReadBytes('\n'); err != nil {
					return
				}
			}
		}
	}()
	return out
}
