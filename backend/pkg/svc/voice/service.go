// Package voice is fully local speech-to-text: the microphone is captured
// with pw-record only while a session is active, transcribed by a
// whisper.cpp server on 127.0.0.1 (started on demand, stopped when idle),
// and the text is handed to the shell (AI center or dictation typing).
//
// IPC (service "voice"):
//
//	press   {target}   keybind press: start, or stop the running session
//	release {}         keybind release: stop a push-to-talk hold
//	start   {target, mode?}  explicit start (UI)
//	stop    {}         finish recording and transcribe
//	cancel  {}         discard the session
//	type    {text, raw?, method?}  type into the focused window (dictation);
//	                   punctuation/trailing space from config unless raw
//	status  {}         Snapshot + install info
//	warm / unload      pre-start / stop the whisper server
//
// Events: voice.state (Snapshot) on every transition, voice.level (Level)
// ~31 times per second while listening.
package voice

import (
	"context"
	"encoding/json"
	"errors"
	"path/filepath"
	"sync"
	"time"

	"yozakura/backend/pkg/ipc"
	"yozakura/backend/pkg/paths"
)

// Targets for transcripts.
const (
	TargetAI        = "ai"
	TargetDictation = "dictation"
)

// Transcriber is the whisper server; tests substitute a fake.
type Transcriber interface {
	Ensure(ctx context.Context, spec ServerSpec) error
	Release()
	Transcribe(ctx context.Context, wav []byte, language string) (Result, error)
	SetIdleTimeout(d time.Duration)
	Running() bool
	Close()
}

// Service is the voice IPC service.
type Service struct {
	ConfigPath string
	Install    Install
	Capture    CaptureFactory
	Typer      *Typer

	server Transcriber
	now    func() time.Time

	startMu sync.Mutex // serialises Start
	mu      sync.Mutex
	sess    *session
	snap    Snapshot
	// lastOrphanRelease is when a release arrived with no session (it
	// raced ahead of its press); see orphanReleaseWindow.
	lastOrphanRelease time.Time
	seq               int

	subsMu sync.Mutex
	subs   []*ipc.Subscriber
	// onEvent observes broadcasts (tests).
	onEvent func(name string, data any)
}

// NewService wires the real recorder, whisper server and typer.
func NewService(p *paths.Paths) *Service {
	return newService(
		p.Config("voice"),
		NewInstall(p.DataDir),
		NewProcCaptureFactory(),
		NewServer(filepath.Join(p.CacheDir, "whisper-server.log")),
	)
}

func newService(cfgPath string, inst Install, capture CaptureFactory, server Transcriber) *Service {
	return &Service{
		ConfigPath: cfgPath,
		Install:    inst,
		Capture:    capture,
		Typer:      NewTyper(),
		server:     server,
		now:        time.Now,
		snap:       Snapshot{State: StateIdle},
	}
}

// Register exposes the service over IPC.
func (svc *Service) Register(srv *ipc.Server) { srv.Register(svc.ipcService()) }

func (svc *Service) ipcService() *ipc.Service {
	return &ipc.Service{
		Name: "voice",
		Methods: map[string]ipc.HandlerFunc{
			"press":   svc.ipcPress,
			"release": func(json.RawMessage) (any, error) { return svc.Release(), nil },
			"start":   svc.ipcStart,
			"stop":    func(json.RawMessage) (any, error) { return svc.Stop(ReasonStop), nil },
			"cancel":  func(json.RawMessage) (any, error) { return svc.Cancel(), nil },
			"type":    svc.ipcType,
			"status":  func(json.RawMessage) (any, error) { return svc.Status(), nil },
			"warm":    func(json.RawMessage) (any, error) { return svc.Warm(), nil },
			"unload":  func(json.RawMessage) (any, error) { svc.server.Close(); return svc.Status(), nil },
		},
		Subscribe: svc.subscribe,
		// type spawns wtype/wl-copy/ydotool; keep it off the serial loop.
		Async: map[string]bool{"type": true},
	}
}

// Close cancels any session and stops the whisper server.
func (svc *Service) Close() {
	svc.Cancel()
	svc.server.Close()
}

func (svc *Service) config() Config { return LoadConfig(svc.ConfigPath) }

func (svc *Service) specFor(cfg Config) ServerSpec {
	spec := ServerSpec{
		Bin:    svc.Install.ServerBin(),
		Model:  svc.Install.ModelPath(cfg.Model),
		UseGPU: cfg.UseGPU,
	}
	if cfg.ServerVad && fileExists(svc.Install.VADModel()) {
		spec.VADModel = svc.Install.VADModel()
	}
	return spec
}

