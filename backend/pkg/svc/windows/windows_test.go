package windows

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"syscall"
	"testing"
	"time"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/envclean"
	"yozakura/backend/pkg/ipc"

	"github.com/stretchr/testify/assert"
)

// fakeProc is a window process the test ends: exit() or a signal it obeys.
type fakeProc struct {
	pid      int
	exitCh   chan error
	once     sync.Once
	mu       sync.Mutex
	signals  []syscall.Signal
	ignoreTM bool // ignores SIGTERM (only SIGKILL ends it)
	unkill   bool // ignores every signal (stuck in the kernel)
}

func (p *fakeProc) Pid() int    { return p.pid }
func (p *fakeProc) Wait() error { return <-p.exitCh }
func (p *fakeProc) exit(err error) {
	p.once.Do(func() { p.exitCh <- err })
}
func (p *fakeProc) Signal(sig syscall.Signal) error {
	p.mu.Lock()
	p.signals = append(p.signals, sig)
	p.mu.Unlock()
	if p.unkill {
		return nil
	}
	if sig == syscall.SIGKILL || !p.ignoreTM {
		p.exit(errors.New("signal: " + sig.String()))
	}
	return nil
}
func (p *fakeProc) sigs() []syscall.Signal {
	p.mu.Lock()
	defer p.mu.Unlock()
	return append([]syscall.Signal(nil), p.signals...)
}

type starter struct {
	mu     sync.Mutex
	argv   [][]string
	env    [][]string
	procs  []*fakeProc
	fail   error
	ignore bool
}

func (s *starter) start(argv, env []string) (Process, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.fail != nil {
		return nil, s.fail
	}
	p := &fakeProc{pid: 1000 + len(s.procs), exitCh: make(chan error, 1), ignoreTM: s.ignore}
	s.argv = append(s.argv, argv)
	s.env = append(s.env, env)
	s.procs = append(s.procs, p)
	return p, nil
}

func (s *starter) count() int {
	s.mu.Lock()
	defer s.mu.Unlock()
	return len(s.procs)
}

func shellTree(t *testing.T, files ...string) string {
	t.Helper()
	dir := t.TempDir()
	for _, f := range files {
		must(t, assert.NoError(t, os.WriteFile(filepath.Join(dir, f), []byte("ShellRoot {}\n"), 0o644)))
	}
	return dir
}

type rig struct {
	svc    *Service
	st     *starter
	sub    *ipc.Subscriber
	exited chan string
}

func newRig(t *testing.T, shellDir, baseDir string) *rig {
	t.Helper()
	r := &rig{st: &starter{}, exited: make(chan string, 8)}
	r.svc = NewService(Options{
		QS:       func() string { return "/nix/store/abc-yozakura-qs" },
		ShellDir: func() string { return shellDir },
		BaseDir:  func() string { return baseDir },
		Env: func() []string {
			return []string{"PATH=/bin", brand.EnvPrefix + "ROLE=bogus", brand.EnvPrefix + "DRYRUN=1"}
		},
		Start:  r.st.start,
		OnExit: func(kind string) { r.exited <- kind },
	})
	r.sub = ipc.NewSubscriber(64)
	go r.svc.subscribe(r.sub)
	t.Cleanup(r.sub.Stop)
	// the initial state of every kind
	got := r.events(t, 2)
	assert.Equal(t, "windows.state", got[0].Service)
	return r
}

func (r *rig) events(t *testing.T, n int) []ipc.ServiceEvent {
	t.Helper()
	var out []ipc.ServiceEvent
	for len(out) < n {
		select {
		case e := <-r.sub.Events:
			out = append(out, e)
		case <-time.After(2 * time.Second):
			t.Fatalf("got %d events, want %d: %+v", len(out), n, out)
		}
	}
	return out
}

func (r *rig) quiet(t *testing.T) {
	t.Helper()
	select {
	case e := <-r.sub.Events:
		t.Fatalf("unexpected event %+v", e)
	case <-time.After(50 * time.Millisecond):
	}
}

func envOf(env []string) map[string]string {
	m := map[string]string{}
	for _, kv := range env {
		k, v, _ := strings.Cut(kv, "=")
		m[k] = v
	}
	return m
}

