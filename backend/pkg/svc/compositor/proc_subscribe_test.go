package compositor

import (
	"bufio"
	"errors"
	"fmt"
	"net"
	"os"
	"strings"
	"testing"
	"time"
)

// acceptSubscriber accepts the Manager's next connection on ln and checks
// that it asks for the event stream.
func acceptSubscriber(t *testing.T, ln net.Listener) (net.Conn, *bufio.Reader) {
	t.Helper()
	_ = ln.(*net.UnixListener).SetDeadline(time.Now().Add(5 * time.Second))
	conn, err := ln.Accept()
	if err != nil {
		t.Fatalf("no subscribe connection: %v", err)
	}
	_ = conn.SetReadDeadline(time.Now().Add(5 * time.Second))
	r := bufio.NewReader(conn)
	req, err := r.ReadString('\n')
	if err != nil || !strings.Contains(req, `"System.Subscribe"`) {
		t.Fatalf("subscribe request = %q, %v", req, err)
	}
	return conn, r
}

func sendLayout(t *testing.T, conn net.Conn, name, pad string) {
	t.Helper()
	line := fmt.Sprintf(`{"id":1,"result":"subscribed"}`+"\n"+
		`{"jsonrpc":"2.0","method":"State.Dump","state":{"keyboard_layout":{"name":%q},"windows":[{"title":%q}]}}`+"\n", name, pad)
	if _, err := conn.Write([]byte(line)); err != nil {
		t.Fatal(err)
	}
}

func layoutIs(m *Manager, name string) func() bool {
	want := fmt.Sprintf(`{"name":%q}`, name)
	return func() bool { return string(m.State().KeyboardLayout) == want }
}

// The event stream is read in-process: a dropped connection (the daemon
// restarting) is re-established, oversized-but-allowed lines still decode,
// and Close ends the stream for good without leaving a goroutine behind.
func TestManagerSubscribeReconnectsAndCloses(t *testing.T) {
	toml, ln := fakeDaemonSocket(t)
	m := NewManager(tomlPath(toml))
	if err := m.Start(); err != nil {
		t.Fatal(err)
	}
	ch, cancel := m.Subscribe()
	defer cancel()

	conn1, _ := acceptSubscriber(t, ln)
	// Larger than bufio's default 64 KiB token: must still be accepted.
	sendLayout(t, conn1, "first", strings.Repeat("x", 256*1024))
	waitFor(t, "first state", layoutIs(m, "first"))
	select {
	case st := <-ch:
		if len(st.Windows) != 1 {
			t.Fatalf("broadcast state = %+v", st)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("first state not broadcast")
	}

	// Daemon goes away: the Manager reconnects on its own.
	_ = conn1.Close()
	conn2, r2 := acceptSubscriber(t, ln)
	sendLayout(t, conn2, "second", "")
	waitFor(t, "state after reconnect", layoutIs(m, "second"))

	m.Close()

	done := make(chan struct{})
	go func() { m.wg.Wait(); close(done) }()
	select {
	case <-done:
	case <-time.After(3 * time.Second):
		t.Fatal("manager goroutines still running after Close")
	}

	// Close dropped the connection...
	_ = conn2.SetReadDeadline(time.Now().Add(2 * time.Second))
	if _, err := r2.ReadByte(); err == nil || errors.Is(err, os.ErrDeadlineExceeded) {
		t.Fatalf("subscribe connection still open after Close (err %v)", err)
	}
	// ...and nothing reconnects afterwards.
	_ = ln.(*net.UnixListener).SetDeadline(time.Now().Add(3 * subscribeRetryDelay))
	if c, err := ln.Accept(); err == nil {
		_ = c.Close()
		t.Fatal("manager reconnected after Close")
	}
	// The subscriber channel is closed.
	for range ch {
	}
}