// Press toggles: starts a session for target, or stops the running one.
func (svc *Service) Press(target string) Snapshot {
	svc.mu.Lock()
	sess := svc.sess
	listening := sess != nil && svc.snap.State == StateListening
	svc.mu.Unlock()
	if sess == nil {
		return svc.Start(target, "")
	}
	if listening {
		sess.requestStop(ReasonToggle)
	}
	return svc.Snapshot()
}

// Release ends a push-to-talk hold. A quick tap (release within
// tapThreshold) switches the session to hands-free instead.
func (svc *Service) Release() Snapshot {
	svc.mu.Lock()
	sess := svc.sess
	if sess == nil {
		svc.lastOrphanRelease = svc.now()
	}
	if sess == nil || svc.snap.State != StateListening || sess.cfg.Mode != ModePushToTalk || sess.handsFree {
		snap := svc.snap
		svc.mu.Unlock()
		return snap
	}
	if svc.now().Sub(sess.started) < tapThreshold {
		sess.handsFree = true
		svc.snap.HandsFree = true
		snap := svc.snap
		svc.mu.Unlock()
		svc.broadcast("voice.state", snap)
		return snap
	}
	svc.mu.Unlock()
	sess.requestStop(ReasonRelease)
	return svc.Snapshot()
}

// Start begins a session. mode "" uses the configured mode.
func (svc *Service) Start(target, mode string) Snapshot {
	if target != TargetAI && target != TargetDictation {
		target = TargetAI
	}
	svc.startMu.Lock()
	defer svc.startMu.Unlock()
	cfg := svc.config()
	if mode == ModePushToTalk || mode == ModeToggle {
		cfg.Mode = mode
	}
	svc.mu.Lock()
	if svc.sess != nil {
		snap := svc.snap
		svc.mu.Unlock()
		return snap
	}
	svc.seq++
	id := svc.seq
	svc.mu.Unlock()

	fail := func(msg string) Snapshot {
		snap := Snapshot{State: StateError, Session: id, Target: target, Mode: cfg.Mode, Reason: "unavailable", Error: msg}
		svc.mu.Lock()
		svc.snap = snap
		svc.mu.Unlock()
		svc.broadcast("voice.state", snap)
		return snap
	}
	// Validate the install before the microphone is ever opened.
	spec := svc.specFor(cfg)
	switch {
	case !cfg.Enabled:
		return fail("disabled")
	case !fileExists(spec.Bin):
		return fail("not_installed")
	case !fileExists(spec.Model):
		return fail("model_missing")
	}
	svc.server.SetIdleTimeout(time.Duration(cfg.IdleTimeout) * time.Second)

	capture, err := svc.Capture()
	if err != nil {
		return fail(err.Error())
	}
	ctx, cancel := context.WithCancel(context.Background())
	now := svc.now()
	svc.mu.Lock()
	tap := cfg.Mode == ModePushToTalk && now.Sub(svc.lastOrphanRelease) < orphanReleaseWindow
	svc.mu.Unlock()
	sess := &session{
		id: id, target: target, cfg: cfg, spec: spec,
		started:   now,
		handsFree: cfg.Mode == ModeToggle || tap,
		stopCh:    make(chan string, 1),
		ctx:       ctx, cancel: cancel,
	}
	lang := cfg.Language
	snap := Snapshot{
		State: StateListening, Session: id, Target: target, Mode: cfg.Mode,
		HandsFree: sess.handsFree, StartedAt: sess.started.UnixMilli(), Language: lang,
	}
	svc.mu.Lock()
	svc.sess = sess
	svc.snap = snap
	svc.mu.Unlock()
	svc.broadcast("voice.state", snap)
	go svc.run(sess, capture)
	return snap
}

// Stop finishes recording and transcribes.
func (svc *Service) Stop(reason string) Snapshot {
	svc.mu.Lock()
	sess := svc.sess
	svc.mu.Unlock()
	if sess != nil {
		sess.requestStop(reason)
	}
	return svc.Snapshot()
}

// Cancel discards the session (recording or transcribing).
func (svc *Service) Cancel() Snapshot {
	svc.mu.Lock()
	sess := svc.sess
	svc.mu.Unlock()
	if sess != nil {
		sess.requestStop(ReasonCancel)
		sess.cancel()
	}
	return svc.Snapshot()
}

// Snapshot returns the current state.
func (svc *Service) Snapshot() Snapshot {
	svc.mu.Lock()
	defer svc.mu.Unlock()
	return svc.snap
}

