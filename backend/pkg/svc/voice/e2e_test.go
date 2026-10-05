package voice

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// TestEndToEndRealWhisper runs the whole pipeline (fake microphone fed
// with a WAV file → VAD → real whisper-server → transcript). Opt-in, needs
// scripts/voice_setup.sh to have run:
//
//	YOZAKURA_VOICE_E2E=1 go test ./pkg/svc/voice -run EndToEnd -v
//
// YOZAKURA_VOICE_WAV picks the audio (default: whisper.cpp's jfk.wav, whose
// ~1.3 s oratory pause needs a hangover above the 1.2 s default).
func TestEndToEndRealWhisper(t *testing.T) {
	if os.Getenv("YOZAKURA_VOICE_E2E") != "1" {
		t.Skip("set YOZAKURA_VOICE_E2E=1 to run against the installed whisper-server")
	}
	home, _ := os.UserHomeDir()
	inst := NewInstall(filepath.Join(home, ".local/share/yozakura"))
	wav := os.Getenv("YOZAKURA_VOICE_WAV")
	if wav == "" {
		wav = filepath.Join(inst.Root, "src/samples/jfk.wav")
	}
	data, err := os.ReadFile(wav)
	if err != nil || !fileExists(inst.ServerBin()) {
		t.Skipf("whisper install or sample missing: %v", err)
	}
	// 16 kHz mono s16 WAV; skip to the data chunk (ffmpeg adds LIST)
	off := strings.Index(string(data), "data")
	if off < 0 {
		t.Fatal("no data chunk")
	}
	pcm := DecodePCM(data[off+8:])
	silence := make([]int16, SampleRate*2)
	audio := append(append([]int16{}, pcm...), silence...)

	dir := t.TempDir()
	cfg := filepath.Join(dir, "voice.json")
	_ = os.WriteFile(cfg, []byte(`{"activation":"toggle","vadSilenceMs":1500}`), 0o644)
	srv := NewServer(filepath.Join(dir, "server.log"))
	defer srv.Close()
	fc := newFakeCapture(audio)
	svc := newService(cfg, inst, func() (Capture, error) { return fc, nil }, srv)
	states := make(chan Snapshot, 16)
	svc.onEvent = func(name string, data any) {
		if s, ok := data.(Snapshot); ok && name == "voice.state" {
			states <- s
		}
	}
	t0 := time.Now()
	svc.Press(TargetAI)
	timeout := time.After(2 * time.Minute)
	var tStop time.Time
	for {
		select {
		case s := <-states:
			switch s.State {
			case StateTranscribing:
				tStop = time.Now()
			case StateDone:
				t.Logf("reason=%s text=%q lang=%s record=%dms transcribe=%dms stop→text=%s total=%s",
					s.Reason, s.Text, s.Language, s.RecordMs, s.TranscribeMs, time.Since(tStop), time.Since(t0))
				if !strings.Contains(strings.ToLower(s.Text), "ask not what your country") && os.Getenv("YOZAKURA_VOICE_WAV") == "" {
					t.Fatalf("unexpected transcript %q", s.Text)
				}
				return
			case StateError, StateEmpty, StateCancelled:
				t.Fatalf("session ended with %+v", s)
			}
		case <-timeout:
			t.Fatal("timed out")
		}
	}
}
