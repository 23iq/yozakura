package voice

import (
	"context"
	"encoding/binary"
	"math/rand"
	"os"
	"path/filepath"
	"sync"
	"testing"
	"time"
)

// fakeCapture plays synthetic PCM, then blocks like a live microphone
// until Close.
type fakeCapture struct {
	data   []byte
	pos    int
	closed chan struct{}
	once   sync.Once
	mu     sync.Mutex
}

func newFakeCapture(samples []int16) *fakeCapture {
	b := make([]byte, len(samples)*2)
	for i, s := range samples {
		binary.LittleEndian.PutUint16(b[2*i:], uint16(s))
	}
	return &fakeCapture{data: b, closed: make(chan struct{})}
}

func (f *fakeCapture) Read(p []byte) (int, error) {
	f.mu.Lock()
	if f.pos < len(f.data) {
		n := copy(p, f.data[f.pos:])
		f.pos += n
		f.mu.Unlock()
		return n, nil
	}
	f.mu.Unlock()
	<-f.closed
	return 0, os.ErrClosed
}

func (f *fakeCapture) Close() error {
	f.once.Do(func() { close(f.closed) })
	return nil
}

func (f *fakeCapture) isClosed() bool {
	select {
	case <-f.closed:
		return true
	default:
		return false
	}
}

type fakeTranscriber struct {
	mu        sync.Mutex
	text      string
	lang      string
	err       error
	delay     time.Duration
	ensures   int
	releases  int
	calls     int
	gotWAVLen int
	running   bool
}

func (f *fakeTranscriber) Ensure(ctx context.Context, _ ServerSpec) error {
	f.mu.Lock()
	f.ensures++
	f.running = true
	f.mu.Unlock()
	return nil
}
func (f *fakeTranscriber) Release() { f.mu.Lock(); f.releases++; f.mu.Unlock() }
func (f *fakeTranscriber) Transcribe(ctx context.Context, wav []byte, _ string) (Result, error) {
	f.mu.Lock()
	f.calls++
	f.gotWAVLen = len(wav)
	d := f.delay
	f.mu.Unlock()
	select {
	case <-time.After(d):
	case <-ctx.Done():
		return Result{}, ctx.Err()
	}
	return Result{Text: f.text, Language: f.lang}, f.err
}
func (f *fakeTranscriber) SetIdleTimeout(time.Duration) {}
func (f *fakeTranscriber) Running() bool                { f.mu.Lock(); defer f.mu.Unlock(); return f.running }
func (f *fakeTranscriber) Close()                       {}
func (f *fakeTranscriber) counts() (int, int, int) {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.ensures, f.releases, f.calls
}

type harness struct {
	svc     *Service
	cap     *fakeCapture
	opened  int
	tr      *fakeTranscriber
	states  chan Snapshot
	levels  int
	mu      sync.Mutex
	clock   time.Time
	clockMu sync.Mutex
}