func TestOpenStartsOnceThenRaises(t *testing.T) {
	dir := shellTree(t, "shell.qml", "settings-window.qml", "onboarding-window.qml")
	r := newRig(t, dir, "")

	res, err := r.svc.Open(Request{Kind: KindSettings, Page: "network", Screen: "DP-1", Workspace: 3})
	must(t, assert.NoError(t, err))
	assert.Equal(t, "started", res)
	ev := r.events(t, 1)[0]
	assert.Equal(t, "windows.state", ev.Service)
	assert.Equal(t, Status{Kind: KindSettings, State: StateStarting, Pid: 1000}, ev.Data)

	must(t, assert.Equal(t, 1, r.st.count()))
	assert.Equal(t, []string{"/nix/store/abc-yozakura-qs", "-p", filepath.Join(dir, "settings-window.qml")}, r.st.argv[0])
	env := envOf(r.st.env[0])
	assert.Equal(t, "settings", env[brand.EnvPrefix+"ROLE"])
	assert.Equal(t, "network", env[brand.EnvPrefix+"WINDOW_PAGE"])
	assert.Equal(t, "DP-1", env[brand.EnvPrefix+"WINDOW_SCREEN"])
	assert.Equal(t, "3", env[brand.EnvPrefix+"WINDOW_WORKSPACE"])
	_, dry := env[brand.EnvPrefix+"DRYRUN"]
	assert.False(t, dry, "a window never inherits the dry-run switch")
	assert.Equal(t, "/bin", env["PATH"])

	// a second open raises the running window instead of starting another
	ok, _ := r.svc.Ready(KindSettings)
	must(t, assert.True(t, ok))
	r.events(t, 1)
	res, err = r.svc.Open(Request{Kind: KindSettings, Page: "sound"})
	must(t, assert.NoError(t, err))
	assert.Equal(t, "raised", res)
	ev = r.events(t, 1)[0]
	assert.Equal(t, "windows.command", ev.Service)
	assert.Equal(t, Command{Kind: KindSettings, Action: "raise", Page: "sound"}, ev.Data)
	assert.Equal(t, 1, r.st.count())

	// another kind is its own instance
	res, err = r.svc.Open(Request{Kind: KindOnboarding})
	must(t, assert.NoError(t, err))
	assert.Equal(t, "started", res)
	assert.Equal(t, 2, r.st.count())
	r.events(t, 1)
}

func TestReadyAndStatus(t *testing.T) {
	r := newRig(t, shellTree(t, "settings-window.qml"), "")
	ok, _ := r.svc.Ready(KindSettings)
	assert.False(t, ok, "nothing runs")
	_, err := r.svc.Open(Request{Kind: KindSettings})
	must(t, assert.NoError(t, err))
	r.events(t, 1)
	ok, cmd := r.svc.Ready(KindSettings)
	assert.True(t, ok)
	assert.Nil(t, cmd, "nothing was asked while it started")
	assert.Equal(t, Status{Kind: KindSettings, State: StateOpen, Pid: 1000}, r.events(t, 1)[0].Data)
	assert.Equal(t, []Status{{Kind: KindSettings, State: StateOpen, Pid: 1000}, {Kind: KindOnboarding, State: StateClosed}}, r.svc.Statuses())
}

func TestExitIsReapedAndReported(t *testing.T) {
	r := newRig(t, shellTree(t, "settings-window.qml"), "")
	_, err := r.svc.Open(Request{Kind: KindSettings})
	must(t, assert.NoError(t, err))
	r.events(t, 1)

	// the window closed itself (or crashed): reaped, reported, owner gone
	r.st.procs[0].exit(errors.New("exit status 139"))
	ev := r.events(t, 1)[0]
	assert.Equal(t, Status{Kind: KindSettings, State: StateClosed, Error: "exit status 139"}, ev.Data)
	select {
	case k := <-r.exited:
		assert.Equal(t, KindSettings, k)
	case <-time.After(time.Second):
		t.Fatal("OnExit not called")
	}
	assert.Equal(t, StateClosed, r.svc.Statuses()[0].State)
	assert.False(t, r.svc.AnyRunning())

	// the next open starts a fresh process (never restarted on its own)
	res, err := r.svc.Open(Request{Kind: KindSettings})
	must(t, assert.NoError(t, err))
	assert.Equal(t, "started", res)
	assert.Equal(t, 2, r.st.count())
}

