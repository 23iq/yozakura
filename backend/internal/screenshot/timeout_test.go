package screenshot

import (
	"errors"
	"io"
	"net"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/AvengeMedia/dankgo/wayland/client"
	"yozakura/backend/internal/proto/wlr_screencopy"
)

// A compositor that accepts requests but never sends the sync/frame event
// must not leave the shared backend request connection blocked indefinitely.
func TestUnresponsiveCompositor(t *testing.T) {
	for _, stage := range []string{"registry", "frame"} {
		t.Run(stage, func(t *testing.T) {
			dir := t.TempDir()
			addr := filepath.Join(dir, "wayland-test")
			listener, err := net.Listen("unix", addr)
			if err != nil {
				t.Fatal(err)
			}
			defer listener.Close()
			closed := make(chan struct{})
			go func() {
				defer close(closed)
				conn, err := listener.Accept()
				if err != nil {
					return
				}
				defer conn.Close()
				// Bound the regression itself when production has no deadline.
				timer := time.AfterFunc(6*time.Second, func() { conn.Close() })
				defer timer.Stop()
				_, _ = io.Copy(io.Discard, conn)
			}()

			engine := NewEngine(CursorOff)
			defer engine.Close()
			if stage == "registry" {
				t.Setenv("XDG_RUNTIME_DIR", dir)
				t.Setenv("WAYLAND_DISPLAY", "wayland-test")
				err = engine.Connect()
			} else {
				display, connectErr := client.Connect(addr)
				if connectErr != nil {
					t.Fatal(connectErr)
				}
				engine.display, engine.ctx = display, display.Context()
				engine.screencopy = wlr_screencopy.NewZwlrScreencopyManagerV1(engine.ctx)
				engine.outputs[1] = &WaylandOutput{name: "DP-1", wlOutput: client.NewOutput(engine.ctx)}
				_, err = engine.CaptureOutputFrame("DP-1")
			}
			if !errors.Is(err, os.ErrDeadlineExceeded) {
				t.Fatalf("stalled %s should time out, got %v", stage, err)
			}
			engine.Close()
			select {
			case <-closed:
			case <-time.After(time.Second):
				t.Fatal("timed-out Wayland connection was not closed")
			}
		})
	}
}
