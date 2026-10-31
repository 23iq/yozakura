package tasks

import (
	"log"
	"os"
	"path/filepath"
	"strings"
	"yozakura/backend/pkg/fsutil"
)

// On-disk layout (dir = ~/.local/share/<app>/tasks):
//   <task id>.json   one Task each
//   projects.json    {dir: Project}
//   settings.json    Settings

type store struct{ dir string }

func (s store) taskPath(id string) string { return filepath.Join(s.dir, id+".json") }

func (s store) loadTasks() []*Task {
	entries, err := os.ReadDir(s.dir)
	if err != nil {
		return nil
	}
	var out []*Task
	for _, e := range entries {
		name := e.Name()
		if e.IsDir() || !strings.HasPrefix(name, "k") || !strings.HasSuffix(name, ".json") {
			continue
		}
		var t Task
		if err := readJSON(filepath.Join(s.dir, name), &t); err != nil || t.ID == "" {
			log.Printf("[tasks] %s: %v", name, err)
			continue
		}
		out = append(out, &t)
	}
	return out
}

func (s store) saveTask(t *Task) {
	if err := writeJSON(s.taskPath(t.ID), t); err != nil {
		log.Printf("[tasks] save %s: %v", t.ID, err)
	}
}

func (s store) deleteTask(id string) { _ = os.Remove(s.taskPath(id)) }

func (s store) loadProjects() map[string]Project {
	out := map[string]Project{}
	_ = readJSON(filepath.Join(s.dir, "projects.json"), &out)
	return out
}

func (s store) saveProjects(p map[string]Project) {
	if err := writeJSON(filepath.Join(s.dir, "projects.json"), p); err != nil {
		log.Printf("[tasks] save projects: %v", err)
	}
}

func (s store) loadSettings() Settings {
	var st Settings
	_ = readJSON(filepath.Join(s.dir, "settings.json"), &st)
	return st
}

func (s store) saveSettings(st Settings) {
	if err := writeJSON(filepath.Join(s.dir, "settings.json"), st); err != nil {
		log.Printf("[tasks] save settings: %v", err)
	}
}

func readJSON(path string, v any) error { return fsutil.ReadJSON(path, v) }

func writeJSON(path string, v any) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	return fsutil.WriteJSON(path, v, 0o600)
}
