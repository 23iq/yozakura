package voice

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"mime/multipart"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
)

// ServerSpec identifies one whisper-server configuration. A change of any
// field restarts the server.
type ServerSpec struct {
	Bin       string
	Model     string
	VADModel  string // "" disables server-side Silero VAD
	UseGPU    bool
	ExtraArgs []string
}

// Result is a finished transcription.
type Result struct {
	Text     string `json:"text"`
	Language string `json:"language"`
}

// ProcStarter launches the server process; tests replace it with a fake.
type ProcStarter func(spec ServerSpec, port int, logPath string) (*exec.Cmd, error)

// Server owns a whisper-server child on 127.0.0.1: started on demand,
// stopped after an idle timeout or on Close. Safe for concurrent use.
type Server struct {
	Start   ProcStarter
	LogPath string
	// ReadyTimeout bounds model loading (large models on CPU are slow).
	ReadyTimeout time.Duration

	mu      sync.Mutex
	cmd     *exec.Cmd
	exited  chan struct{}
	spec    ServerSpec
	port    int
	idle    *time.Timer
	idleDur time.Duration
	busy    int
	client  *http.Client
}

// NewServer returns a server using the real whisper-server binary.
func NewServer(logPath string) *Server {
	return &Server{
		Start:        startWhisperServer,
		LogPath:      logPath,
		ReadyTimeout: 90 * time.Second,
		client:       &http.Client{},
	}
}

// Running reports whether a server child is alive.
func (s *Server) Running() bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.aliveLocked()
}

func (s *Server) aliveLocked() bool {
	if s.cmd == nil {
		return false
	}
	select {
	case <-s.exited:
		return false
	default:
		return true
	}
}

// SetIdleTimeout sets how long the server may stay unused (0 = forever).
func (s *Server) SetIdleTimeout(d time.Duration) {
	s.mu.Lock()
	s.idleDur = d
	s.mu.Unlock()
}

// Ensure starts (or restarts, if spec changed) the server and waits until
// it answers /health. The idle timer is paused until Release.
func (s *Server) Ensure(ctx context.Context, spec ServerSpec) error {
	s.mu.Lock()
	s.busy++
	if s.idle != nil {
		s.idle.Stop()
	}
	if s.aliveLocked() && !specEqual(s.spec, spec) {
		s.stopLocked()
	}
	if !s.aliveLocked() {
		if err := s.spawnLocked(spec); err != nil {
			s.mu.Unlock()
			return err
		}
	}
	port, exited := s.port, s.exited
	s.mu.Unlock()
	return s.waitReady(ctx, port, exited)
}

// Release marks one Ensure caller done and arms the idle timer.
func (s *Server) Release() {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.busy > 0 {
		s.busy--
	}
	if s.busy > 0 || s.idleDur <= 0 || s.cmd == nil {
		return
	}
	if s.idle != nil {
		s.idle.Stop()
	}
	s.idle = time.AfterFunc(s.idleDur, func() {
		s.mu.Lock()
		defer s.mu.Unlock()
		if s.busy == 0 {
			s.stopLocked()
		}
	})
}

// Close stops the server child, if any.
func (s *Server) Close() {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.idle != nil {
		s.idle.Stop()
	}
	s.stopLocked()
}

func (s *Server) spawnLocked(spec ServerSpec) error {
	port, err := freePort()
	if err != nil {
		return err
	}
	cmd, err := s.Start(spec, port, s.LogPath)
	if err != nil {
		return err
	}
	exited := make(chan struct{})
	go func() { _ = cmd.Wait(); close(exited) }()
	s.cmd, s.exited, s.spec, s.port = cmd, exited, spec, port
	return nil
}

func (s *Server) stopLocked() {
	if s.cmd == nil {
		return
	}
	cmd, exited := s.cmd, s.exited
	s.cmd = nil
	if cmd.Process != nil {
		_ = syscall.Kill(-cmd.Process.Pid, syscall.SIGTERM)
		select {
		case <-exited:
		case <-time.After(2 * time.Second):
			_ = syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL)
			<-exited
		}
	}
}

