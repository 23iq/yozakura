package routines

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"

	"yozakura/backend/pkg/fsutil"
	"yozakura/backend/pkg/paths"
)

// FileName is the routines file under the app config dir.
const FileName = "routines.json"

// DefaultPath is ~/.config/<app>/routines.json.
func DefaultPath() string { return filepath.Join(paths.New().ConfigDir, FileName) }

// Load reads the routines; a missing file is an empty list.
func Load(path string) ([]Routine, error) {
	data, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return []Routine{}, nil
	}
	if err != nil {
		return []Routine{}, err
	}
	var f File
	if err := json.Unmarshal(data, &f); err != nil {
		return []Routine{}, fmt.Errorf("%s: %v", path, err)
	}
	if f.Routines == nil {
		f.Routines = []Routine{}
	}
	for i := range f.Routines {
		if f.Routines[i].Steps == nil {
			f.Routines[i].Steps = []Step{}
		}
	}
	return f.Routines, nil
}

// Save writes the routines atomically.
func Save(path string, list []Routine) error {
	if list == nil {
		list = []Routine{}
	}
	data, err := json.MarshalIndent(File{Routines: list}, "", "  ")
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	return fsutil.WriteFile(path, append(data, '\n'), 0o644)
}
