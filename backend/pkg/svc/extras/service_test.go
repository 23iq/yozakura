package extras

import (
	"encoding/json"
	"errors"
	"io/fs"
	"os"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"yozakura/backend/pkg/ipc"
)

type countProbe struct {
	fakeProbe
	n atomic.Int32
}

func (c *countProbe) InstalledPkgs() map[string]bool { c.n.Add(1); return c.pkgs }

type svcEnv struct {
	s      *Service
	run    *fakeRunner
	probe  *countProbe
	now    time.Time
	events chan ipc.ServiceEvent
}

func newSvcEnv(t *testing.T, p Platform, steps map[string]fakeStep) *svcEnv {
	t.Helper()
	cat := loadReal(t)
	e := &svcEnv{run: &fakeRunner{steps: steps}, probe: &countProbe{fakeProbe: fakeProbe{pkgs: map[string]bool{}}},
		now: time.Unix(1000, 0), events: make(chan ipc.ServiceEvent, 256)}
	e.s = newService(Options{
		Catalog:  func() (*Catalog, error) { return cat, nil },
		Platform: func() Platform { return p },
		Probe:    e.probe, Runner: e.run, Notify: func(string, string) {},
		Self: func() string { return self }, User: func() string { return "alice" },
		ReadFile: func(path string) ([]byte, error) {
			if path == "/etc/shells" {
				return []byte("/bin/bash\n/usr/bin/fish\n"), nil
			}
			return os.ReadFile(path)
		},
		Now: func() time.Time { return e.now }, LogDir: t.TempDir(),
	})
	e.s.subscribe(&ipc.Subscriber{Events: e.events})
	return e
}

func call(t *testing.T, h ipc.HandlerFunc, params string) (map[string]any, error) {
	t.Helper()
	res, err := h(json.RawMessage(params))
	if err != nil {
		return nil, err
	}
	b, _ := json.Marshal(res)
	var m map[string]any
	_ = json.Unmarshal(b, &m)
	return m, nil
}

func jobIDs(t *testing.T, m map[string]any) []string {
	t.Helper()
	var ids []string
	for _, j := range m["jobs"].([]any) {
		ids = append(ids, j.(map[string]any)["id"].(string))
	}
	return ids
}

func TestServiceInstallRunsAndRefreshes(t *testing.T) {
	e := newSvcEnv(t, archNvidia, nil)
	m, err := call(t, e.s.install, `{"ids":["codex"]}`)
	if err != nil {
		t.Fatal(err)
	}
	if got := jobIDs(t, m); len(got) != 2 || !strings.HasPrefix(got[0], "system-") || !strings.HasPrefix(got[1], "npm-") {
		t.Fatalf("jobs = %v", got)
	}
	e.s.q.Wait()
	if !strings.Contains(strings.Join(e.run.calls, "\n"), "pkexec "+self+" sys install nodejs") {
		t.Errorf("calls = %v", e.run.calls)
	}
	var sawStatus bool
	for len(e.events) > 0 {
		if ev := <-e.events; ev.Service == "extras.status" {
			sawStatus = true
		}
	}
	if !sawStatus {
		t.Error("no extras.status event")
	}
}

func TestServiceInstallErrorCodes(t *testing.T) {
	p := archNvidia
	p.Multilib = false
	e := newSvcEnv(t, p, nil)
	_, err := call(t, e.s.install, `{"ids":["steam"]}`)
	code, data := ParseError(err.Error())
	if code != CodeNeedsConfirm || data["kind"] != "multilib" {
		t.Fatalf("err = %v (%s %v)", err, code, data)
	}
	if len(e.s.q.Jobs()) != 0 {
		t.Error("jobs queued despite needs_confirm")
	}
	if _, err := call(t, e.s.install, `{"ids":["steam"],"confirmMultilib":true}`); err != nil {
		t.Fatal(err)
	}
	e.s.q.Wait()

	// flatpak-only entry on a host without flatpak: per-entry reasons
	other := Platform{Distro: "other", GPU: "none", HasPkexec: true}
	e2 := newSvcEnv(t, other, nil)
	_, err = call(t, e2.s.install, `{"ids":["firefox"]}`)
	code, data = ParseError(err.Error())
	if code != CodeUnavailable {
		t.Fatalf("err = %v", err)
	}
	if _, ok := data["reasons"].(map[string]any)["firefox"]; !ok {
		t.Errorf("reasons = %v", data)
	}
	for _, bad := range []string{`{}`, `{"ids":[]}`, `not json`} {
		if _, err := call(t, e.s.install, bad); err == nil {
			t.Errorf("install %s accepted", bad)
		}
	}
}

