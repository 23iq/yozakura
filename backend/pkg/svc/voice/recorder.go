package voice

import (
	"errors"
	"io"
	"os/exec"
	"sync"
	"syscall"
	"time"
	"yozakura/backend/pkg/brand"
)

// Capture is a live microphone stream of raw s16le 16 kHz mono PCM.
// Close must stop the capture process: the microphone is only ever open
// between Start and Close.
type Capture interface {
	io.Reader
	Close() error
}

// CaptureFactory opens the default PipeWire source.
type CaptureFactory func() (Capture, error)

// procCapture streams stdout of pw-record / parecord.
type procCapture struct {
	cmd      *exec.Cmd
	out      io.ReadCloser
	once     sync.Once
	stopOnce sync.Once
	stop     chan struct{} // closed on EOF/read error or Close: Wait may run
	done     chan struct{} // closed after cmd.Wait returned
}

func (p *procCapture) Read(b []byte) (int, error) {
	n, err := p.out.Read(b)
	if err != nil {
		p.release()
	}
	return n, err
}

func (p *procCapture) release() { p.stopOnce.Do(func() { close(p.stop) }) }

func (p *procCapture) Close() error {
	p.once.Do(func() {
		if p.cmd.Process != nil {
			_ = p.cmd.Process.Signal(syscall.SIGTERM)
		}
		p.release() // the caller is done reading: let Wait reap the recorder
		select {
		case <-p.done:
		case <-time.After(time.Second):
			_ = p.cmd.Process.Kill()
			<-p.done
		}
	})
	return nil
}

// captureCommands lists recorders in order of preference. The node name
// and application name make the stream identifiable in the privacy
// indicator and pavucontrol ("Voice input").
func captureCommands() [][]string {
	return [][]string{
		{"pw-record", "--raw", "--rate", "16000", "--channels", "1", "--format", "s16",
			"--latency", "32ms",
			"-P", `{ application.name = "Voice input" node.name = "` + brand.AppID + `-voice" media.role = "Communication" }`,
			"-"},
		{"parecord", "--raw", "--rate=16000", "--channels=1", "--format=s16le",
			"--latency-msec=32", "--client-name=Voice input", "--stream-name=" + brand.AppID + "-voice"},
	}
}

var errStart = errors.New("capture: start failed")

// startCapture runs argv with stdout piped to the returned Capture.
func startCapture(argv []string) (*procCapture, error) {
	cmd := exec.Command(argv[0], argv[1:]...)
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true, Pdeathsig: syscall.SIGTERM}
	out, err := cmd.StdoutPipe()
	if err != nil {
		return nil, err
	}
	if err := cmd.Start(); err != nil {
		return nil, errors.Join(errStart, err)
	}
	pc := &procCapture{cmd: cmd, out: out, done: make(chan struct{}), stop: make(chan struct{})}
	// Wait closes the stdout pipe, so it may only run once the reader has
	// drained it (EOF) or the capture is being closed; otherwise audio still
	// buffered in the pipe is lost when the recorder exits.
	go func() {
		<-pc.stop
		_ = cmd.Wait()
		close(pc.done)
	}()
	return pc, nil
}

// NewProcCaptureFactory returns a factory spawning the first available
// recorder from captureCommands.
func NewProcCaptureFactory() CaptureFactory {
	return func() (Capture, error) {
		for _, argv := range captureCommands() {
			if _, err := exec.LookPath(argv[0]); err != nil {
				continue
			}
			pc, err := startCapture(argv)
			if errors.Is(err, errStart) {
				continue
			}
			return pc, err
		}
		return nil, errors.New("no recorder found (install pipewire's pw-record or pulseaudio-utils' parecord)")
	}
}
