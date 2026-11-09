package videoproxy

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"syscall"
	"time"

	"yozakura/backend/pkg/proc"
)

// States of a Result.
const (
	// StateReady: Path is the proxy to play.
	StateReady = "ready"
	// StatePending: the proxy is being made; play the original meanwhile,
	// a Result with the final state follows through Notify.
	StatePending = "pending"
	// StateOriginal: play the original (small enough, no ffmpeg, failed).
	StateOriginal = "original"
)

// Keep is how many proxies stay cached (least recently used are removed).
const Keep = 6

// transcodeTimeout bounds one ffmpeg run.
const transcodeTimeout = 30 * time.Minute

// Request asks for the proxy of Path on a Width x Height (physical pixels)
// screen.
type Request struct {
	Path   string `json:"path"`
	Width  int    `json:"width"`
	Height int    `json:"height"`
}

// Result answers a Request.
type Result struct {
	Source string `json:"source"`
	Width  int    `json:"width"`
	Height int    `json:"height"`
	State  string `json:"state"`
	Path   string `json:"path,omitempty"`
}

// Manager makes and caches proxies. The zero value is not usable: use New.
type Manager struct {
	Dir string
	// Notify receives the final Result of every transcode started by
	// Request (ready or original). May be nil.
	Notify func(Result)

	// Seams for tests.
	lookPath func(string) (string, error)
	probe    func(ctx context.Context, path string) ([]byte, error)
	run      func(ctx context.Context, name string, args ...string) error

	ctx     context.Context
	mu      sync.Mutex
	pending map[string]bool
	failed  map[string]bool
	infos   map[string]Info
	sem     chan struct{}
}

// New returns a Manager caching proxies in dir. ctx ends running transcodes.
func New(ctx context.Context, dir string) *Manager {
	return &Manager{
		Dir:      dir,
		lookPath: exec.LookPath,
		probe: func(ctx context.Context, path string) ([]byte, error) {
			return proc.Run(ctx, "ffprobe", ProbeArgs(path)...)
		},
		run:     runTranscode,
		ctx:     ctx,
		pending: map[string]bool{},
		failed:  map[string]bool{},
		infos:   map[string]Info{},
		// One transcode at a time: they are CPU heavy and rare.
		sem: make(chan struct{}, 1),
	}
}

// runTranscode runs the encoder bound to ctx and transcodeTimeout. The
// child dies with the daemon (Pdeathsig): a restart must not leave an
// orphan encoder running for minutes, or writing next to the new one.
func runTranscode(ctx context.Context, name string, args ...string) error {
	ctx, cancel := context.WithTimeout(ctx, transcodeTimeout)
	defer cancel()
	cmd := proc.Command(ctx, name, args...)
	cmd.SysProcAttr = &syscall.SysProcAttr{Pdeathsig: syscall.SIGKILL}
	out, err := cmd.CombinedOutput()
	if err != nil {
		return &proc.Error{Name: name, Args: args, Err: err, Stderr: string(out)}
	}
	return nil
}

func (m *Manager) available() bool {
	for _, bin := range []string{"ffmpeg", "ffprobe"} {
		if _, err := m.lookPath(bin); err != nil {
			return false
		}
	}
	return true
}

// identity changes whenever the source file does.
func identity(path string, fi os.FileInfo) string {
	return fmt.Sprintf("%s\x00%d\x00%d", path, fi.Size(), fi.ModTime().UnixNano())
}

// Key names the proxy file of a source identity and plan.
func Key(id string, p Plan) string {
	sum := sha256.Sum256([]byte(fmt.Sprintf("v%d\x00%s\x00%dx%d@%s", formatVersion, id, p.Width, p.Height, p.Rate)))
	return hex.EncodeToString(sum[:])[:20]
}

