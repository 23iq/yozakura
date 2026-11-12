package sleep

import (
	"bufio"
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/godbus/dbus/v5"

	"yozakura/backend/pkg/ipc"
)

type runs struct {
	mu   sync.Mutex
	list []string
}

func (r *runs) add(cmd string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.list = append(r.list, cmd)
}

func (r *runs) get() []string {
	r.mu.Lock()
	defer r.mu.Unlock()
	return append([]string(nil), r.list...)
}

func set(t *testing.T, s *Service, params string) {
	t.Helper()
	if _, err := s.setCommands(json.RawMessage(params)); err != nil {
		t.Fatal(err)
	}
}

func TestSetCommandsClearsAndKeeps(t *testing.T) {
	s := &Service{}
	set(t, s, `{"before":"b","after":"a","lock":"l"}`)
	set(t, s, `{"lock":""}`)
	if b, a, l := s.commands(); b != "b" || a != "a" || l != "" {
		t.Fatalf("got %q %q %q; an empty lock clears it, absent fields stay", b, a, l)
	}
	set(t, s, `{"before":"","after":"","lock":"x"}`)
	if b, a, l := s.commands(); b != "" || a != "" || l != "x" {
		t.Fatalf("got %q %q %q", b, a, l)
	}
	if _, err := s.setCommands(json.RawMessage(`{"lock":1}`)); err == nil {
		t.Fatal("a non-string command must fail")
	}
}

func lockSignal(path dbus.ObjectPath) *dbus.Signal {
	return &dbus.Signal{Path: path, Name: "org.freedesktop.login1.Session.Lock"}
}

func TestLockOnlyFromOwnSession(t *testing.T) {
	r := &runs{}
	s := &Service{run: r.add, resolve: func() dbus.ObjectPath { return "/org/freedesktop/login1/session/_32" }}
	set(t, s, `{"lock":"lock-it","before":"pre","after":"post"}`)
	sub := ipc.NewSubscriber(8)
	s.handle(lockSignal("/org/freedesktop/login1/session/c1"), sub)
	s.handle(lockSignal("/org/freedesktop/login1/session/_32"), sub)
	s.handle(&dbus.Signal{Path: "/org/freedesktop/login1", Name: "org.freedesktop.login1.Manager.PrepareForSleep", Body: []any{true}}, sub)
	s.handle(&dbus.Signal{Path: "/org/freedesktop/login1", Name: "org.freedesktop.login1.Manager.PrepareForSleep", Body: []any{false}}, sub)
	if got := strings.Join(r.get(), ","); got != "lock-it,pre,post" {
		t.Fatalf("ran %q", got)
	}
	if len(sub.Events) != 3 {
		t.Fatalf("%d events, want LOCK, SUSPEND, WAKE", len(sub.Events))
	}

	// unresolved session: every Lock counts, as before
	r2 := &runs{}
	anySession := &Service{run: r2.add, resolve: func() dbus.ObjectPath { return "" }}
	set(t, anySession, `{"lock":"l"}`)
	anySession.handle(lockSignal("/org/freedesktop/login1/session/c1"), ipc.NewSubscriber(8))
	if len(r2.get()) != 1 {
		t.Fatal("without a resolved session a Lock still locks")
	}
}

// Run with -race: setCommands and the signal loop share the commands.
func TestCommandsConcurrent(t *testing.T) {
	r := &runs{}
	s := &Service{run: r.add}
	sub := ipc.NewSubscriber(1)
	var wg sync.WaitGroup
	wg.Add(2)
	go func() {
		defer wg.Done()
		for i := 0; i < 200; i++ {
			set(t, s, `{"lock":"a","before":"b"}`)
		}
	}()
	go func() {
		defer wg.Done()
		for i := 0; i < 200; i++ {
			s.handle(lockSignal("/s"), sub)
		}
	}()
	wg.Wait()
}

// privateBus starts a throwaway bus and owns org.freedesktop.login1 on it
// with a fake Manager (sessions: id -> path; pids: pid -> path; user
// display path).
func privateBus(t *testing.T) (client, server *dbus.Conn) {
	t.Helper()
	bin, err := exec.LookPath("dbus-daemon")
	if err != nil {
		t.Skip("dbus-daemon not installed")
	}
	sock := filepath.Join(t.TempDir(), "bus")
	cmd := exec.Command(bin, "--session", "--nofork", "--print-address", "--address=unix:path="+sock)
	out, err := cmd.StdoutPipe()
	if err != nil {
		t.Fatal(err)
	}
	if err := cmd.Start(); err != nil {
		t.Skipf("dbus-daemon: %v", err)
	}
	t.Cleanup(func() { _ = cmd.Process.Kill(); _ = cmd.Wait() })
	line, err := bufio.NewReader(out).ReadString('\n')
	if err != nil {
		t.Fatalf("bus address: %v", err)
	}
	addr := strings.TrimSpace(line)
	connect := func() *dbus.Conn {
		c, err := dbus.Connect(addr)
		if err != nil {
			t.Fatal(err)
		}
		t.Cleanup(func() { c.Close() })
		return c
	}
	return connect(), connect()
}

// fakeManager is login1's Manager; never mutated once exported (the bus
// serves it from another goroutine): serveLogin1 exports a new one.
type fakeManager struct {
	sessions map[string]dbus.ObjectPath
	pids     map[uint32]dbus.ObjectPath
	display  dbus.ObjectPath // the user's display session ("" = no user)
}

func (m *fakeManager) GetSession(id string) (dbus.ObjectPath, *dbus.Error) {
	if p, ok := m.sessions[id]; ok {
		return p, nil
	}
	return "", dbus.NewError("org.freedesktop.login1.NoSuchSession", nil)
}

