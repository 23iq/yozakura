package proc

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"
)

func TestRunStdout(t *testing.T) {
	out, err := Run(context.Background(), "sh", "-c", `printf '%s' "$1"`, "sh", "hi there")
	if err != nil || string(out) != "hi there" {
		t.Fatalf("out=%q err=%v", out, err)
	}
}

func TestRunStderrInError(t *testing.T) {
	_, err := Run(context.Background(), "sh", "-c", `echo boom >&2; exit 3`)
	var pe *Error
	if !errors.As(err, &pe) {
		t.Fatalf("want *Error, got %v", err)
	}
	if !strings.Contains(pe.Stderr, "boom") || !strings.Contains(err.Error(), "boom") {
		t.Fatalf("stderr missing: %v", err)
	}
}

func TestRunTrue(t *testing.T) {
	if _, err := Run(context.Background(), "true"); err != nil {
		t.Fatal(err)
	}
}

func TestRunMissingBinary(t *testing.T) {
	if _, err := Run(context.Background(), "definitely-not-a-binary-xyz"); err == nil {
		t.Fatal("expected error")
	}
}

func TestTimeout(t *testing.T) {
	start := time.Now()
	_, err := RunWith(context.Background(), Options{Timeout: 100 * time.Millisecond}, "sleep", "5")
	if err == nil || time.Since(start) > 3*time.Second {
		t.Fatalf("timeout not enforced: %v after %v", err, time.Since(start))
	}
}

func TestContextCancel(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	go func() { time.Sleep(50 * time.Millisecond); cancel() }()
	if _, err := Run(ctx, "sleep", "5"); err == nil {
		t.Fatal("expected cancel error")
	}
}

func TestStdinAndCombined(t *testing.T) {
	out, err := RunWith(context.Background(), Options{Stdin: strings.NewReader("abc")}, "cat")
	if err != nil || string(out) != "abc" {
		t.Fatalf("out=%q err=%v", out, err)
	}
	out, err = RunWith(context.Background(), Options{Combined: true}, "sh", "-c", "echo o; echo e >&2; exit 1")
	if err == nil || !strings.Contains(string(out), "o") || !strings.Contains(string(out), "e") {
		t.Fatalf("out=%q err=%v", out, err)
	}
}

func TestStartKilledByCtx(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cmd, err := Start(ctx, "sleep", "5")
	if err != nil {
		t.Fatal(err)
	}
	cancel()
	done := make(chan error, 1)
	go func() { done <- cmd.Wait() }()
	select {
	case err := <-done:
		if err == nil {
			t.Fatal("expected kill error")
		}
	case <-time.After(3 * time.Second):
		t.Fatal("child not killed")
	}
}
