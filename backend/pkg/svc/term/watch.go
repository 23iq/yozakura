package term

import (
	"os"
	"path/filepath"
	"time"

	"github.com/fsnotify/fsnotify"
)

// watcher reports changes of a few files, debounced per file. It watches
// the parent directories, so atomic replacement (rename) is seen too.
type watcher struct {
	fs       *fsnotify.Watcher
	stop     <-chan struct{}
	done     chan struct{}
	files    map[string]bool
	debounce time.Duration
	fn       func(file string)
	pending  map[string]bool // wanted directories that did not exist yet
}

func newWatcher(stop <-chan struct{}, done chan struct{}, files []string, debounce time.Duration, fn func(string)) (*watcher, error) {
	fw, err := fsnotify.NewWatcher()
	if err != nil {
		return nil, err
	}
	w := &watcher{fs: fw, stop: stop, done: done, files: map[string]bool{}, debounce: debounce, fn: fn, pending: map[string]bool{}}
	for _, f := range files {
		w.files[f] = true
		w.watchDir(filepath.Dir(f))
	}
	return w, nil
}

// watchDir watches dir; when it does not exist yet, the nearest existing
// ancestor is watched instead and dir is retried when something appears.
func (w *watcher) watchDir(dir string) {
	if w.fs.Add(dir) == nil {
		delete(w.pending, dir)
		return
	}
	w.pending[dir] = true
	for up := filepath.Dir(dir); up != dir; up, dir = filepath.Dir(up), up {
		if w.fs.Add(up) == nil {
			return
		}
	}
}

// retryPending re-adds the missing directories and reports their files that
// already exist, so a colors.json created with its directory is not missed.
func (w *watcher) retryPending(fire func(string)) {
	for dir := range w.pending {
		if w.fs.Add(dir) != nil {
			continue
		}
		delete(w.pending, dir)
		for f := range w.files {
			if filepath.Dir(f) == dir {
				if _, err := os.Stat(f); err == nil {
					fire(f)
				}
			}
		}
	}
}

func (w *watcher) run() {
	defer close(w.done)
	defer w.fs.Close()
	timers := map[string]*time.Timer{}
	fire := make(chan string, 8)
	for {
		select {
		case <-w.stop:
			for _, t := range timers {
				t.Stop()
			}
			return
		case ev, ok := <-w.fs.Events:
			if !ok {
				return
			}
			name := filepath.Clean(ev.Name)
			schedule := func(name string) {
				if t := timers[name]; t != nil {
					t.Stop()
				}
				timers[name] = time.AfterFunc(w.debounce, func() {
					select {
					case fire <- name:
					case <-w.stop:
					}
				})
			}
			if ev.Op&fsnotify.Create != 0 && len(w.pending) > 0 {
				w.retryPending(schedule)
			}
			if !w.files[name] || ev.Op&(fsnotify.Write|fsnotify.Create|fsnotify.Rename) == 0 {
				continue
			}
			schedule(name)
		case name := <-fire:
			delete(timers, name)
			w.fn(name)
		case <-w.fs.Errors:
		}
	}
}