func TestServiceStatusCache(t *testing.T) {
	e := newSvcEnv(t, archNvidia, nil)
	if _, err := call(t, e.s.statusM, `{}`); err != nil {
		t.Fatal(err)
	}
	call(t, e.s.statusM, `{}`)
	if n := e.probe.n.Load(); n != 1 {
		t.Fatalf("detections = %d, want 1 (cached)", n)
	}
	call(t, e.s.statusM, `{"refresh":true}`)
	if n := e.probe.n.Load(); n != 2 {
		t.Fatalf("refresh did not re-detect: %d", n)
	}
	e.now = e.now.Add(31 * time.Second)
	m, _ := call(t, e.s.statusM, `{}`)
	if n := e.probe.n.Load(); n != 3 {
		t.Fatalf("stale cache not refreshed: %d", n)
	}
	st := m["firefox"].(map[string]any)
	if st["state"] != "missing" || st["id"] != "firefox" {
		t.Errorf("firefox = %v (lowercase keys expected)", st)
	}
}

func TestServiceInstallingOverlayAndFailed(t *testing.T) {
	e := newSvcEnv(t, archNvidia, map[string]fakeStep{
		"pkexec " + self + " sys install firefox": {lines: []string{"error: target not found: firefox"}, code: 1},
	})
	call(t, e.s.statusM, `{}`)
	if _, err := call(t, e.s.install, `{"ids":["firefox"]}`); err != nil {
		t.Fatal(err)
	}
	e.s.q.Wait()
	m, _ := call(t, e.s.statusM, `{}`)
	st := m["firefox"].(map[string]any)
	if st["state"] != "failed" || st["reason"] != "needs_sync" {
		t.Errorf("firefox = %v", st)
	}
}

func TestServiceCancelCodes(t *testing.T) {
	key := "pkexec " + self + " sys install firefox"
	e := newSvcEnv(t, archNvidia, map[string]fakeStep{key: {block: true}})
	e.run.started = make(chan string, 4)
	m, _ := call(t, e.s.install, `{"ids":["firefox"]}`)
	<-e.run.started
	_, err := call(t, e.s.cancel, `{"job":"`+jobIDs(t, m)[0]+`"}`)
	if code, _ := ParseError(err.Error()); code != CodeNotCancellable {
		t.Fatalf("err = %v", err)
	}
	if _, err := call(t, e.s.cancel, `{"job":"nope-1"}`); err == nil || !strings.HasPrefix(err.Error(), CodeUnknownJob+":") {
		t.Fatalf("err = %v", err)
	}
	if _, err := call(t, e.s.cancel, `{}`); err == nil {
		t.Error("cancel without job accepted")
	}
	// queued jobs can be cancelled
	m2, _ := call(t, e.s.install, `{"ids":["telegram"]}`)
	if _, err := call(t, e.s.cancel, `{"job":"`+jobIDs(t, m2)[0]+`"}`); err != nil {
		t.Fatal(err)
	}
}

func TestServiceUpgradeAndRetry(t *testing.T) {
	first := "pkexec " + self + " sys install firefox"
	e := newSvcEnv(t, archNvidia, map[string]fakeStep{first: {lines: []string{"error: target not found: firefox"}, code: 1}})
	m, _ := call(t, e.s.install, `{"ids":["firefox"]}`)
	e.s.q.Wait()
	old := jobIDs(t, m)[0]
	e.run.steps = map[string]fakeStep{} // everything succeeds now
	m2, err := call(t, e.s.upgradeAndRetry, `{"job":"`+old+`"}`)
	if err != nil {
		t.Fatal(err)
	}
	ids := jobIDs(t, m2)
	if len(ids) != 2 || !strings.HasPrefix(ids[0], "upgrade-") || ids[1] == old {
		t.Fatalf("ids = %v", ids)
	}
	e.s.q.Wait()
	want := []string{first, "pkexec " + self + " sys upgrade", first}
	if strings.Join(e.run.calls, "|") != strings.Join(want, "|") {
		t.Errorf("calls = %v", e.run.calls)
	}
	if _, err := call(t, e.s.upgradeAndRetry, `{"job":"system-1"}`); err == nil {
		t.Error("unknown job accepted")
	}
}

func TestServiceLog(t *testing.T) {
	e := newSvcEnv(t, archNvidia, map[string]fakeStep{"pkexec " + self + " sys install firefox": {lines: []string{"hello log"}}})
	m, _ := call(t, e.s.install, `{"ids":["firefox"]}`)
	e.s.q.Wait()
	l, err := call(t, e.s.log, `{"job":"`+jobIDs(t, m)[0]+`"}`)
	if err != nil || !strings.Contains(l["text"].(string), "hello log") {
		t.Fatalf("log = %v, %v", l, err)
	}
	for _, bad := range []string{`{"job":"../../etc/passwd"}`, `{"job":"a/b"}`, `{"job":"system-1/../x"}`} {
		if _, err := call(t, e.s.log, bad); err == nil {
			t.Errorf("log %s accepted", bad)
		}
	}
}

