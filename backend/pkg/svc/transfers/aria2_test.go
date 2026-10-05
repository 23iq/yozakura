package transfers

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"sync"
	"testing"
	"time"
)

type aria2Fake struct {
	mu      sync.Mutex
	stopped string
	calls   []string
	tokens  []any
}

func (f *aria2Fake) handler(t *testing.T) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req struct {
			ID     string `json:"id"`
			Method string `json:"method"`
			Params []any  `json:"params"`
		}
		json.NewDecoder(r.Body).Decode(&req)
		f.mu.Lock()
		defer f.mu.Unlock()
		f.calls = append(f.calls, req.Method)
		if len(req.Params) > 0 {
			f.tokens = append(f.tokens, req.Params[0])
		}
		switch req.Method {
		case "aria2.tellActive":
			w.Write(fixture(t, "aria2/tellActive.json"))
		case "aria2.tellWaiting":
			w.Write(fixture(t, "aria2/tellWaiting.json"))
		case "aria2.tellStopped":
			if f.stopped != "" {
				w.Write([]byte(f.stopped))
			} else {
				w.Write(fixture(t, "aria2/tellStopped.json"))
			}
		default:
			json.NewEncoder(w).Encode(map[string]any{"id": req.ID, "jsonrpc": "2.0", "result": "OK"})
		}
	}
}

func TestAria2Discovery(t *testing.T) {
	conf := t.TempDir()
	os.WriteFile(filepath.Join(conf, "aria2.conf"), []byte("# rpc\nenable-rpc=true\nrpc-listen-port=6801\nrpc-secret=fromconf\n"), 0o644)
	s := newAria2Source()
	s.confDirs = []string{conf}
	s.listProc = func() []Proc {
		return []Proc{
			{PID: 1, Comm: "aria2c", Args: []string{"aria2c", "https://x/y.iso"}},                                             // no RPC on the CLI, but the conf enables it
			{PID: 2, Comm: "aria2c", Args: []string{"aria2c", "--enable-rpc", "--rpc-listen-port", "7000", "--rpc-secret=s"}}, // CLI
			{PID: 3, Comm: "aria2c", Args: []string{"aria2c", "--no-conf", "file"}},                                           // plain
		}
	}
	s.discover()
	if len(s.rpcs) != 2 {
		t.Fatalf("rpcs %+v", s.rpcs)
	}
	if s.rpcs[0] != (aria2RPC{URL: "http://127.0.0.1:6801/jsonrpc", Secret: "fromconf"}) ||
		s.rpcs[1] != (aria2RPC{URL: "http://127.0.0.1:7000/jsonrpc", Secret: "s"}) {
		t.Fatalf("rpcs %+v", s.rpcs)
	}
}

func TestAria2PollAndActions(t *testing.T) {
	fake := &aria2Fake{}
	srv := httptest.NewServer(fake.handler(t))
	defer srv.Close()
	s := newAria2Source()
	now := time.Unix(1000, 0)
	s.now = func() time.Time { return now }
	s.rpcs = []aria2RPC{{URL: srv.URL, Secret: "tok"}}

	items := s.poll(context.Background())
	m := byKeyMap(items)
	if len(items) != 5 {
		t.Fatalf("want 3 active + 2 waiting (old stopped job hidden), got %+v", items)
	}
	k := m["2089b05ecca3d829"]
	if k.State != StateRunning || k.Processed != 104857600 || k.Total != 1073741824 || k.Rate != 2097152 ||
		k.Title != "linux-6.18.tar.xz" || k.Dir != "/home/user/Downloads" || len(k.Actions) != 2 {
		t.Fatalf("kernel %+v", k)
	}
	if u := m["aaaa0000bbbb1111"]; u.Title != "big.iso" || u.Total != -1 {
		t.Fatalf("metadata-less job %+v", u)
	}
	if d := m["cccc2222dddd3333"]; d.Title != "debian-13.1.0-amd64-DVD-1.iso" || d.Path != "/srv/torrents/debian-13.1.0-amd64-DVD-1.iso" {
		t.Fatalf("torrent job %+v", d)
	}
	if m["eeee4444ffff5555"].State != StatePaused || m["eeee4444ffff5555"].Actions[0] != ActionResume || m["1111aaaa2222bbbb"].State != StateQueued {
		t.Fatalf("waiting %+v", m)
	}
	for _, tok := range fake.tokens {
		if tok != "token:tok" {
			t.Fatalf("secret must be sent as the first param, got %v", tok)
		}
	}

	// The kernel download finishes: shown as done for a while, then hidden
	fake.mu.Lock()
	fake.stopped = `{"id":"3","jsonrpc":"2.0","result":[{"completedLength":"1073741824","dir":"/home/user/Downloads","downloadSpeed":"0","files":[{"path":"/home/user/Downloads/linux-6.18.tar.xz","uris":[]}],"gid":"2089b05ecca3d829","status":"complete","totalLength":"1073741824"}]}`
	fake.mu.Unlock()
	items = s.poll(context.Background())
	var done int
	for _, it := range items {
		if it.Key == "2089b05ecca3d829" && it.State == StateDone {
			done++
		}
	}
	if done != 1 || len(items) != 5 {
		t.Fatalf("finished job not reported once as done: %+v", items)
	}
	now = now.Add(aria2DoneHold + time.Second)
	for _, it := range s.poll(context.Background()) {
		if it.Key == "2089b05ecca3d829" && it.State == StateDone {
			t.Fatal("done job must expire")
		}
	}

	if err := s.Action("eeee4444ffff5555", ActionResume); err != nil {
		t.Fatal(err)
	}
	if err := s.Action("1111aaaa2222bbbb", ActionCancel); err != nil {
		t.Fatal(err)
	}
	if err := s.Action("nope", ActionCancel); err == nil {
		t.Fatal("unknown gid must fail")
	}
	fake.mu.Lock()
	calls := fake.calls[len(fake.calls)-2:]
	fake.mu.Unlock()
	if calls[0] != "aria2.unpause" || calls[1] != "aria2.remove" {
		t.Fatalf("actions sent as %v", calls)
	}
}
