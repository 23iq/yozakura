package voice

import (
	"io"
	"testing"
	"time"
)

// A recorder that exits on its own (device gone, pw-record crash) must not
// take the audio still buffered in the pipe with it: cmd.Wait closes the
// read end, so it may only run after the reader saw EOF.
func TestCaptureKeepsBufferedAudioAfterExit(t *testing.T) {
	pc, err := startCapture([]string{"sh", "-c", "printf 'pcm-data'"})
	if err != nil {
		t.Fatal(err)
	}
	time.Sleep(300 * time.Millisecond) // the recorder has exited by now
	got, err := io.ReadAll(pc)
	if err != nil {
		t.Fatalf("read after exit: %v", err)
	}
	if string(got) != "pcm-data" {
		t.Fatalf("got %q, want buffered audio", got)
	}
	select {
	case <-pc.done:
	case <-time.After(2 * time.Second):
		t.Fatal("recorder not reaped after EOF")
	}
	_ = pc.Close()
}

func TestCaptureCloseStopsRunningRecorder(t *testing.T) {
	pc, err := startCapture([]string{"sh", "-c", "exec sleep 30"})
	if err != nil {
		t.Fatal(err)
	}
	done := make(chan struct{})
	go func() { _ = pc.Close(); close(done) }()
	select {
	case <-done:
	case <-time.After(3 * time.Second):
		t.Fatal("Close did not stop the recorder")
	}
}