func (s *Server) waitReady(ctx context.Context, port int, exited <-chan struct{}) error {
	deadline := time.Now().Add(s.ReadyTimeout)
	url := fmt.Sprintf("http://127.0.0.1:%d/health", port)
	for {
		req, _ := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
		resp, err := s.client.Do(req)
		if err == nil {
			_, _ = io.Copy(io.Discard, resp.Body)
			resp.Body.Close()
			if resp.StatusCode == http.StatusOK {
				return nil
			}
		}
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-exited:
			return fmt.Errorf("whisper-server exited during startup (see %s)", s.LogPath)
		case <-time.After(50 * time.Millisecond):
		}
		if time.Now().After(deadline) {
			return errors.New("whisper-server did not become ready")
		}
	}
}

// Transcribe posts a WAV to /inference. language is a whisper code or
// "auto".
func (s *Server) Transcribe(ctx context.Context, wav []byte, language string) (Result, error) {
	s.mu.Lock()
	port, alive := s.port, s.aliveLocked()
	s.mu.Unlock()
	if !alive {
		return Result{}, errors.New("whisper-server is not running")
	}
	var body bytes.Buffer
	mw := multipart.NewWriter(&body)
	fw, _ := mw.CreateFormFile("file", "speech.wav")
	_, _ = fw.Write(wav)
	fields := map[string]string{
		"response_format": "verbose_json",
		"temperature":     "0.0",
		"temperature_inc": "0.2",
		"language":        language,
		"no_timestamps":   "true",
	}
	for k, v := range fields {
		_ = mw.WriteField(k, v)
	}
	_ = mw.Close()
	url := fmt.Sprintf("http://127.0.0.1:%d/inference", port)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, &body)
	if err != nil {
		return Result{}, err
	}
	req.Header.Set("Content-Type", mw.FormDataContentType())
	resp, err := s.client.Do(req)
	if err != nil {
		return Result{}, err
	}
	defer resp.Body.Close()
	data, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		return Result{}, fmt.Errorf("whisper-server: %s: %s", resp.Status, strings.TrimSpace(string(data)))
	}
	var out struct {
		Text     string `json:"text"`
		Language string `json:"language"`
		Error    string `json:"error"`
	}
	if err := json.Unmarshal(data, &out); err != nil {
		return Result{}, fmt.Errorf("whisper-server: bad response: %w", err)
	}
	if out.Error != "" {
		return Result{}, errors.New(out.Error)
	}
	return Result{Text: out.Text, Language: out.Language}, nil
}

func specEqual(a, b ServerSpec) bool {
	return a.Bin == b.Bin && a.Model == b.Model && a.VADModel == b.VADModel &&
		a.UseGPU == b.UseGPU && strings.Join(a.ExtraArgs, "\x00") == strings.Join(b.ExtraArgs, "\x00")
}

func freePort() (int, error) {
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return 0, err
	}
	defer l.Close()
	return l.Addr().(*net.TCPAddr).Port, nil
}

// ServerArgs builds the whisper-server command line for spec.
func ServerArgs(spec ServerSpec, port int) []string {
	args := []string{
		"-m", spec.Model,
		"--host", "127.0.0.1",
		"--port", strconv.Itoa(port),
		"-l", "auto",
		"-nt",
	}
	if !spec.UseGPU {
		// whisper-server defaults to 4 threads; CPU decoding scales well
		// up to ~8-10 cores.
		args = append(args, "-ng", "-t", strconv.Itoa(cpuThreads()))
	}
	if spec.VADModel != "" {
		args = append(args, "--vad", "-vm", spec.VADModel)
	}
	return append(args, spec.ExtraArgs...)
}

func cpuThreads() int {
	n := runtime.NumCPU() / 2
	return max(2, min(n, 10))
}

func startWhisperServer(spec ServerSpec, port int, logPath string) (*exec.Cmd, error) {
	if !fileExists(spec.Bin) {
		return nil, fmt.Errorf("whisper-server not installed (%s); run scripts/voice_setup.sh", spec.Bin)
	}
	if !fileExists(spec.Model) {
		return nil, fmt.Errorf("model not found: %s", spec.Model)
	}
	cmd := exec.Command(spec.Bin, ServerArgs(spec, port)...)
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true, Pdeathsig: syscall.SIGTERM}
	var logFile *os.File
	if logPath != "" {
		_ = os.MkdirAll(filepath.Dir(logPath), 0o755)
		if f, err := os.Create(logPath); err == nil {
			logFile = f
			cmd.Stdout, cmd.Stderr = f, f
		}
	}
	err := cmd.Start()
	if logFile != nil {
		_ = logFile.Close() // the child keeps its own descriptor
	}
	if err != nil {
		return nil, err
	}
	return cmd, nil
}
