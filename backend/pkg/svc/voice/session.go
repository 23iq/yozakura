package voice

import (
	"context"
	"errors"
	"io"
	"time"
)

// Session states, as sent in voice.state events.
const (
	StateIdle         = "idle"
	StateListening    = "listening"
	StateTranscribing = "transcribing"
	StateDone         = "done"      // text ready
	StateEmpty        = "empty"     // nothing was said / recognised
	StateCancelled    = "cancelled" // user cancelled
	StateError        = "error"
)

// Stop reasons.
const (
	ReasonRelease  = "release"
	ReasonToggle   = "toggle"
	ReasonStop     = "stop"
	ReasonCancel   = "cancel"
	ReasonVAD      = "vad"
	ReasonMax      = "max_duration"
	ReasonNoSpeech = "no_speech"
	ReasonCapture  = "capture_ended"
)

// tapThreshold separates a tap from a hold in push-to-talk mode: a release
// sooner than this keeps listening hands-free (stopped by VAD or a second
// press) instead of stopping immediately.
const tapThreshold = 350 * time.Millisecond

// holdSilenceMin is the shortest silence that ends a push-to-talk hold
// whose key release was lost.
const holdSilenceMin = 4 * time.Second

// orphanReleaseWindow: a release that arrives this long before its press
// (two CLI processes racing) still counts as a tap.
const orphanReleaseWindow = 500 * time.Millisecond

// minSpeech is the shortest recording worth transcribing.
const minSpeech = 300 * time.Millisecond

// Snapshot is the payload of voice.state events and voice.status.
type Snapshot struct {
	State        string `json:"state"`
	Session      int    `json:"session"`
	Target       string `json:"target"`
	Mode         string `json:"mode"`
	HandsFree    bool   `json:"handsFree"`
	StartedAt    int64  `json:"startedAt"`
	ElapsedMs    int    `json:"elapsedMs"`
	Language     string `json:"language"`
	Text         string `json:"text"`
	Reason       string `json:"reason"`
	Error        string `json:"error"`
	RecordMs     int    `json:"recordMs"`
	TranscribeMs int    `json:"transcribeMs"`
}

// Level is the payload of voice.level events (~31 per second).
type Level struct {
	Session   int       `json:"session"`
	Level     float64   `json:"level"`
	Bands     []float64 `json:"bands"`
	Speech    bool      `json:"speech"`
	ElapsedMs int       `json:"elapsedMs"`
}

type session struct {
	id        int
	target    string
	cfg       Config
	spec      ServerSpec
	started   time.Time
	handsFree bool
	stopCh    chan string
	ctx       context.Context
	cancel    context.CancelFunc
}

// requestStop delivers a stop reason once; later ones are ignored.
func (s *session) requestStop(reason string) {
	select {
	case s.stopCh <- reason:
	default:
	}
}

// readFrames splits a capture stream into FrameSamples frames.
func readFrames(r io.Reader, out chan<- []int16, errc chan<- error) {
	defer close(out)
	buf := make([]byte, FrameSamples*2)
	for {
		if _, err := io.ReadFull(r, buf); err != nil {
			if !errors.Is(err, io.EOF) && !errors.Is(err, io.ErrUnexpectedEOF) {
				errc <- err
			}
			return
		}
		out <- DecodePCM(buf)
	}
}

