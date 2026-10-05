package transfers

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"sync/atomic"
	"testing"
)

func fixture(t *testing.T, name string) []byte {
	t.Helper()
	data, err := os.ReadFile("testdata/" + name)
	if err != nil {
		t.Fatal(err)
	}
	return data
}

func byKeyMap(items []Transfer) map[string]Transfer {
	out := map[string]Transfer{}
	for _, it := range items {
		out[it.Key] = it
	}
	return out
}

func TestQBittorrentLocalhostBypass(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/api/v2/torrents/info" || r.URL.Query().Get("filter") != "all" {
			t.Errorf("unexpected request %s", r.URL)
		}
		w.Write(fixture(t, "torrents/qbittorrent_info.json"))
	}))
	defer srv.Close()
	q := newQBittorrent(Options{Endpoints: map[string]string{"qbittorrent": srv.URL + "/"}})
	items, err := q.poll(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	m := byKeyMap(items)
	if len(items) != 5 {
		t.Fatalf("want 5 incomplete torrents, got %d: %+v", len(items), items)
	}
	arch := m["qbittorrent:8f1e2c3a4b5d6e7f8091a2b3c4d5e6f708192a3b"]
	if arch.State != StateRunning || arch.Processed != 1073741824 || arch.Total != 3221225472 || arch.Rate != 5242880 ||
		arch.Path != "/home/user/Downloads/archlinux-2026.10.01-x86_64.iso" || arch.App != "qBittorrent" || arch.StartedAt != 1790960000000 {
		t.Fatalf("arch %+v", arch)
	}
	if m["qbittorrent:aa11"].State != StatePaused || m["qbittorrent:dd44"].State != StateQueued ||
		m["qbittorrent:ee55"].State != StateFailed || m["qbittorrent:cc33"].Detail != "Stalled" {
		t.Fatalf("states %+v", m)
	}
	if _, seeded := m["qbittorrent:bb22"]; seeded {
		t.Fatal("seeding torrents are not downloads")
	}
}

func TestQBittorrentLoginOnceThenGiveUp(t *testing.T) {
	var logins atomic.Int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/api/v2/auth/login":
			logins.Add(1)
			r.ParseForm()
			if r.Header.Get("Referer") == "" {
				t.Error("login needs a Referer (CSRF check)")
			}
			if r.Form.Get("username") == "admin" && r.Form.Get("password") == "s3cret" {
				http.SetCookie(w, &http.Cookie{Name: "SID", Value: "abc", Path: "/"})
				io.WriteString(w, "Ok.")
				return
			}
			io.WriteString(w, "Fails.")
		case "/api/v2/torrents/info":
			if c, err := r.Cookie("SID"); err != nil || c.Value != "abc" {
				w.WriteHeader(http.StatusForbidden)
				return
			}
			w.Write(fixture(t, "torrents/qbittorrent_info.json"))
		}
	}))
	defer srv.Close()

	good := newQBittorrent(Options{Endpoints: map[string]string{"qbittorrent": srv.URL}, Secrets: map[string]string{"qbittorrent": "admin:s3cret"}})
	if items, err := good.poll(context.Background()); err != nil || len(items) != 5 {
		t.Fatalf("login flow: %v %d", err, len(items))
	}
	if _, err := good.poll(context.Background()); err != nil {
		t.Fatal("session cookie must be reused")
	}
	if logins.Load() != 1 {
		t.Fatalf("logins %d", logins.Load())
	}

	bad := newQBittorrent(Options{Endpoints: map[string]string{"qbittorrent": srv.URL}, Secrets: map[string]string{"qbittorrent": "admin:wrong"}})
	if _, err := bad.poll(context.Background()); err != errTorrentGiveUp {
		t.Fatalf("wrong password must give up, got %v", err)
	}
	none := newQBittorrent(Options{Endpoints: map[string]string{"qbittorrent": srv.URL}})
	if _, err := none.poll(context.Background()); err != errTorrentGiveUp {
		t.Fatalf("no credentials must give up, got %v", err)
	}
	if logins.Load() != 2 {
		t.Fatalf("only one attempt per process expected, got %d", logins.Load())
	}
}

