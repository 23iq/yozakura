// Package convert is the daemon's file converter service: it probes files
// (format, targets, smart default), runs conversions (pkg/convert) with
// bounded concurrency and publishes each job's state, reads the clipboard
// for files or image data, and copies a result to the clipboard.
//
// IPC (service "convert"):
//
//	formats {}                          -> {formats, engines}  (MCP / scripts; the window probes)
//	probe {paths}                       -> {files: [File]}
//	start {items: [{path, target}], outDir?, quality?} -> {jobs: [Job]}
//	cancel {id}                         -> {}
//	clear {}                            -> {}   forget finished jobs (MCP / scripts)
//	paste {}                            -> {paths}  files or image data on the clipboard
//	copy {path}                         -> {}   a result to the clipboard
//
// Events: convert.job (Job) on every change; a subscriber first gets every
// job still known. Progress is published at most every progressEvery; an
// event a full subscriber buffer refused is made good by resending every
// job (see resync), so a job's final state is never lost.
package convert

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"sync"
	"time"

	conv "yozakura/backend/pkg/convert"
	"yozakura/backend/pkg/ipc"
)

// toolsTTL: how long a detection of the installed engines is used before
// it is refreshed (in the background: callers keep the previous one).
const toolsTTL = 2 * time.Minute

// Options are the side effects of the service (faked in tests).
type Options struct {
	Detect    func() *conv.Tools
	CacheDir  string // pasted images, LibreOffice profile
	Home      string // where results of pasted images go
	Clipboard Clipboard
	Workers   int
}

// Service is the convert IPC service.
type Service struct {
	o Options

	// tools is detected without s.mu: detection runs programs for seconds
	tools toolCache

	mu      sync.Mutex
	jobs    map[string]*Job
	order   []string
	subs    []*subscription
	cancels map[string]func()
	seq     int
	// resyncing: a retry of the stale subscribers is scheduled
	resyncing bool

	sem chan struct{}
	// one LibreOffice at a time on this process's profile; a channel so a
	// cancelled job stops waiting
	office  chan struct{}
	wg      sync.WaitGroup
	stopped bool
}

// NewService returns the service with the real host.
func NewService(cacheDir string) *Service {
	home, _ := os.UserHomeDir()
	return New(Options{
		Detect:    func() *conv.Tools { return conv.DetectTools(nil) },
		CacheDir:  filepath.Join(cacheDir, "convert"),
		Home:      home,
		Clipboard: wlClipboard{},
	})
}

// New builds a service from explicit options.
func New(o Options) *Service {
	if o.Workers <= 0 {
		o.Workers = 2
	}
	s := &Service{o: o, jobs: map[string]*Job{}, cancels: map[string]func(){}, sem: make(chan struct{}, o.Workers),
		office: make(chan struct{}, 1), tools: toolCache{ready: make(chan struct{})}}
	s.sweep()
	return s
}

// Register exposes the service over IPC.
func (s *Service) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "convert",
		Methods: map[string]ipc.HandlerFunc{
			"formats": s.formats, "probe": s.probe, "start": s.start, "cancel": s.cancel,
			"clear": s.clear, "paste": s.paste, "copy": s.copy,
		},
		Subscribe: s.subscribe,
		// start detects every file's format (a slow or hung mount must not
		// stall the shell's ordered connection)
		Async: map[string]bool{"formats": true, "probe": true, "start": true, "paste": true, "copy": true},
	})
}

// toolCache holds the last detection of the installed engines.
type toolCache struct {
	mu         sync.Mutex
	tools      *conv.Tools
	at         time.Time
	refreshing bool
	ready      chan struct{} // closed by the first detection
}

// Tools returns the detected engines. Only the very first call waits for a
// detection; later ones get the last result at once, and one past toolsTTL
// starts a refresh in the background. s.mu is never held meanwhile.
func (s *Service) Tools() *conv.Tools {
	c := &s.tools
	c.mu.Lock()
	t := c.tools
	if (t == nil || time.Since(c.at) > toolsTTL) && !c.refreshing {
		c.refreshing = true
		go s.refreshTools()
	}
	c.mu.Unlock()
	if t != nil {
		return t
	}
	<-c.ready
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.tools
}