func TestRequestCloseAsksTheWindow(t *testing.T) {
	r := newRig(t, shellTree(t, "settings-window.qml"), "")
	res, err := r.svc.RequestClose(KindSettings)
	must(t, assert.NoError(t, err))
	assert.Equal(t, StateClosed, res)
	r.quiet(t)

	_, err = r.svc.Open(Request{Kind: KindSettings})
	must(t, assert.NoError(t, err))
	r.events(t, 1)
	r.svc.Ready(KindSettings)
	r.events(t, 1)
	res, err = r.svc.RequestClose(KindSettings)
	must(t, assert.NoError(t, err))
	assert.Equal(t, "closing", res)
	assert.Equal(t, Command{Kind: KindSettings, Action: "close"}, r.events(t, 1)[0].Data)
	// asking is not killing: the window decides (unsaved changes)
	assert.Empty(t, r.st.procs[0].sigs())
}

func TestCloseStopsEveryWindowAndRefusesNewOnes(t *testing.T) {
	old := StopWait
	StopWait = 100 * time.Millisecond
	t.Cleanup(func() { StopWait = old })

	r := newRig(t, shellTree(t, "settings-window.qml", "onboarding-window.qml"), "")
	_, err := r.svc.Open(Request{Kind: KindSettings})
	must(t, assert.NoError(t, err))
	r.st.ignore = true // the wizard ignores SIGTERM
	_, err = r.svc.Open(Request{Kind: KindOnboarding})
	must(t, assert.NoError(t, err))

	done := make(chan struct{})
	go func() { r.svc.Close(); close(done) }()
	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("Close did not return")
	}
	assert.Equal(t, []syscall.Signal{syscall.SIGTERM}, r.st.procs[0].sigs())
	assert.Equal(t, []syscall.Signal{syscall.SIGTERM, syscall.SIGKILL}, r.st.procs[1].sigs())
	must(t, assert.Eventually(t, func() bool {
		return r.svc.Statuses()[0].State == StateClosed && r.svc.Statuses()[1].State == StateClosed
	},
		time.Second, 5*time.Millisecond))

	_, err = r.svc.Open(Request{Kind: KindSettings})
	assert.Error(t, err, "no window starts during shutdown")
	assert.Equal(t, 2, r.st.count())
}

// A window that is still starting does not listen to windows.command yet:
// the last command asked meanwhile waits for its windows.ready (a toggle
// closing it during the start is not lost, a later open undoes it).
func TestCommandDuringStartIsHandedOverAtReady(t *testing.T) {
	r := newRig(t, shellTree(t, "settings-window.qml"), "")
	_, err := r.svc.Open(Request{Kind: KindSettings})
	must(t, assert.NoError(t, err))
	r.events(t, 1)

	res, err := r.svc.RequestClose(KindSettings)
	must(t, assert.NoError(t, err))
	assert.Equal(t, "closing", res)
	r.quiet(t)
	ok, cmd := r.svc.Ready(KindSettings)
	must(t, assert.True(t, ok))
	assert.Equal(t, &Command{Kind: KindSettings, Action: "close"}, cmd)
	r.events(t, 1) // open
	_, cmd = r.svc.Ready(KindSettings)
	assert.Nil(t, cmd, "handed over once")
	r.events(t, 1)

	// close then open again while starting: the open wins
	r.st.procs[0].exit(nil)
	r.events(t, 1)
	<-r.exited
	_, err = r.svc.Open(Request{Kind: KindSettings})
	must(t, assert.NoError(t, err))
	r.events(t, 1)
	_, err = r.svc.RequestClose(KindSettings)
	must(t, assert.NoError(t, err))
	_, err = r.svc.Open(Request{Kind: KindSettings, Page: "sound"})
	must(t, assert.NoError(t, err))
	r.quiet(t)
	_, cmd = r.svc.Ready(KindSettings)
	assert.Equal(t, &Command{Kind: KindSettings, Action: "raise", Page: "sound"}, cmd)
}