func TestTransmissionSessionHandshake(t *testing.T) {
	var calls atomic.Int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls.Add(1)
		if r.Header.Get("X-Transmission-Session-Id") != "sess-42" {
			w.Header().Set("X-Transmission-Session-Id", "sess-42")
			w.WriteHeader(http.StatusConflict)
			return
		}
		var req struct {
			Method    string `json:"method"`
			Arguments struct {
				Fields []string `json:"fields"`
			} `json:"arguments"`
		}
		json.NewDecoder(r.Body).Decode(&req)
		if req.Method != "torrent-get" || len(req.Arguments.Fields) == 0 {
			t.Errorf("bad request %+v", req)
		}
		w.Write(fixture(t, "torrents/transmission_get.json"))
	}))
	defer srv.Close()
	tr := newTransmission(Options{Endpoints: map[string]string{"transmission": srv.URL}})
	items, err := tr.poll(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	m := byKeyMap(items)
	if len(items) != 3 {
		t.Fatalf("want 3 incomplete, got %+v", items)
	}
	f := m["transmission:0123456789abcdef0123456789abcdef01234567"]
	if f.State != StateRunning || f.Processed != 2097152000-524288000 || f.Total != 2097152000 || f.Rate != 4194304 ||
		f.Path != "/var/lib/transmission/Downloads/Fedora-Workstation-Live-x86_64-43.iso" {
		t.Fatalf("fedora %+v", f)
	}
	if m["transmission:abab"].State != StatePaused || m["transmission:cdcd"].State != StateFailed ||
		!strings.Contains(m["transmission:cdcd"].Detail, "No data found") {
		t.Fatalf("states %+v", m)
	}
	tr.poll(context.Background())
	if calls.Load() != 3 {
		t.Fatalf("the session id must be reused after the handshake, %d calls", calls.Load())
	}
}

func TestTransmissionUnauthorizedGivesUp(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusUnauthorized)
	}))
	defer srv.Close()
	tr := newTransmission(Options{Endpoints: map[string]string{"transmission": srv.URL}})
	if _, err := tr.poll(context.Background()); err != errTorrentGiveUp {
		t.Fatalf("got %v", err)
	}
}

func TestDelugeWebJSONRPC(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var req struct {
			Method string `json:"method"`
			Params []any  `json:"params"`
			ID     int    `json:"id"`
		}
		json.NewDecoder(r.Body).Decode(&req)
		switch req.Method {
		case "auth.login":
			ok := len(req.Params) == 1 && req.Params[0] == "deluge"
			if ok {
				http.SetCookie(w, &http.Cookie{Name: "_session_id", Value: "s1", Path: "/"})
			}
			json.NewEncoder(w).Encode(map[string]any{"result": ok, "error": nil, "id": req.ID})
		case "web.update_ui":
			if c, err := r.Cookie("_session_id"); err != nil || c.Value != "s1" {
				json.NewEncoder(w).Encode(map[string]any{"result": nil, "error": map[string]any{"message": "Not authenticated", "code": 1}, "id": req.ID})
				return
			}
			w.Write(fixture(t, "torrents/deluge_update_ui.json"))
		}
	}))
	defer srv.Close()
	d := newDeluge(Options{Endpoints: map[string]string{"deluge": srv.URL}})
	items, err := d.poll(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 1 {
		t.Fatalf("want 1 downloading torrent, got %+v", items)
	}
	u := items[0]
	if u.Key != "deluge:5a6b7c8d" || u.Processed != 1610612736 || u.Total != 6442450944 || u.Rate != 3355443 ||
		u.State != StateRunning || u.App != "Deluge" || u.Path != "/home/user/Downloads/ubuntu-26.04-desktop-amd64.iso" {
		t.Fatalf("ubuntu %+v", u)
	}

	wrong := newDeluge(Options{Endpoints: map[string]string{"deluge": srv.URL}, Secrets: map[string]string{"deluge": "nope"}})
	if _, err := wrong.poll(context.Background()); err != errTorrentGiveUp {
		t.Fatalf("wrong password: %v", err)
	}
}

type fakeTorrentClient struct {
	names  []string
	items  []Transfer
	err    error
	polls  int
	resets int
}

func (f *fakeTorrentClient) procs() []string { return f.names }
func (f *fakeTorrentClient) reset()          { f.resets++ }
func (f *fakeTorrentClient) poll(context.Context) ([]Transfer, error) {
	f.polls++
	return f.items, f.err
}

func TestTorrentsPollOnlyRunningClients(t *testing.T) {
	a := &fakeTorrentClient{names: []string{"qbittorrent"}, items: []Transfer{{Key: "qbittorrent:x"}}}
	b := &fakeTorrentClient{names: []string{"transmission-da"}, err: errTorrentGiveUp}
	running := map[string][]int{"qbittorrent": {10}}
	s := &torrentsSource{
		clients: []*torrentState{{client: a}, {client: b}},
		listPID: func([]string) map[string][]int { return running },
	}
	s.discover()
	if got := s.pollAll(context.Background()); len(got) != 1 || b.polls != 0 {
		t.Fatalf("got %+v, transmission polled %d times", got, b.polls)
	}
	running = map[string][]int{"qbittorrent": {10}, "transmission-da": {20}}
	s.discover()
	s.pollAll(context.Background())
	s.pollAll(context.Background())
	if b.polls != 1 {
		t.Fatalf("a client that gave up is not polled again, got %d polls", b.polls)
	}
	running = map[string][]int{"qbittorrent": {10}, "transmission-da": {21}} // restarted
	s.discover()
	s.pollAll(context.Background())
	if b.polls != 2 || b.resets < 2 {
		t.Fatalf("a restart retries once: polls %d resets %d", b.polls, b.resets)
	}
	running = map[string][]int{}
	s.discover()
	if got := s.pollAll(context.Background()); len(got) != 0 {
		t.Fatalf("stopped clients report nothing: %+v", got)
	}
}