func (m *fakeManager) GetSessionByPID(pid uint32) (dbus.ObjectPath, *dbus.Error) {
	if p, ok := m.pids[pid]; ok {
		return p, nil
	}
	return "", dbus.NewError("org.freedesktop.login1.NoSessionForPID", nil)
}

func (m *fakeManager) GetUser(uint32) (dbus.ObjectPath, *dbus.Error) {
	if m.display == "" {
		return "", dbus.NewError("org.freedesktop.login1.NoSuchUser", nil)
	}
	return "/org/freedesktop/login1/user/_1000", nil
}

type fakeUser struct{ display dbus.ObjectPath }

func (u fakeUser) Get(iface, name string) (dbus.Variant, *dbus.Error) {
	if iface != "org.freedesktop.login1.User" || name != "Display" {
		return dbus.Variant{}, dbus.NewError("org.freedesktop.DBus.Error.UnknownProperty", nil)
	}
	// (so), like logind
	return dbus.MakeVariant(struct {
		ID   string
		Path dbus.ObjectPath
	}{"2", u.display}), nil
}

var login1Owned sync.Map // server conn -> true

func serveLogin1(t *testing.T, server *dbus.Conn, m *fakeManager) {
	t.Helper()
	if err := server.Export(m, login1Path, login1Manager); err != nil {
		t.Fatal(err)
	}
	if err := server.Export(fakeUser{m.display}, "/org/freedesktop/login1/user/_1000", "org.freedesktop.DBus.Properties"); err != nil {
		t.Fatal(err)
	}
	if _, done := login1Owned.LoadOrStore(server, true); done {
		return
	}
	if reply, err := server.RequestName(login1Dest, dbus.NameFlagDoNotQueue); err != nil || reply != dbus.RequestNameReplyPrimaryOwner {
		t.Fatalf("own %s: %v %v", login1Dest, reply, err)
	}
}

func TestOwnSessionResolution(t *testing.T) {
	client, server := privateBus(t)
	t.Setenv("XDG_SESSION_ID", "3")
	if got := ownSession(client); got != "" {
		t.Fatalf("no login1: %q", got)
	}
	sessions := map[string]dbus.ObjectPath{"3": "/org/freedesktop/login1/session/_33"}
	serveLogin1(t, server, &fakeManager{sessions: sessions})
	if got := ownSession(client); got != "/org/freedesktop/login1/session/_33" {
		t.Fatalf("XDG_SESSION_ID: %q", got)
	}
	t.Setenv("XDG_SESSION_ID", "")
	if got := ownSession(client); got != "" {
		t.Fatalf("nothing resolves: %q", got)
	}
	pid := uint32(os.Getpid())
	serveLogin1(t, server, &fakeManager{sessions: sessions, pids: map[uint32]dbus.ObjectPath{pid: "/org/freedesktop/login1/session/_34"}})
	if got := ownSession(client); got != "/org/freedesktop/login1/session/_34" {
		t.Fatalf("by pid: %q", got)
	}
	serveLogin1(t, server, &fakeManager{display: "/org/freedesktop/login1/session/_35"})
	if got := ownSession(client); got != "/org/freedesktop/login1/session/_35" {
		t.Fatalf("user display: %q", got)
	}
	serveLogin1(t, server, &fakeManager{display: "/"})
	if got := ownSession(client); got != "" {
		t.Fatalf("no display session: %q", got)
	}
}

// End to end over a bus: another session's Lock signal is ignored, this
// session's runs the lock command.
func TestSubscribeIgnoresOtherSessionsLock(t *testing.T) {
	client, server := privateBus(t)
	serveLogin1(t, server, &fakeManager{sessions: map[string]dbus.ObjectPath{"7": "/org/freedesktop/login1/session/_37"}})
	t.Setenv("XDG_SESSION_ID", "7")
	r := &runs{}
	s := newService(client)
	s.run = r.add
	set(t, s, `{"lock":"lock-it"}`)
	sub := ipc.NewSubscriber(8)
	done := make(chan struct{})
	go func() { s.subscribe(sub); close(done) }()
	defer func() { sub.Stop(); <-done }()

	emit := func(path dbus.ObjectPath) {
		if err := server.Emit(path, "org.freedesktop.login1.Session.Lock"); err != nil {
			t.Fatal(err)
		}
	}
	waitRuns := func(n int) {
		t.Helper()
		deadline := time.Now().Add(3 * time.Second)
		for len(r.get()) < n {
			if time.Now().After(deadline) {
				t.Fatalf("ran %v, want %d runs", r.get(), n)
			}
			time.Sleep(5 * time.Millisecond)
		}
	}
	// the match is added inside subscribe: emit our Lock until it arrives
	deadline := time.Now().Add(3 * time.Second)
	for len(r.get()) == 0 && time.Now().Before(deadline) {
		emit("/org/freedesktop/login1/session/_37")
		time.Sleep(20 * time.Millisecond)
	}
	time.Sleep(50 * time.Millisecond) // retries still in flight
	base := len(r.get())
	if base == 0 {
		t.Fatal("own session's Lock did not run the lock command")
	}
	// signals from one sender arrive in order: the other session's Locks
	// are handled before ours, and must add nothing
	emit("/org/freedesktop/login1/session/c9")
	emit("/org/freedesktop/login1/session/c9")
	emit("/org/freedesktop/login1/session/_37")
	waitRuns(base + 1)
	time.Sleep(50 * time.Millisecond)
	if got := r.get(); len(got) != base+1 || got[len(got)-1] != "lock-it" {
		t.Fatalf("ran %v, want %d lock-it runs", got, base+1)
	}
}