// newHarness builds a service with a fake install (dummy files), the
// given config JSON and audio.
func newHarness(t *testing.T, cfgJSON string, audio []int16) *harness {
	t.Helper()
	dir := t.TempDir()
	inst := Install{Root: filepath.Join(dir, "whisper")}
	for _, p := range []string{inst.ServerBin(), inst.ModelPath("large-v3-turbo-q5_0")} {
		if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(p, []byte("x"), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	cfgPath := filepath.Join(dir, "voice.json")
	if cfgJSON != "" {
		if err := os.WriteFile(cfgPath, []byte(cfgJSON), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	h := &harness{tr: &fakeTranscriber{text: " Привет, мир. ", lang: "russian"}, states: make(chan Snapshot, 64), clock: time.Unix(1000, 0)}
	h.cap = newFakeCapture(audio)
	factory := func() (Capture, error) {
		h.mu.Lock()
		h.opened++
		h.mu.Unlock()
		return h.cap, nil
	}
	h.svc = newService(cfgPath, inst, factory, h.tr)
	h.svc.now = func() time.Time { h.clockMu.Lock(); defer h.clockMu.Unlock(); return h.clock }
	h.svc.onEvent = func(name string, data any) {
		switch name {
		case "voice.state":
			h.states <- data.(Snapshot)
		case "voice.level":
			h.mu.Lock()
			h.levels++
			h.mu.Unlock()
		}
	}
	return h
}

func (h *harness) advance(d time.Duration) {
	h.clockMu.Lock()
	h.clock = h.clock.Add(d)
	h.clockMu.Unlock()
}

// waitFor returns the first state event with state want.
func (h *harness) waitFor(t *testing.T, want string) Snapshot {
	t.Helper()
	timeout := time.After(5 * time.Second)
	for {
		select {
		case s := <-h.states:
			if s.State == want {
				return s
			}
		case <-timeout:
			t.Fatalf("timed out waiting for state %q (now %q)", want, h.svc.Snapshot().State)
		}
	}
}

func utterance(seed int64) []int16 {
	rng := rand.New(rand.NewSource(seed))
	return withRoom(rng, -60, noise(rng, 0.5, -90), speechLike(rng, 1.2, -20), noise(rng, 3, -90))
}

func TestToggleModeAutoStopsOnSilence(t *testing.T) {
	h := newHarness(t, `{"activation":"toggle","vadSilenceMs":800}`, utterance(1))
	snap := h.svc.Press(TargetDictation)
	if snap.State != StateListening || !snap.HandsFree || snap.Target != TargetDictation {
		t.Fatalf("press: %+v", snap)
	}
	h.waitFor(t, StateTranscribing)
	if !h.cap.isClosed() {
		t.Fatal("microphone still open while transcribing")
	}
	done := h.waitFor(t, StateDone)
	if done.Text != "Привет, мир." || done.Language != "ru" || done.Reason != ReasonVAD {
		t.Fatalf("done: %+v", done)
	}
	if done.RecordMs < 2300 || done.RecordMs > 2900 {
		t.Errorf("recorded %d ms, want ~2.5 s (1.7 s audio + 0.8 s hangover)", done.RecordMs)
	}
	if e, r, c := h.tr.counts(); e != 1 || r != 1 || c != 1 {
		t.Errorf("ensure/release/transcribe = %d/%d/%d, want 1/1/1", e, r, c)
	}
	if h.levels < 50 {
		t.Errorf("only %d level events", h.levels)
	}
	if h.svc.Snapshot().State != StateDone {
		t.Error("final snapshot not kept")
	}
	// A new session can start after the previous one ended.
	h.cap = newFakeCapture(utterance(2))
	if s := h.svc.Press(TargetAI); s.State != StateListening {
		t.Fatalf("second session: %+v", s)
	}
	h.svc.Cancel()
	h.waitFor(t, StateCancelled)
}

func TestPushToTalkHoldStopsOnRelease(t *testing.T) {
	// Speech continues past the release: no VAD stop while held.
	rng := rand.New(rand.NewSource(3))
	audio := withRoom(rng, -60, speechLike(rng, 1, -20), noise(rng, 2, -90))
	h := newHarness(t, `{"activation":"push-to-talk"}`, audio)
	h.svc.Press(TargetAI)
	time.Sleep(50 * time.Millisecond)
	h.advance(time.Second)
	h.svc.Release()
	tr := h.waitFor(t, StateTranscribing)
	if tr.Reason != ReasonRelease {
		t.Fatalf("reason %q", tr.Reason)
	}
	if d := h.waitFor(t, StateDone); d.Target != TargetAI {
		t.Fatalf("done: %+v", d)
	}
}

func TestPushToTalkTapBecomesHandsFree(t *testing.T) {
	h := newHarness(t, `{"activation":"push-to-talk","vadSilenceMs":600}`, utterance(4))
	h.svc.Press(TargetDictation)
	h.advance(100 * time.Millisecond)
	if s := h.svc.Release(); !s.HandsFree || s.State != StateListening {
		t.Fatalf("tap did not switch to hands-free: %+v", s)
	}
	if d := h.waitFor(t, StateTranscribing); d.Reason != ReasonVAD {
		t.Fatalf("hands-free stop reason %q", d.Reason)
	}
	h.waitFor(t, StateDone)
}

func TestSecondPressStops(t *testing.T) {
	rng := rand.New(rand.NewSource(5))
	h := newHarness(t, `{"activation":"toggle","vadAutoStop":false}`, withRoom(rng, -60, speechLike(rng, 1, -20)))
	h.svc.Press(TargetAI)
	time.Sleep(50 * time.Millisecond)
	h.svc.Press(TargetAI)
	if d := h.waitFor(t, StateTranscribing); d.Reason != ReasonToggle {
		t.Fatalf("reason %q", d.Reason)
	}
	h.waitFor(t, StateDone)
}

func TestCancelDiscardsWithoutTranscribing(t *testing.T) {
	h := newHarness(t, `{"activation":"toggle"}`, utterance(6))
	h.svc.Press(TargetAI)
	h.svc.Cancel()
	h.waitFor(t, StateCancelled)
	if !h.cap.isClosed() {
		t.Fatal("microphone left open after cancel")
	}
	if _, r, c := h.tr.counts(); c != 0 || r != 1 {
		t.Fatalf("transcribe calls %d (want 0), releases %d (want 1)", c, r)
	}
}

func TestCancelDuringTranscription(t *testing.T) {
	h := newHarness(t, `{"activation":"toggle","vadSilenceMs":500}`, utterance(7))
	h.tr.delay = 10 * time.Second
	h.svc.Press(TargetAI)
	h.waitFor(t, StateTranscribing)
	h.svc.Cancel()
	h.waitFor(t, StateCancelled)
}

func TestNoSpeechTimesOutHandsFree(t *testing.T) {
	rng := rand.New(rand.NewSource(8))
	h := newHarness(t, `{"activation":"toggle","noSpeechTimeout":2}`, noise(rng, 5, -60))
	h.svc.Press(TargetAI)
	e := h.waitFor(t, StateEmpty)
	if e.Reason != ReasonNoSpeech || e.RecordMs < 1900 || e.RecordMs > 2200 {
		t.Fatalf("empty: %+v", e)
	}
	if _, _, c := h.tr.counts(); c != 0 {
		t.Fatal("transcribed silence")
	}
}

func TestMaxDuration(t *testing.T) {
	rng := rand.New(rand.NewSource(9))
	h := newHarness(t, `{"activation":"toggle","maxSeconds":5,"vadAutoStop":false}`, withRoom(rng, -60, speechLike(rng, 7, -20)))
	h.svc.Press(TargetAI)
	if d := h.waitFor(t, StateTranscribing); d.Reason != ReasonMax {
		t.Fatalf("reason %q", d.Reason)
	}
	d := h.waitFor(t, StateDone)
	if d.RecordMs < 4990 || d.RecordMs > 5100 {
		t.Errorf("recorded %d ms, want 5 s", d.RecordMs)
	}
}

func TestEmptyTranscriptIsEmptyState(t *testing.T) {
	h := newHarness(t, `{"activation":"toggle","vadSilenceMs":500}`, utterance(10))
	h.tr.text = " [BLANK_AUDIO] "
	h.svc.Press(TargetAI)
	h.waitFor(t, StateEmpty)
}

func TestUnavailableNeverOpensMicrophone(t *testing.T) {
	for _, tc := range []struct{ cfg, want string }{
		{`{"enabled":false}`, "disabled"},
		{`{"model":"tiny"}`, "model_missing"},
	} {
		h := newHarness(t, tc.cfg, utterance(11))
		s := h.svc.Press(TargetAI)
		if s.State != StateError || s.Error != tc.want {
			t.Errorf("%s: %+v", tc.cfg, s)
		}
		if h.opened != 0 {
			t.Errorf("%s: microphone opened", tc.cfg)
		}
	}
	h := newHarness(t, "", utterance(12))
	_ = os.Remove(h.svc.Install.ServerBin())
	if s := h.svc.Press(TargetAI); s.Error != "not_installed" || h.opened != 0 {
		t.Errorf("not installed: %+v opened=%d", s, h.opened)
	}
}

func TestLoadConfigDefaultsAndValidation(t *testing.T) {
	dir := t.TempDir()
	p := filepath.Join(dir, "voice.json")
	if c := LoadConfig(p); c != DefaultConfig() {
		t.Fatalf("missing file: %+v", c)
	}
	_ = os.WriteFile(p, []byte(`{"activation":"bogus","maxSeconds":0,"language":" RU ","typingMethod":"x","vadSensitivity":3}`), 0o644)
	c := LoadConfig(p)
	d := DefaultConfig()
	if c.Mode != d.Mode || c.MaxSeconds != d.MaxSeconds || c.Language != "ru" || c.TypingMethod != "auto" || c.VadSensitivity != d.VadSensitivity {
		t.Fatalf("not normalised: %+v", c)
	}
}

func TestReleaseRacingAheadOfPressCountsAsTap(t *testing.T) {
	h := newHarness(t, `{"activation":"push-to-talk","vadSilenceMs":600}`, utterance(13))
	h.svc.Release() // the release CLI won the race
	h.advance(80 * time.Millisecond)
	if s := h.svc.Press(TargetAI); !s.HandsFree {
		t.Fatalf("orphan release not treated as a tap: %+v", s)
	}
	if d := h.waitFor(t, StateTranscribing); d.Reason != ReasonVAD {
		t.Fatalf("reason %q", d.Reason)
	}
	h.waitFor(t, StateDone)
}

func TestLostReleaseEndsHoldAfterLongSilence(t *testing.T) {
	rng := rand.New(rand.NewSource(14))
	audio := withRoom(rng, -60, noise(rng, 0.3, -90), speechLike(rng, 1, -20), noise(rng, 8, -90))
	h := newHarness(t, `{"activation":"push-to-talk","vadSilenceMs":800}`, audio)
	h.svc.Press(TargetDictation)
	d := h.waitFor(t, StateTranscribing)
	// speech ends ~1.3 s, the VAD hangover (0.8 s) ends the utterance at
	// ~2.1 s, then hold silence = max(4 s, 3*0.8 s) → ~6.1 s
	if d.Reason != ReasonVAD || d.ElapsedMs < 5800 || d.ElapsedMs > 6400 {
		t.Fatalf("hold without release: %+v", d)
	}
	h.waitFor(t, StateDone)
}
