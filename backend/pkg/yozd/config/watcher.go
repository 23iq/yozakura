package config

import (
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/fsnotify/fsnotify"
)

// ConfigWatcher watches config files for changes and triggers reloads.
//
// It watches the directories of the config and its includes, not the files:
// a file that does not exist yet (yozd starts before the shell writes the
// TOML on a first run) or is replaced by a rename is still seen.
type ConfigWatcher struct {
	watcher    *fsnotify.Watcher
	configPath string
	callback   func(*TOMLConfig)
	watched    map[string]bool // config files (clean paths)
	dirs       map[string]bool // their directories, the fsnotify watches
	mu         sync.Mutex
	done       chan struct{}
}

// LoadAndWatch applies the config at path when it exists and watches it:
// apply runs again on every change, and once the file is created when it
// does not exist yet. The watch starts first, so a file written while the
// initial load runs is not missed; apply calls never overlap. The watcher
// is nil when fsnotify is unavailable (the initial load still runs).
func LoadAndWatch(path string, apply func(*TOMLConfig)) *ConfigWatcher {
	var mu sync.Mutex
	serial := func(cfg *TOMLConfig) {
		mu.Lock()
		defer mu.Unlock()
		apply(cfg)
	}
	w, err := NewConfigWatcher()
	if err != nil {
		fmt.Printf("%s Warning: could not start watcher: %v\n", logPrefix, err)
		w = nil
	} else {
		w.Start(path, func(cfg *TOMLConfig) {
			fmt.Println(logPrefix, "Config changed, reloading...")
			serial(cfg)
		})
	}
	if _, err := os.Stat(path); err != nil {
		fmt.Printf("%s No config file at %s yet, waiting for it\n", logPrefix, path)
		return w
	}
	if cfg, err := LoadConfig(path); err != nil {
		fmt.Printf("%s Error loading config: %v\n", logPrefix, err)
	} else {
		fmt.Printf("%s Loaded config from %s\n", logPrefix, path)
		serial(cfg)
	}
	return w
}

// NewConfigWatcher creates a new config file watcher.
func NewConfigWatcher() (*ConfigWatcher, error) {
	w, err := fsnotify.NewWatcher()
	if err != nil {
		return nil, fmt.Errorf("creating fsnotify watcher: %w", err)
	}
	return &ConfigWatcher{
		watcher: w,
		watched: make(map[string]bool),
		dirs:    make(map[string]bool),
		done:    make(chan struct{}),
	}, nil
}

// Start begins watching the config file at path and calls callback on changes.
func (cw *ConfigWatcher) Start(path string, callback func(*TOMLConfig)) {
	cw.configPath = path
	cw.callback = callback

	// Watch the main config and all includes
	cw.updateWatchedFiles()

	go cw.loop()
}

// Stop stops the config watcher and releases resources.
func (cw *ConfigWatcher) Stop() {
	close(cw.done)
	cw.watcher.Close()
}

func (cw *ConfigWatcher) loop() {
	var debounceTimer *time.Timer

	for {
		select {
		case <-cw.done:
			if debounceTimer != nil {
				debounceTimer.Stop()
			}
			return

		case event, ok := <-cw.watcher.Events:
			if !ok {
				return
			}
			// The directory watches see every file next to the config.
			if !cw.isWatched(event.Name) {
				continue
			}

			// fsnotify delivers IN_IGNORED implicitly when a watch
			// descriptor becomes invalid — typical after the kernel
			// reaps the inode following a rename or unlink, and for
			// atomic-write patterns that put a new file in the same
			// path. IN_IGNORED surfaces as fsnotify.Remove (Chmod
			// events sometimes arrive here too on some kernels).
			//
			// Without re-adding the watch on these events, every
			// subsequent change to the file is silently dropped.
			if event.Op&fsnotify.Remove != 0 {
				fmt.Printf("%s Watch invalidated for %s (%s), re-registering\n", logPrefix, event.Name, event.Op)
				cw.updateWatchedFiles()
				// The change that invalidated the watch is itself a
				// reason to reload — don't lose it just because the
				// new watch hasn't caught the next event yet.
				if debounceTimer != nil {
					debounceTimer.Stop()
				}
				debounceTimer = time.AfterFunc(200*time.Millisecond, func() {
					cw.reload()
				})
				continue
			}

			// React to writes, creates, and renames.
			if event.Op&(fsnotify.Write|fsnotify.Create|fsnotify.Rename) == 0 {
				continue
			}

			// Debounce: reset timer on each event
			if debounceTimer != nil {
				debounceTimer.Stop()
			}
			debounceTimer = time.AfterFunc(200*time.Millisecond, func() {
				cw.reload()
			})

		case err, ok := <-cw.watcher.Errors:
			if !ok {
				return
			}
			fmt.Printf("%s Watcher error: %v\n", logPrefix, err)
		}
	}
}

func (cw *ConfigWatcher) reload() {
	cfg, err := LoadConfig(cw.configPath)
	if err != nil {
		fmt.Printf("%s Error reloading config: %v\n", logPrefix, err)
		return
	}

	fmt.Printf("%s Config reloaded from %s\n", logPrefix, cw.configPath)

	// Update watched files in case includes changed
	cw.updateWatchedFiles()

	if cw.callback != nil {
		cw.callback(cfg)
	}
}

func (cw *ConfigWatcher) isWatched(name string) bool {
	cw.mu.Lock()
	defer cw.mu.Unlock()
	return cw.watched[filepath.Clean(name)]
}

func (cw *ConfigWatcher) updateWatchedFiles() {
	cw.mu.Lock()
	defer cw.mu.Unlock()

	newWatched := make(map[string]bool)
	newDirs := make(map[string]bool)
	for _, p := range ResolveIncludePaths(cw.configPath) {
		if abs, err := filepath.Abs(p); err == nil {
			p = abs
		}
		p = filepath.Clean(p)
		newWatched[p] = true
		dir := filepath.Dir(p)
		if newDirs[dir] {
			continue
		}
		newDirs[dir] = true
		// Always (re)add the watch: fsnotify.Add is cheap on an
		// already-watched path, so this also self-heals after a missed
		// event or a directory created since.
		if err := cw.watcher.Add(dir); err != nil {
			fmt.Printf("%s Warning: cannot watch %s: %v\n", logPrefix, dir, err)
		}
	}

	// Remove watches of directories no longer holding a config file
	for d := range cw.dirs {
		if !newDirs[d] {
			cw.watcher.Remove(d)
		}
	}

	cw.watched, cw.dirs = newWatched, newDirs
}