// Request returns the proxy state for r, starting a transcode when needed.
func (m *Manager) Request(r Request) Result {
	res := Result{Source: r.Path, Width: r.Width, Height: r.Height, State: StateOriginal}
	if !filepath.IsAbs(r.Path) || r.Width <= 0 || r.Height <= 0 || !m.available() {
		return res
	}
	fi, err := os.Stat(r.Path)
	if err != nil || fi.IsDir() {
		return res
	}
	id := identity(r.Path, fi)
	info, err := m.info(id, r.Path)
	if err != nil {
		return res
	}
	plan, needed := PlanFor(info, r.Width, r.Height)
	if !needed {
		return res
	}
	key := Key(id, plan)
	dst := filepath.Join(m.Dir, key+".mp4")
	if _, err := os.Stat(dst); err == nil {
		now := time.Now()
		_ = os.Chtimes(dst, now, now) // most recently used
		res.State, res.Path = StateReady, dst
		return res
	}

	m.mu.Lock()
	defer m.mu.Unlock()
	if m.failed[key] {
		return res
	}
	res.State = StatePending
	if m.pending[key] {
		return res
	}
	m.pending[key] = true
	go m.transcode(key, r, plan, dst)
	return res
}

func (m *Manager) info(id, path string) (Info, error) {
	m.mu.Lock()
	info, ok := m.infos[id]
	m.mu.Unlock()
	if ok {
		return info, nil
	}
	out, err := m.probe(m.ctx, path)
	if err != nil {
		return Info{}, err
	}
	info, err = ParseProbe(out)
	if err != nil {
		return Info{}, err
	}
	m.mu.Lock()
	m.infos[id] = info
	m.mu.Unlock()
	return info, nil
}

func (m *Manager) transcode(key string, r Request, plan Plan, dst string) {
	m.sem <- struct{}{}
	err := m.make(r.Path, dst, plan)
	<-m.sem

	res := Result{Source: r.Path, Width: r.Width, Height: r.Height, State: StateReady, Path: dst}
	m.mu.Lock()
	delete(m.pending, key)
	if err != nil {
		m.failed[key] = true
		res.State, res.Path = StateOriginal, ""
	}
	m.mu.Unlock()
	if err != nil {
		log.Printf("[videoproxy] %s: %v", r.Path, err)
	} else {
		log.Printf("[videoproxy] %s -> %s (%dx%d @ %s fps)", r.Path, dst, plan.Width, plan.Height, plan.Rate)
		m.prune(dst)
	}
	if m.Notify != nil {
		m.Notify(res)
	}
}

// make writes the proxy next to dst and renames it into place, so a
// partial file is never played. ffmpeg runs at the lowest priority.
func (m *Manager) make(src, dst string, plan Plan) error {
	if err := os.MkdirAll(m.Dir, 0o755); err != nil {
		return err
	}
	m.removeStaleParts()
	// Per process: an encoder of an earlier daemon never shares the file.
	tmp := fmt.Sprintf("%s.%d.part", dst, os.Getpid())
	defer os.Remove(tmp)
	args := Args(src, tmp, plan)
	name := "ffmpeg"
	if _, err := m.lookPath("nice"); err == nil {
		args = append([]string{"-n", "19", "ffmpeg"}, args...)
		name = "nice"
	}
	if err := m.run(m.ctx, name, args...); err != nil {
		return err
	}
	return os.Rename(tmp, dst)
}

// removeStaleParts deletes partial files left by a daemon that died
// mid-transcode (older than any running job can be).
func (m *Manager) removeStaleParts() {
	entries, err := os.ReadDir(m.Dir)
	if err != nil {
		return
	}
	for _, e := range entries {
		if !strings.HasSuffix(e.Name(), ".part") {
			continue
		}
		if fi, err := e.Info(); err == nil && time.Since(fi.ModTime()) > transcodeTimeout {
			_ = os.Remove(filepath.Join(m.Dir, e.Name()))
		}
	}
}

// prune keeps the Keep most recently used proxies (always `keep`).
func (m *Manager) prune(keep string) {
	entries, err := os.ReadDir(m.Dir)
	if err != nil {
		return
	}
	type file struct {
		path string
		mod  time.Time
	}
	var files []file
	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".mp4") {
			continue
		}
		fi, err := e.Info()
		if err != nil {
			continue
		}
		files = append(files, file{filepath.Join(m.Dir, e.Name()), fi.ModTime()})
	}
	sort.Slice(files, func(i, j int) bool { return files[i].mod.After(files[j].mod) })
	kept := 0
	for _, f := range files {
		if f.path == keep || kept < Keep-1 {
			if f.path != keep {
				kept++
			}
			continue
		}
		_ = os.Remove(f.path)
	}
}