// A closed window reports hiding until its process is gone; an open in
// that time raises it (the window shows itself again) and it reports ready.
func TestHidingWindowIsRaised(t *testing.T) {
	r := newRig(t, shellTree(t, "settings-window.qml"), "")
	assert.False(t, r.svc.Hiding(KindSettings), "nothing runs")
	_, err := r.svc.Open(Request{Kind: KindSettings})
	must(t, assert.NoError(t, err))
	r.events(t, 1)
	r.svc.Ready(KindSettings)
	r.events(t, 1)

	assert.True(t, r.svc.Hiding(KindSettings))
	assert.Equal(t, Status{Kind: KindSettings, State: StateHiding, Pid: 1000}, r.events(t, 1)[0].Data)
	assert.Equal(t, StateHiding, r.svc.Statuses()[0].State)
	res, err := r.svc.Open(Request{Kind: KindSettings, Page: "about"})
	must(t, assert.NoError(t, err))
	assert.Equal(t, "raised", res)
	assert.Equal(t, Command{Kind: KindSettings, Action: "raise", Page: "about"}, r.events(t, 1)[0].Data)
	assert.Equal(t, 1, r.st.count())
	ok, cmd := r.svc.Ready(KindSettings)
	assert.True(t, ok)
	assert.Nil(t, cmd)
	assert.Equal(t, StateOpen, r.events(t, 1)[0].Data.(Status).State)
}

// Every window ignoring SIGTERM gets SIGKILL after the one StopWait (the
// deadline is not used up by the first), and Close is bounded even when a
// process does not die at all.
func TestCloseKillsEveryHungWindowAndIsBounded(t *testing.T) {
	old := StopWait
	StopWait = 50 * time.Millisecond
	t.Cleanup(func() { StopWait = old })

	r := newRig(t, shellTree(t, "settings-window.qml", "onboarding-window.qml"), "")
	r.st.ignore = true
	_, err := r.svc.Open(Request{Kind: KindSettings})
	must(t, assert.NoError(t, err))
	_, err = r.svc.Open(Request{Kind: KindOnboarding})
	must(t, assert.NoError(t, err))

	start := time.Now()
	done := make(chan struct{})
	go func() { r.svc.Close(); close(done) }()
	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("Close did not return")
	}
	assert.Less(t, time.Since(start), time.Second)
	for i, p := range r.st.procs {
		assert.Equal(t, []syscall.Signal{syscall.SIGTERM, syscall.SIGKILL}, p.sigs(), "window %d", i)
	}

	// a process that survives SIGKILL does not hold the daemon's shutdown
	r2 := newRig(t, shellTree(t, "settings-window.qml", "onboarding-window.qml"), "")
	_, err = r2.svc.Open(Request{Kind: KindSettings})
	must(t, assert.NoError(t, err))
	r2.st.procs[0].unkill = true
	_, err = r2.svc.Open(Request{Kind: KindOnboarding})
	must(t, assert.NoError(t, err))
	r2.st.procs[1].unkill = true
	start = time.Now()
	done2 := make(chan struct{})
	go func() { r2.svc.Close(); close(done2) }()
	select {
	case <-done2:
	case <-time.After(2 * time.Second):
		t.Fatal("Close waited for an unkillable process")
	}
	assert.Less(t, time.Since(start), time.Second)
	for _, p := range r2.st.procs {
		assert.Equal(t, []syscall.Signal{syscall.SIGTERM, syscall.SIGKILL}, p.sigs())
		p.exit(nil)
	}
}

// The names a window gets are the ones every other child loses
// (envclean.WindowVars): the main shell and yozd never inherit a role.
func TestWindowEnvNamesAreStrippedElsewhere(t *testing.T) {
	var names []string
	for _, n := range []string{EnvRole, EnvPage, EnvScreen, EnvWorkspace} {
		names = append(names, brand.EnvPrefix+n)
	}
	assert.ElementsMatch(t, envclean.WindowVars, names)
}

