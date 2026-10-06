package term

import (
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
}

func newWatcher(stop <-chan struct{}, done chan struct{}, files []string, debounce time.Duration, fn func(string)) (*watcher, error) {
	fw, err := fsnotify.NewWatcher()
	if err != nil {
		return nil, err
	}
	w := &watcher{fs: fw, stop: stop, done: done, files: map[string]bool{}, debounce: debounce, fn: fn}
	for _, f := range files {
		w.files[f] = true
		// a missing directory just means nothing to follow yet
		_ = fw.Add(filepath.Dir(f))
	}
	return w, nil
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
			if !w.files[name] || ev.Op&(fsnotify.Write|fsnotify.Create|fsnotify.Rename) == 0 {
				continue
			}
			if t := timers[name]; t != nil {
				t.Stop()
			}
			timers[name] = time.AfterFunc(w.debounce, func() {
				select {
				case fire <- name:
				case <-w.stop:
				}
			})
		case name := <-fire:
			w.fn(name)
		case <-w.fs.Errors:
		}
	}
}
