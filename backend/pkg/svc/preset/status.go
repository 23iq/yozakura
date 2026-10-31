package preset

import (
	"encoding/json"
	"path/filepath"
	"sync"
	"time"

	"github.com/fsnotify/fsnotify"

	"yozakura/backend/pkg/catalog"
	"yozakura/backend/pkg/paths"
	"yozakura/backend/pkg/presets"
)

// AutoSaveKey turns on saving the live config into the active user preset
// as it changes (never into a built-in one).
const AutoSaveKey = "general.autoSavePreset"

// tracker keeps the active preset status (`preset.status`): it is pushed to
// subscribers whenever the live config, the presets or the active marker
// change (fsnotify, debounced), and drives the opt-in auto-save.
type tracker struct {
	manager func() (*presets.Manager, error)
	send    func(data any)

	mu       sync.Mutex
	last     string // JSON of the last pushed status
	autoSave *time.Timer
	saveWait time.Duration
}

// status computes the current status (an empty one without a manager).
func (t *tracker) status() presets.Status {
	m, err := t.manager()
	if err != nil {
		return presets.Status{Changes: []presets.Diff{}}
	}
	st, err := m.Status()
	if err != nil {
		return presets.Status{Changes: []presets.Diff{}}
	}
	return st
}

// refresh pushes the status when it changed and schedules an auto-save.
func (t *tracker) refresh() presets.Status {
	st := t.status()
	data, _ := json.Marshal(st)
	t.mu.Lock()
	changed := string(data) != t.last
	t.last = string(data)
	t.mu.Unlock()
	if changed && t.send != nil {
		t.send(st)
	}
	if t.wantsAutoSave(st) {
		t.scheduleSave()
	}
	return st
}

// wantsAutoSave: the setting is on, a user preset is active, it differs
// from the live config and no try/edit/preview owns the live config.
func (t *tracker) wantsAutoSave(st presets.Status) bool {
	if !st.Owned || st.Changed == 0 || st.Session != "" {
		return false
	}
	m, err := t.manager()
	if err != nil || m.Store == nil {
		return false
	}
	on, _, err := m.Store.Get(AutoSaveKey)
	return err == nil && on == true
}

func (t *tracker) scheduleSave() {
	t.mu.Lock()
	defer t.mu.Unlock()
	if t.autoSave != nil {
		t.autoSave.Stop()
	}
	t.autoSave = time.AfterFunc(t.saveWait, t.saveNow)
}

// saveNow stores the live config into the active user preset when that is
// still wanted (SaveCurrent re-checks under the preset lock).
func (t *tracker) saveNow() {
	if !t.wantsAutoSave(t.status()) {
		return
	}
	if m, err := t.manager(); err == nil {
		_, _, _ = m.SaveCurrent()
	}
	t.refresh()
}

// watch runs refresh after changes under the config, presets and data dirs.
func (t *tracker) watch(dirs []string, debounce time.Duration) {
	fw, err := fsnotify.NewWatcher()
	if err != nil {
		return
	}
	for _, d := range dirs {
		_ = fw.Add(d)
	}
	var timer *time.Timer
	go func() {
		defer fw.Close()
		for {
			select {
			case _, ok := <-fw.Events:
				if !ok {
					return
				}
				if timer != nil {
					timer.Stop()
				}
				timer = time.AfterFunc(debounce, func() { t.refresh() })
			case _, ok := <-fw.Errors:
				if !ok {
					return
				}
			}
		}
	}()
}

// newPresetManager builds the manager the CLI uses, for the daemon.
func newPresetManager(p *paths.Paths) (*presets.Manager, error) {
	src := paths.FindShellSource()
	cat, err := catalog.Load(src)
	if err != nil {
		return nil, err
	}
	official := ""
	if src != "" {
		official = filepath.Join(src, "assets", "presets")
	}
	return &presets.Manager{
		Cat: cat, Store: &catalog.Store{Cat: cat, File: p.Config},
		UserDir:       filepath.Join(p.ConfigDir, "presets"),
		OfficialDir:   official,
		WallpaperFile: filepath.Join(p.CacheDir, "wallpapers.json"),
		StateDir:      p.StateDir,
		DataDir:       p.DataDir,
	}, nil
}
