package extras

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"strings"
	"testing"
	"time"
)

func TestScriptFetcher(t *testing.T) {
	var plainURL string
	mux := http.NewServeMux()
	mux.HandleFunc("/ok", func(w http.ResponseWriter, _ *http.Request) { _, _ = w.Write([]byte("#!/bin/sh\necho hi\n")) })
	mux.HandleFunc("/hop", func(w http.ResponseWriter, r *http.Request) { http.Redirect(w, r, "/ok", http.StatusFound) })
	mux.HandleFunc("/evil", func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, "https://evil.example/x.sh", http.StatusFound)
	})
	mux.HandleFunc("/downgrade", func(w http.ResponseWriter, r *http.Request) { http.Redirect(w, r, plainURL, http.StatusFound) })
	mux.HandleFunc("/loop", func(w http.ResponseWriter, r *http.Request) { http.Redirect(w, r, "/loop", http.StatusFound) })
	mux.HandleFunc("/html", func(w http.ResponseWriter, _ *http.Request) { _, _ = w.Write([]byte("<html>")) })
	ts := httptest.NewTLSServer(mux)
	defer ts.Close()
	plain := httptest.NewServer(mux)
	defer plain.Close()
	plainURL = plain.URL + "/ok"

	host := strings.Split(strings.TrimPrefix(ts.URL, "https://"), ":")[0]
	f := scriptFetcher{initial: map[string]bool{host: true}, hops: map[string]bool{}, transport: ts.Client().Transport}
	ctx := context.Background()

	for _, path := range []string{"/ok", "/hop"} {
		got, err := f.fetch(ctx, ts.URL+path)
		if err != nil {
			t.Fatalf("%s: %v", path, err)
		}
		data, _ := os.ReadFile(got)
		os.Remove(got)
		if !strings.HasPrefix(string(data), "#!/bin/sh") {
			t.Errorf("%s: body %q", path, data)
		}
	}
	for _, path := range []string{"/evil", "/downgrade", "/loop", "/html"} {
		if _, err := f.fetch(ctx, ts.URL+path); !errors.Is(err, ErrScriptRejected) {
			t.Errorf("%s: err = %v, want rejected", path, err)
		}
	}
	if _, err := f.fetch(ctx, plainURL); !errors.Is(err, ErrScriptRejected) {
		t.Errorf("plain http: %v", err)
	}
	if _, err := DownloadScript(ctx, "https://evil.example/install.sh"); !errors.Is(err, ErrScriptRejected) {
		t.Errorf("DownloadScript evil: %v", err)
	}
}

func TestScriptRedirectHostsAllowed(t *testing.T) {
	f := scriptFetcher{initial: scriptHosts, hops: scriptRedirectHosts}
	for raw, ok := range map[string]bool{
		"https://downloads.claude.ai/claude-code-releases/bootstrap.sh": true,
		"https://raw.githubusercontent.com/x/y/install":                 true,
		"https://claude.ai/install.sh":                                  true,
		"http://downloads.claude.ai/b.sh":                               false,
		"https://u:p@raw.githubusercontent.com/x":                       false,
		"https://gist.githubusercontent.com/x":                          false,
	} {
		u, _ := url.Parse(raw)
		if err := f.check(u, f.hops); (err == nil) != ok {
			t.Errorf("%s: err = %v", raw, err)
		}
	}
	u, _ := url.Parse("https://downloads.claude.ai/b.sh")
	if f.check(u, nil) == nil {
		t.Error("redirect host accepted as initial url")
	}
}

// A job writes to a file, never a pipe: a daemon that goes away mid-job
// cannot SIGPIPE pacman. Its lines still arrive, including the last ones.
func TestExecRunnerOutputIsAFile(t *testing.T) {
	var lines []string
	code, err := ExecRunner{}.Run(context.Background(), []string{"sh", "-c", `[ -f /proc/self/fd/1 ] && echo file; sleep 0.1; printf 'a\rb\nlast'`}, nil, func(l string) { lines = append(lines, l) })
	if err != nil || code != 0 {
		t.Fatalf("%d %v", code, err)
	}
	if strings.Join(lines, "|") != "file|a|b|last" {
		t.Fatalf("lines = %q", lines)
	}
}

// A cancelled job whose process ignores SIGTERM is killed after the grace
// period instead of holding the queue forever.
func TestExecRunnerKillsTermIgnoringChild(t *testing.T) {
	old := cancelGrace
	cancelGrace = 200 * time.Millisecond
	defer func() { cancelGrace = old }()
	ctx, cancel := context.WithCancel(context.Background())
	started := make(chan struct{}, 1)
	go func() {
		<-started
		cancel()
	}()
	done := make(chan struct{})
	var code int
	go func() {
		defer close(done)
		code, _ = ExecRunner{}.Run(ctx, []string{"sh", "-c", `trap '' TERM; echo up; while :; do sleep 0.05; done`}, nil, func(string) {
			select {
			case started <- struct{}{}:
			default:
			}
		})
	}()
	select {
	case <-done:
	case <-time.After(5 * time.Second):
		t.Fatal("Run did not return after cancel: no SIGKILL escalation")
	}
	if code == 0 {
		t.Fatalf("exit code = 0, want a signal exit")
	}
}