func TestServiceOllamaPull(t *testing.T) {
	e := newSvcEnv(t, archNvidia, map[string]fakeStep{"ollama pull qwen3:8b": {lines: []string{"pulling manifest"}}})
	m, err := call(t, e.s.ollamaPull, `{"model":"qwen3:8b"}`)
	if err != nil {
		t.Fatal(err)
	}
	e.s.q.Wait()
	if !strings.HasPrefix(jobIDs(t, m)[0], "ollama-") || e.run.calls[0] != "ollama pull qwen3:8b" {
		t.Errorf("ids=%v calls=%v", jobIDs(t, m), e.run.calls)
	}
	for _, bad := range []string{`{"model":"Qwen"}`, `{"model":"a b"}`, `{"model":"-h"}`, `{"model":"x;rm"}`, `{"model":""}`, `{}`} {
		if _, err := call(t, e.s.ollamaPull, bad); err == nil {
			t.Errorf("model %s accepted", bad)
		}
	}
}

func TestServiceSetLoginShell(t *testing.T) {
	e := newSvcEnv(t, archNvidia, nil)
	m, err := call(t, e.s.setLoginShell, `{"shell":"/usr/bin/fish"}`)
	if err != nil {
		t.Fatal(err)
	}
	e.s.q.Wait()
	if want := "pkexec " + self + " sys chsh alice /usr/bin/fish"; e.run.calls[0] != want {
		t.Errorf("call = %q", e.run.calls[0])
	}
	if !strings.HasPrefix(jobIDs(t, m)[0], "loginshell-") {
		t.Errorf("ids = %v", jobIDs(t, m))
	}
	for _, bad := range []string{`{"shell":"/usr/bin/zsh"}`, `{"shell":"fish"}`, `{"shell":"/tmp/evil"}`, `{}`} {
		if _, err := call(t, e.s.setLoginShell, bad); err == nil {
			t.Errorf("shell %s accepted", bad)
		}
	}
	if len(e.run.calls) != 1 {
		t.Errorf("extra calls: %v", e.run.calls)
	}
}

func TestServiceCatalog(t *testing.T) {
	e := newSvcEnv(t, archNvidia, nil)
	m, err := call(t, e.s.catalogM, `{}`)
	if err != nil {
		t.Fatal(err)
	}
	if len(m["entries"].([]any)) == 0 || len(m["categories"].([]any)) == 0 {
		t.Error("empty catalog")
	}
	if pl := m["platform"].(map[string]any); pl["distro"] != "arch" || pl["gpu"] != "nvidia" {
		t.Errorf("platform = %v", pl)
	}
}

func TestParseError(t *testing.T) {
	err := &codedError{CodeUnavailable, map[string]any{"reasons": map[string]string{"x": "needs_flatpak"}}}
	code, data := ParseError(err.Error())
	if code != CodeUnavailable || data["reasons"].(map[string]any)["x"] != "needs_flatpak" {
		t.Errorf("%q -> %s %v", err, code, data)
	}
	if c, _ := ParseError("boom"); c != "" {
		t.Error("plain error parsed as coded")
	}
	if !errors.Is(ErrNotCancellable, ErrNotCancellable) {
		t.Fatal()
	}
}

type fakeInfo struct {
	mode fs.FileMode
	sys  any
}

func (f fakeInfo) Name() string       { return "h" }
func (f fakeInfo) Size() int64        { return 1 }
func (f fakeInfo) Mode() fs.FileMode  { return f.mode }
func (f fakeInfo) ModTime() time.Time { return time.Time{} }
func (f fakeInfo) IsDir() bool        { return f.mode.IsDir() }
func (f fakeInfo) Sys() any           { return f.sys }

func TestServiceInstallSkipsActiveAndRedetects(t *testing.T) {
	key := "pkexec " + self + " sys install firefox"
	e := newSvcEnv(t, archNvidia, map[string]fakeStep{key: {block: true}})
	e.run.started = make(chan string, 4)
	call(t, e.s.install, `{"ids":["firefox"]}`)
	<-e.run.started
	n := e.probe.n.Load()
	m, err := call(t, e.s.install, `{"ids":["firefox"]}`)
	if err != nil {
		t.Fatal(err)
	}
	if len(m["jobs"].([]any)) != 0 {
		t.Errorf("active entry queued twice: %v", m)
	}
	if e.probe.n.Load() == n {
		t.Error("install did not re-detect")
	}
}
