package transfers

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
	"time"
)

func TestSyncthingConfig(t *testing.T) {
	c, err := parseSyncthingConfig(fixture(t, "syncthing/config.xml"))
	if err != nil {
		t.Fatal(err)
	}
	if c.GUI.APIKey != "p4Ss9kLmN3xYzA1bC2dE3fG4hI5jK6lM" || len(c.Folders) != 3 || !c.Folders[2].Paused || c.Folders[0].Label != "Photos" {
		t.Fatalf("config %+v", c)
	}
	if b := syncthingBase(c); b != "http://127.0.0.1:8384" {
		t.Fatalf("base %q", b)
	}
	c.GUI.TLS, c.GUI.Address = true, "[::1]:8385"
	if b := syncthingBase(c); b != "https://[::1]:8385" || !isLoopback(b) {
		t.Fatalf("tls base %q", b)
	}
	c.GUI.Address = "/run/user/1000/syncthing.sock"
	if syncthingBase(c) != "" {
		t.Fatal("unix socket GUI is not supported")
	}
	if isLoopback("https://nas.local:8384") {
		t.Fatal("remote hosts keep TLS verification")
	}
}

func TestSyncthingPoll(t *testing.T) {
	var inBytes int64 = 1000
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("X-API-Key") != "p4Ss9kLmN3xYzA1bC2dE3fG4hI5jK6lM" {
			w.WriteHeader(http.StatusForbidden)
			return
		}
		switch r.URL.Path {
		case "/rest/db/status":
			switch r.URL.Query().Get("folder") {
			case "abcde-12345":
				json.NewEncoder(w).Encode(map[string]any{"state": "syncing", "globalBytes": 2000000000, "needBytes": 500000000, "needFiles": 120, "inSyncBytes": 1500000000})
			case "docs-1":
				json.NewEncoder(w).Encode(map[string]any{"state": "idle", "globalBytes": 100, "needBytes": 50, "needFiles": 1})
			default:
				t.Errorf("paused folder polled: %s", r.URL)
			}
		case "/rest/system/connections":
			json.NewEncoder(w).Encode(map[string]any{"total": map[string]any{"inBytesTotal": inBytes}})
		}
	}))
	defer srv.Close()

	dir := t.TempDir()
	os.WriteFile(dir+"/config.xml", fixture(t, "syncthing/config.xml"), 0o644)
	s := newSyncthingSource()
	s.configPaths = func() []string { return []string{dir + "/missing.xml", dir + "/config.xml"} }
	s.opts = Options{Endpoints: map[string]string{"syncthing": srv.URL}}
	now := time.Unix(100, 0)
	s.now = func() time.Time { return now }
	s.load()

	items := s.poll(context.Background())
	if len(items) != 1 {
		t.Fatalf("only the syncing folder: %+v", items)
	}
	p := items[0]
	if p.Title != "Photos" || p.Kind != KindSync || p.Processed != 1500000000 || p.Total != 2000000000 ||
		p.Path != "/home/user/Photos" || p.Detail != "120 files" || p.App != "Syncthing" {
		t.Fatalf("photos %+v", p)
	}
	inBytes += 3 * 1024 * 1024
	now = now.Add(3 * time.Second)
	items = s.poll(context.Background())
	if items[0].Rate != 1024*1024 {
		t.Fatalf("rate %v", items[0].Rate)
	}
}

func TestSyncthingNotInstalled(t *testing.T) {
	s := newSyncthingSource()
	s.configPaths = func() []string { return []string{t.TempDir() + "/none.xml"} }
	s.load()
	if s.cfg != nil || s.base != "" {
		t.Fatal("no config, nothing to poll")
	}
}
