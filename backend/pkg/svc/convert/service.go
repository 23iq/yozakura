// Package convert is the daemon's file converter service: it probes files
// (format, targets, smart default), runs conversions (pkg/convert) with
// bounded concurrency and publishes each job's state, reads the clipboard
// for files or image data, and copies a result to the clipboard.
//
// IPC (service "convert"):
//
//	formats {}                          -> {formats, engines}
//	probe {paths}                       -> {files: [File]}
//	start {items: [{path, target}], outDir?, quality?} -> {jobs: [Job]}
//	cancel {id}                         -> {}
//	clear {}                            -> {}   forget finished jobs
//	paste {}                            -> {paths}  files or image data on the clipboard
//	copy {path}                         -> {}   a result to the clipboard
//
// Events: convert.job (Job) on every change; a subscriber first gets every
// job still known.
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

// toolsTTL: how long a detection of the installed engines is reused.
const toolsTTL = 30 * time.Second

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

	mu      sync.Mutex
	tools   *conv.Tools
	toolsAt time.Time
	jobs    map[string]*Job
	order   []string
	subs    []*ipc.Subscriber
	cancels map[string]func()
	seq     int

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
		office: make(chan struct{}, 1)}
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
		Async:     map[string]bool{"formats": true, "probe": true, "paste": true, "copy": true},
	})
}

// Tools returns the detected engines, refreshed after toolsTTL.
func (s *Service) Tools() *conv.Tools {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.tools == nil || time.Since(s.toolsAt) > toolsTTL {
		s.tools, s.toolsAt = s.o.Detect(), time.Now()
	}
	return s.tools
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

func (s *Service) subscribe(sub *ipc.Subscriber) {
	s.mu.Lock()
	s.subs = append(s.subs, sub)
	for _, id := range s.order {
		sub.Send("convert.job", *s.jobs[id])
	}
	s.mu.Unlock()
	go func() {
		<-sub.StopCh()
		s.mu.Lock()
		defer s.mu.Unlock()
		for i, x := range s.subs {
			if x == sub {
				s.subs = append(s.subs[:i], s.subs[i+1:]...)
				return
			}
		}
	}()
}

// publish sends a copy of the job to every subscriber; s.mu is held.
func (s *Service) publish(j *Job) {
	for _, sub := range s.subs {
		sub.Send("convert.job", *j)
	}
}