func (s *Service) refreshTools() {
	t := s.o.Detect()
	c := &s.tools
	c.mu.Lock()
	first := c.tools == nil
	c.tools, c.at, c.refreshing = t, time.Now(), false
	c.mu.Unlock()
	if first {
		close(c.ready)
	}
}

func (s *Service) formats(json.RawMessage) (any, error) {
	t := s.Tools()
	engines := []string{}
	for _, e := range t.Installed() {
		engines = append(engines, string(e))
	}
	return map[string]any{"formats": conv.Formats(), "engines": engines}, nil
}

// File is the probe of one path.
type File struct {
	Path        string        `json:"path"`
	Name        string        `json:"name"`
	Size        int64         `json:"size"`
	Kind        conv.Kind     `json:"kind"`
	Format      string        `json:"format"`
	FormatLabel string        `json:"formatLabel"`
	Targets     []conv.Target `json:"targets"`
	Default     string        `json:"default"`
	Error       string        `json:"error,omitempty"`
}

// Probe describes one file: its format, targets and the proposed one.
func Probe(path string, t *conv.Tools) File {
	f := File{Path: path, Name: filepath.Base(path), Targets: []conv.Target{}}
	st, err := os.Stat(path)
	switch {
	case err != nil:
		f.Error = "not found"
		return f
	case st.IsDir():
		f.Error = "a folder"
		return f
	case !st.Mode().IsRegular():
		// a FIFO or a device: never opened (reading could block)
		f.Error = "not a regular file"
		return f
	}
	f.Size = st.Size()
	fm, ok := conv.Detect(path)
	if !ok {
		f.Error = "unknown format"
		return f
	}
	f.Kind, f.Format, f.FormatLabel = fm.Kind, fm.ID, fm.Label
	f.Targets = conv.Targets(fm.ID, t)
	f.Default = conv.Default(fm.ID, t)
	return f
}

func (s *Service) probe(params json.RawMessage) (any, error) {
	var p struct {
		Paths []string `json:"paths"`
	}
	if err := json.Unmarshal(params, &p); err != nil || len(p.Paths) == 0 {
		return nil, errors.New("paths is required")
	}
	t := s.Tools()
	files := make([]File, 0, len(p.Paths))
	for _, path := range p.Paths {
		if abs, err := filepath.Abs(path); err == nil {
			path = abs
		}
		files = append(files, Probe(path, t))
	}
	return map[string]any{"files": files}, nil
}

// subscription is a subscriber and whether it missed an event.
type subscription struct {
	sub   *ipc.Subscriber
	stale bool
}

// resyncEvery: how soon a subscriber that missed an event gets every job
// again.
const resyncEvery = 200 * time.Millisecond

func (s *Service) subscribe(sub *ipc.Subscriber) {
	s.mu.Lock()
	w := &subscription{sub: sub}
	s.subs = append(s.subs, w)
	s.resync(w)
	s.mu.Unlock()
	go func() {
		<-sub.StopCh()
		s.mu.Lock()
		defer s.mu.Unlock()
		for i, x := range s.subs {
			if x == w {
				s.subs = append(s.subs[:i], s.subs[i+1:]...)
				return
			}
		}
	}()
}

// publish sends a copy of the job to every subscriber; s.mu is held. A
// subscriber whose buffer is full is resent every job later instead.
func (s *Service) publish(j *Job) {
	for _, w := range s.subs {
		if w.stale {
			s.resync(w)
		} else if !w.sub.TrySend("convert.job", *j) {
			w.stale = true
			s.scheduleResync()
		}
	}
}

// resync sends every job to w (the current state of each: whatever it
// missed); w stays stale until all fit. s.mu is held.
func (s *Service) resync(w *subscription) {
	w.stale = false
	for _, id := range s.order {
		if !w.sub.TrySend("convert.job", *s.jobs[id]) {
			w.stale = true
			s.scheduleResync()
			return
		}
	}
}

// scheduleResync retries the stale subscribers after resyncEvery, until
// none is left (a finished job publishes nothing more on its own). s.mu is
// held.
func (s *Service) scheduleResync() {
	if s.resyncing {
		return
	}
	s.resyncing = true
	time.AfterFunc(resyncEvery, func() {
		s.mu.Lock()
		defer s.mu.Unlock()
		s.resyncing = false
		for _, w := range s.subs {
			if w.stale {
				s.resync(w)
			}
		}
	})
}
