package voice

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"strings"
	"syscall"
	"testing"
	"time"
)

// TestHelperFakeWhisperServer is not a real test: when re-executed with
// VOICE_FAKE_SERVER=1 it impersonates whisper-server (503 while "loading
// the model", then /health ok and a canned /inference answer).
func TestHelperFakeWhisperServer(t *testing.T) {
	if os.Getenv("VOICE_FAKE_SERVER") != "1" {
		t.Skip("helper process")
	}
	port := os.Getenv("VOICE_FAKE_PORT")
	if os.Getenv("VOICE_FAKE_CRASH") == "1" {
		os.Exit(3)
	}
	ready := time.Now().Add(150 * time.Millisecond)
	mux := http.NewServeMux()
	mux.HandleFunc("/health", func(w http.ResponseWriter, _ *http.Request) {
		if time.Now().Before(ready) {
			w.WriteHeader(http.StatusServiceUnavailable)
			return
		}
		fmt.Fprint(w, `{"status":"ok"}`)
	})
	mux.HandleFunc("/inference", func(w http.ResponseWriter, r *http.Request) {
		if err := r.ParseMultipartForm(1 << 20); err != nil {
			http.Error(w, err.Error(), 400)
			return
		}
		f, _, err := r.FormFile("file")
		if err != nil {
			http.Error(w, "no file", 400)
			return
		}
		f.Close()
		fmt.Fprintf(w, `{"text":" hello from %s ","language":"english","model":%q}`,
			r.FormValue("language"), os.Getenv("VOICE_FAKE_MODEL"))
	})
	_ = http.ListenAndServe("127.0.0.1:"+port, mux)
	os.Exit(0)
}

func fakeStarter(crash bool) ProcStarter {
	return func(spec ServerSpec, port int, _ string) (*exec.Cmd, error) {
		cmd := exec.Command(os.Args[0], "-test.run=^TestHelperFakeWhisperServer$")
		cmd.Env = append(os.Environ(), "VOICE_FAKE_SERVER=1",
			fmt.Sprintf("VOICE_FAKE_PORT=%d", port), "VOICE_FAKE_MODEL="+spec.Model)
		if crash {
			cmd.Env = append(cmd.Env, "VOICE_FAKE_CRASH=1")
		}
		cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
		return cmd, cmd.Start()
	}
}

func newFakeServer(crash bool) *Server {
	s := NewServer("")
	s.Start = fakeStarter(crash)
	s.ReadyTimeout = 10 * time.Second
	return s
}

func (s *Server) pid() int {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.cmd == nil {
		return 0
	}
	return s.cmd.Process.Pid
}

func TestServerLifecycle(t *testing.T) {
	s := newFakeServer(false)
	defer s.Close()
	ctx := context.Background()
	specA := ServerSpec{Bin: "whisper-server", Model: "a.bin", UseGPU: true}

	if s.Running() {
		t.Fatal("running before Ensure")
	}
	if _, err := s.Transcribe(ctx, EncodeWAV(make([]int16, 1600)), "auto"); err == nil {
		t.Fatal("transcribe without a server should fail")
	}
	if err := s.Ensure(ctx, specA); err != nil {
		t.Fatal(err)
	}
	pid := s.pid()
	res, err := s.Transcribe(ctx, EncodeWAV(make([]int16, 1600)), "ru")
	if err != nil || strings.TrimSpace(res.Text) != "hello from ru" || res.Language != "english" {
		t.Fatalf("transcribe: %+v %v", res, err)
	}
	s.Release()

	// Same spec: reused, no restart.
	if err := s.Ensure(ctx, specA); err != nil || s.pid() != pid {
		t.Fatalf("restarted for an unchanged spec (err=%v)", err)
	}
	s.Release()

	// Different model: restarted.
	specB := specA
	specB.Model = "b.bin"
	if err := s.Ensure(ctx, specB); err != nil || s.pid() == pid {
		t.Fatalf("not restarted for a new model (err=%v)", err)
	}
	s.Release()

	// Idle timeout stops it; Ensure brings it back.
	s.SetIdleTimeout(200 * time.Millisecond)
	if err := s.Ensure(ctx, specB); err != nil {
		t.Fatal(err)
	}
	time.Sleep(400 * time.Millisecond)
	if !s.Running() {
		t.Fatal("idle timer fired while busy")
	}
	s.Release()
	deadline := time.Now().Add(3 * time.Second)
	for s.Running() && time.Now().Before(deadline) {
		time.Sleep(20 * time.Millisecond)
	}
	if s.Running() {
		t.Fatal("idle server not stopped")
	}
	if err := s.Ensure(ctx, specB); err != nil || !s.Running() {
		t.Fatalf("restart after idle: %v", err)
	}
	s.Release()
	s.Close()
	if s.Running() {
		t.Fatal("Close left the server running")
	}
}

func TestServerStartupCrash(t *testing.T) {
	s := newFakeServer(true)
	defer s.Close()
	err := s.Ensure(context.Background(), ServerSpec{Model: "a.bin"})
	if err == nil || !strings.Contains(err.Error(), "exited") {
		t.Fatalf("want startup exit error, got %v", err)
	}
	s.Release()
}

func TestServerEnsureCancelled(t *testing.T) {
	s := newFakeServer(false)
	defer s.Close()
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if err := s.Ensure(ctx, ServerSpec{Model: "a.bin"}); err == nil {
		t.Fatal("cancelled Ensure succeeded")
	}
	s.Release()
}

func TestServerArgs(t *testing.T) {
	got := strings.Join(ServerArgs(ServerSpec{Model: "m.bin", VADModel: "v.bin", UseGPU: false}, 9999), " ")
	for _, want := range []string{"-m m.bin", "--host 127.0.0.1", "--port 9999", "-ng", "--vad -vm v.bin"} {
		if !strings.Contains(got, want) {
			t.Errorf("args %q missing %q", got, want)
		}
	}
	if strings.Contains(strings.Join(ServerArgs(ServerSpec{Model: "m", UseGPU: true}, 1), " "), "-ng") {
		t.Error("-ng with GPU enabled")
	}
}