// run drives one session: capture → VAD/levels → stop → transcribe.
func (svc *Service) run(sess *session, capture Capture) {
	warm := make(chan error, 1)
	go func() { warm <- svc.server.Ensure(sess.ctx, sess.spec) }()

	frames := make(chan []int16, 64)
	readErr := make(chan error, 1)
	go readFrames(capture, frames, readErr)

	vad := NewEnergyVAD(sess.cfg.VadSensitivity, sess.cfg.VadSilenceMs)
	samples := make([]int16, 0, SampleRate*10)
	maxDur := time.Duration(sess.cfg.MaxSeconds) * time.Second
	noSpeech := time.Duration(sess.cfg.NoSpeechTimeout) * time.Second
	holdSilence := max(holdSilenceMin, 3*time.Duration(sess.cfg.VadSilenceMs)*time.Millisecond)
	var lastSpeech time.Duration
	reason := ""

loop:
	for {
		select {
		case reason = <-sess.stopCh:
			break loop
		case f, ok := <-frames:
			if !ok {
				reason = ReasonCapture
				break loop
			}
			samples = append(samples, f...)
			e := FrameEnergy(f)
			ev := vad.Push(e)
			el := time.Duration(len(samples)) * time.Second / SampleRate
			svc.broadcast("voice.level", Level{
				Session: sess.id, Level: LevelFromEnergy(e), Bands: Bands(f),
				Speech: vad.InSpeech(), ElapsedMs: int(el / time.Millisecond),
			})
			if vad.InSpeech() {
				lastSpeech = el
			}
			hands := svc.handsFree(sess)
			switch {
			case el >= maxDur:
				reason = ReasonMax
			case hands && sess.cfg.VadAutoStop && ev == VADSpeechEnd:
				reason = ReasonVAD
			case hands && noSpeech > 0 && !vad.HadSpeech() && el >= noSpeech:
				reason = ReasonNoSpeech
			// Held key whose release never arrived (e.g. the modifier was
			// let go first and the compositor skipped the release bind):
			// a long silence ends the session instead of maxSeconds.
			case !hands && vad.HadSpeech() && !vad.InSpeech() && el-lastSpeech >= holdSilence:
				reason = ReasonVAD
			case !hands && noSpeech > 0 && !vad.HadSpeech() && el >= 2*noSpeech:
				reason = ReasonNoSpeech
			}
			if reason != "" {
				break loop
			}
		}
	}
	// Close the microphone before anything else.
	_ = capture.Close()
	recorded := time.Duration(len(samples)) * time.Second / SampleRate
	recordMs := int(recorded / time.Millisecond)

	var warmErr error
	warmed := false
	waitWarm := func() error {
		if !warmed {
			warmErr, warmed = <-warm, true
		}
		return warmErr
	}
	finish := func(snap Snapshot) {
		sess.cancel()
		_ = waitWarm()
		svc.server.Release()
		snap.RecordMs = recordMs
		svc.end(sess, snap)
	}

	if reason == ReasonCapture {
		select {
		case err := <-readErr:
			finish(Snapshot{State: StateError, Reason: reason, Error: err.Error()})
			return
		default:
		}
		if recorded < minSpeech {
			finish(Snapshot{State: StateError, Reason: reason, Error: "microphone capture stopped"})
			return
		}
	}
	switch {
	case reason == ReasonCancel:
		finish(Snapshot{State: StateCancelled, Reason: reason})
		return
	case reason == ReasonNoSpeech, recorded < minSpeech,
		svc.handsFree(sess) && !vad.HadSpeech():
		finish(Snapshot{State: StateEmpty, Reason: ReasonNoSpeech})
		return
	}

	svc.update(sess, func(s *Snapshot) {
		s.State = StateTranscribing
		s.Reason = reason
		s.ElapsedMs = recordMs
	})
	t0 := time.Now()
	ctx, cancel := context.WithTimeout(sess.ctx, 2*time.Minute)
	defer cancel()
	var res Result
	err := waitWarm()
	if err == nil {
		res, err = svc.server.Transcribe(ctx, EncodeWAV(samples), sess.cfg.Language)
	}
	took := int(time.Since(t0) / time.Millisecond)
	switch {
	case errors.Is(err, context.Canceled):
		finish(Snapshot{State: StateCancelled, Reason: ReasonCancel, TranscribeMs: took})
	case err != nil:
		finish(Snapshot{State: StateError, Reason: reason, Error: err.Error(), TranscribeMs: took})
	default:
		text := CleanTranscript(res.Text)
		lang := LangCode(res.Language)
		if lang == "" && sess.cfg.Language != "auto" {
			lang = sess.cfg.Language
		}
		state := StateDone
		if text == "" {
			state = StateEmpty
			reason = ReasonNoSpeech
		}
		finish(Snapshot{State: state, Reason: reason, Text: text, Language: lang, TranscribeMs: took})
	}
}