func (svc *Service) handsFree(sess *session) bool {
	svc.mu.Lock()
	defer svc.mu.Unlock()
	return sess.handsFree
}

// update mutates the snapshot of a live session and broadcasts it.
func (svc *Service) update(sess *session, fn func(*Snapshot)) {
	svc.mu.Lock()
	if svc.sess != sess {
		svc.mu.Unlock()
		return
	}
	fn(&svc.snap)
	snap := svc.snap
	svc.mu.Unlock()
	svc.broadcast("voice.state", snap)
}

// end publishes a terminal state and frees the slot for a new session.
func (svc *Service) end(sess *session, final Snapshot) {
	svc.mu.Lock()
	base := svc.snap
	final.Session, final.Target, final.Mode = sess.id, sess.target, sess.cfg.Mode
	final.HandsFree, final.StartedAt = base.HandsFree, base.StartedAt
	if final.Language == "" {
		final.Language = base.Language
	}
	final.ElapsedMs = final.RecordMs
	svc.snap = final
	if svc.sess == sess {
		svc.sess = nil
	}
	svc.mu.Unlock()
	svc.broadcast("voice.state", final)
}

// Status reports the session plus install/server info for Settings.
func (svc *Service) Status() map[string]any {
	cfg := svc.config()
	return map[string]any{
		"snapshot":      svc.Snapshot(),
		"installed":     fileExists(svc.Install.ServerBin()),
		"backend":       svc.Install.Backend(),
		"models":        svc.Install.Models(),
		"modelPresent":  fileExists(svc.Install.ModelPath(cfg.Model)),
		"vadModel":      fileExists(svc.Install.VADModel()),
		"serverRunning": svc.server.Running(),
	}
}

// Warm starts the server in the background so the first session is fast.
func (svc *Service) Warm() map[string]any {
	cfg := svc.config()
	spec := svc.specFor(cfg)
	if fileExists(spec.Bin) && fileExists(spec.Model) {
		svc.server.SetIdleTimeout(time.Duration(cfg.IdleTimeout) * time.Second)
		go func() {
			_ = svc.server.Ensure(context.Background(), spec)
			svc.server.Release()
		}()
	}
	return svc.Status()
}

func (svc *Service) ipcPress(params json.RawMessage) (any, error) {
	return svc.Press(paramString(params, "target")), nil
}

func (svc *Service) ipcStart(params json.RawMessage) (any, error) {
	return svc.Start(paramString(params, "target"), paramString(params, "mode")), nil
}

func (svc *Service) ipcType(params json.RawMessage) (any, error) {
	text := paramString(params, "text")
	if text == "" {
		return nil, errors.New("voice.type: empty text")
	}
	cfg := svc.config()
	if raw, _ := paramBool(params, "raw"); !raw {
		text = FormatDictation(text, cfg.Punctuation, cfg.TrailingSpace)
	}
	method := paramString(params, "method")
	if method == "" {
		method = cfg.TypingMethod
	}
	used, err := svc.Typer.Type(text, method)
	if err != nil {
		return nil, err
	}
	return map[string]any{"method": used}, nil
}

func (svc *Service) subscribe(sub *ipc.Subscriber) {
	svc.subsMu.Lock()
	svc.subs = append(svc.subs, sub)
	svc.subsMu.Unlock()
	sub.Send("voice.state", svc.Snapshot())
	go func() {
		<-sub.StopCh()
		svc.subsMu.Lock()
		defer svc.subsMu.Unlock()
		for i, x := range svc.subs {
			if x == sub {
				svc.subs = append(svc.subs[:i], svc.subs[i+1:]...)
				return
			}
		}
	}()
}

func (svc *Service) broadcast(name string, data any) {
	if svc.onEvent != nil {
		svc.onEvent(name, data)
	}
	svc.subsMu.Lock()
	subs := append([]*ipc.Subscriber(nil), svc.subs...)
	svc.subsMu.Unlock()
	for _, sub := range subs {
		sub.Send(name, data)
	}
}

func paramString(params json.RawMessage, key string) string {
	var m map[string]any
	if len(params) == 0 || json.Unmarshal(params, &m) != nil {
		return ""
	}
	v, _ := m[key].(string)
	return v
}

func paramBool(params json.RawMessage, key string) (bool, bool) {
	var m map[string]any
	if len(params) == 0 || json.Unmarshal(params, &m) != nil {
		return false, false
	}
	v, ok := m[key].(bool)
	return v, ok
}
