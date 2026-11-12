package client

import (
	"bufio"
	"context"
	"errors"
	"io"
	"net"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestReadLinesSkipsEmptyAndEndsWithEOF(t *testing.T) {
	var got []string
	err := ReadLines(strings.NewReader("a\n\nb\nc"), 0, func(l []byte) { got = append(got, string(l)) })
	if !errors.Is(err, io.EOF) {
		t.Fatalf("err = %v, want io.EOF", err)
	}
	if strings.Join(got, ",") != "a,b,c" {
		t.Fatalf("lines = %q", got)
	}
}

func TestReadLinesLimit(t *testing.T) {
	long := strings.Repeat("x", 200*1024)
	n := 0
	if err := ReadLines(strings.NewReader(long+"\n"), 1<<20, func([]byte) { n++ }); !errors.Is(err, io.EOF) || n != 1 {
		t.Fatalf("line under the limit: n=%d err=%v", n, err)
	}
	if err := ReadLines(strings.NewReader(long+"\n"), 1024, func([]byte) {}); !errors.Is(err, bufio.ErrTooLong) {
		t.Fatalf("line over the limit: err=%v, want ErrTooLong", err)
	}
}

func TestSubscribeSendsRequestAndStopsOnCancel(t *testing.T) {
	sock := filepath.Join(t.TempDir(), "d.sock")
	ln, err := net.Listen("unix", sock)
	if err != nil {
		t.Fatal(err)
	}
	defer ln.Close()

	ctx, cancel := context.WithCancel(context.Background())
	lines := make(chan string, 4)
	done := make(chan error, 1)
	go func() {
		done <- Subscribe(ctx, sock, 0, func(l []byte) { lines <- string(l) })
	}()

	conn, err := ln.Accept()
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()
	req, err := bufio.NewReader(conn).ReadString('\n')
	if err != nil || !strings.Contains(req, `"method":"`+SubscribeMethod+`"`) {
		t.Fatalf("request = %q, %v", req, err)
	}
	_, _ = conn.Write([]byte(`{"jsonrpc":"2.0","method":"State.Dump"}` + "\n"))
	select {
	case l := <-lines:
		if !strings.Contains(l, "State.Dump") {
			t.Fatalf("line = %q", l)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("no line delivered")
	}

	cancel()
	select {
	case err := <-done:
		if !errors.Is(err, context.Canceled) {
			t.Fatalf("err = %v, want context.Canceled", err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("Subscribe did not return after cancel")
	}
}

func TestSubscribeReportsDaemonClose(t *testing.T) {
	sock := filepath.Join(t.TempDir(), "d.sock")
	ln, err := net.Listen("unix", sock)
	if err != nil {
		t.Fatal(err)
	}
	defer ln.Close()
	go func() {
		if c, err := ln.Accept(); err == nil {
			_, _ = bufio.NewReader(c).ReadString('\n')
			_ = c.Close()
		}
	}()
	if err := Subscribe(context.Background(), sock, 0, func([]byte) {}); !errors.Is(err, io.EOF) {
		t.Fatalf("err = %v, want io.EOF", err)
	}
}