func TestStartFailureIsReturned(t *testing.T) {
	r := newRig(t, shellTree(t, "settings-window.qml"), "")
	r.st.fail = errors.New("exec: qs: not found")
	_, err := r.svc.Open(Request{Kind: KindSettings})
	must(t, assert.Error(t, err))
	assert.Contains(t, err.Error(), "not found")
	r.quiet(t)
	assert.Equal(t, StateClosed, r.svc.Statuses()[0].State)
}

func TestUnknownKindRefused(t *testing.T) {
	r := newRig(t, shellTree(t, "settings-window.qml"), "")
	for _, k := range []string{"", "shell", "../x"} {
		_, err := r.svc.Open(Request{Kind: k})
		assert.Error(t, err, k)
		_, err = r.svc.RequestClose(k)
		assert.Error(t, err, k)
	}
	assert.Equal(t, 0, r.st.count())
}

func TestEntryPathResolution(t *testing.T) {
	// Nix-style: the shell is a read-only store path exported by the
	// launcher; the entry file is its sibling, never the binary's dir.
	store := shellTree(t, "shell.qml", "settings-window.qml")
	r := newRig(t, store, "")
	p, err := r.svc.EntryPath(KindSettings)
	must(t, assert.NoError(t, err))
	assert.Equal(t, filepath.Join(store, "settings-window.qml"), p)

	// a mods generation from before the entry files existed: the base
	// source has it
	gen := shellTree(t, "shell.qml")
	base := shellTree(t, "shell.qml", "settings-window.qml")
	r = newRig(t, gen, base)
	p, err = r.svc.EntryPath(KindSettings)
	must(t, assert.NoError(t, err))
	assert.Equal(t, filepath.Join(base, "settings-window.qml"), p)

	// nowhere: an error naming the dirs, nothing started
	r = newRig(t, gen, "")
	_, err = r.svc.Open(Request{Kind: KindSettings})
	must(t, assert.Error(t, err))
	assert.Contains(t, err.Error(), gen)
	assert.Equal(t, 0, r.st.count())

	// a directory with the entry name is not a file
	odd := t.TempDir()
	must(t, assert.NoError(t, os.Mkdir(filepath.Join(odd, "settings-window.qml"), 0o755)))
	r = newRig(t, odd, "")
	_, err = r.svc.EntryPath(KindSettings)
	assert.Error(t, err)
}

func TestRelay(t *testing.T) {
	r := newRig(t, shellTree(t, "settings-window.qml"), "")
	_, err := r.svc.handleRelay(json.RawMessage(`{"to":"shell","topic":"wallpaper.set","data":{"path":"/w.png"}}`))
	must(t, assert.NoError(t, err))
	ev := r.events(t, 1)[0]
	assert.Equal(t, "windows.relay", ev.Service)
	b, _ := json.Marshal(ev.Data)
	assert.JSONEq(t, `{"to":"shell","topic":"wallpaper.set","data":{"path":"/w.png"}}`, string(b))

	for _, bad := range []string{`{"to":"shell"}`, `{"topic":"x"}`, `{"to":"nobody","topic":"x"}`, `{`} {
		_, err := r.svc.handleRelay(json.RawMessage(bad))
		assert.Error(t, err, bad)
	}
}

func TestShellEntryFiles(t *testing.T) {
	assert.Equal(t, []string{"shell.qml", "settings-window.qml", "onboarding-window.qml"}, ShellEntryFiles())
	assert.Equal(t, "settings-window.qml", EntryFile(KindSettings))
	assert.Equal(t, "", EntryFile("shell"))
}

// The real spawner: its own process group, killed as a group.
func TestStartGroupOwnProcessGroup(t *testing.T) {
	p, err := StartGroup([]string{"sleep", "30"}, os.Environ())
	must(t, assert.NoError(t, err))
	pgid, err := syscall.Getpgid(p.Pid())
	must(t, assert.NoError(t, err))
	assert.Equal(t, p.Pid(), pgid)
	must(t, assert.NoError(t, p.Signal(syscall.SIGTERM)))
	assert.Error(t, p.Wait())
}

func must(t *testing.T, ok bool) {
	t.Helper()
	if !ok {
		t.FailNow()
	}
}
