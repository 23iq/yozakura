package exclusive

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

const stampLayout = "20060102-150405"

// manifest is <backup>/manifest.json.
type manifest struct {
	Created          string   `json:"created"`
	Entry            string   `json:"entry"` // hyprland.lua | hyprland.conf
	DisabledUnits    []string `json:"disabledUnits"`
	ImportedDisplays int      `json:"importedDisplays"`
	ImportedKeyboard bool     `json:"importedKeyboard"`
	Version          int      `json:"version"`
	// Units are the enabled candidates (recorded before disabling any);
	// DisabledUnits the ones Disable succeeded on.
	Units []unitRecord `json:"units"`
	// HyprMissing: ~/.config/hypr did not exist; restore removes it.
	HyprMissing bool `json:"hyprMissing,omitempty"`
	// Previous holds the config values Import overwrote.
	Previous map[string]any `json:"previous,omitempty"`
}

// createBackup copies ~/.config/hypr (an empty tree when it is missing,
// reported by missing) into a new <backups>/<stamp>/hypr and returns the
// backup dir.
func createBackup(o Options, now time.Time) (dir string, missing bool, err error) {
	root := o.backupRoot()
	if err := os.MkdirAll(root, 0o755); err != nil {
		return "", false, fmt.Errorf("backup: %w", err)
	}
	stamp := now.Format(stampLayout)
	dir = filepath.Join(root, stamp)
	for i := 1; ; i++ {
		err := os.Mkdir(dir, 0o700)
		if err == nil {
			break
		}
		if !os.IsExist(err) || i > 100 {
			return "", false, fmt.Errorf("backup: %w", err)
		}
		dir = filepath.Join(root, fmt.Sprintf("%s-%d", stamp, i))
	}
	syncDir(root)
	src := o.hyprDir()
	if _, statErr := os.Lstat(src); os.IsNotExist(statErr) {
		missing = true
		err = os.Mkdir(filepath.Join(dir, "hypr"), 0o755)
		syncDir(dir)
	} else {
		err = copyTree(src, filepath.Join(dir, "hypr"))
	}
	if err != nil {
		_ = removeTree(dir)
		return "", false, fmt.Errorf("backup %s: %w", src, err)
	}
	return dir, missing, nil
}

func writeManifest(dir string, m manifest) error {
	data, err := json.MarshalIndent(m, "", "  ")
	if err != nil {
		return err
	}
	if err := replaceFile(filepath.Join(dir, "manifest.json"), append(data, '\n'), 0o644); err != nil {
		return fmt.Errorf("write manifest: %w", err)
	}
	return nil
}

func readManifest(dir string) (manifest, error) {
	var m manifest
	data, err := os.ReadFile(filepath.Join(dir, "manifest.json"))
	if err != nil {
		return m, err
	}
	if err := json.Unmarshal(data, &m); err != nil {
		return m, fmt.Errorf("manifest: %w", err)
	}
	if m.Version != 1 {
		return m, fmt.Errorf("manifest: unsupported version %d", m.Version)
	}
	if len(m.Units) == 0 {
		// Older manifests only list the disabled names (they were stopped
		// with --now, so start them again).
		for _, n := range m.DisabledUnits {
			m.Units = append(m.Units, unitRecord{Name: n, WasActive: true, Disabled: true})
		}
	}
	if info, err := os.Lstat(filepath.Join(dir, "hypr")); err != nil || !info.IsDir() {
		return m, fmt.Errorf("backup has no hypr directory")
	}
	return m, nil
}

// latestBackup is the newest valid backup (dir names sort by time).
func latestBackup(o Options) (string, manifest, error) {
	entries, _ := os.ReadDir(o.backupRoot())
	names := []string{}
	for _, e := range entries {
		if e.IsDir() {
			names = append(names, e.Name())
		}
	}
	sort.Sort(sort.Reverse(sort.StringSlice(names)))
	for _, n := range names {
		dir := filepath.Join(o.backupRoot(), n)
		if m, err := readManifest(dir); err == nil {
			return dir, m, nil
		}
	}
	return "", manifest{}, ErrNoBackup
}

func resolveBackup(o Options, from string) (string, manifest, error) {
	if from == "" {
		return latestBackup(o)
	}
	dir := from
	if !strings.ContainsRune(from, filepath.Separator) {
		dir = filepath.Join(o.backupRoot(), from)
	}
	m, err := readManifest(dir)
	if err != nil {
		return "", m, fmt.Errorf("backup %s: %w", dir, err)
	}
	return dir, m, nil
}

// restoreTree replaces ~/.config/hypr with <dir>/hypr (or removes it when
// the backup recorded it missing). The copy is staged next to it and
// swapped in with renames, so a failed copy changes nothing. With
// keepCurrent the replaced tree is first saved as <dir>/replaced-<stamp>
// (never overwriting an earlier one) and its path returned.
func restoreTree(o Options, dir string, m manifest, now time.Time, keepCurrent bool) (string, error) {
	hypr := o.hyprDir()
	parent := filepath.Dir(hypr)
	stage := filepath.Join(parent, ".hypr."+o.appID()+"-restore")
	old := filepath.Join(parent, ".hypr."+o.appID()+"-old")
	if !m.HyprMissing {
		if err := os.MkdirAll(parent, 0o755); err != nil {
			return "", fmt.Errorf("restore: %w", err)
		}
		if err := removeTree(stage); err != nil {
			return "", fmt.Errorf("restore: %w", err)
		}
		if err := copyTree(filepath.Join(dir, "hypr"), stage); err != nil {
			_ = removeTree(stage)
			return "", fmt.Errorf("restore: %w", err)
		}
	}
	_, statErr := os.Lstat(hypr)
	exists := statErr == nil
	saved := ""
	if exists && keepCurrent {
		saved = freeName(filepath.Join(dir, "replaced-"+now.Format(stampLayout)))
		if err := copyTree(hypr, saved); err != nil {
			_ = removeTree(saved)
			_ = removeTree(stage)
			return "", fmt.Errorf("restore: save current tree: %w", err)
		}
	}
	if err := removeTree(old); err != nil {
		_ = removeTree(stage)
		return "", fmt.Errorf("restore: %w", err)
	}
	if exists {
		if err := os.Rename(hypr, old); err != nil {
			_ = removeTree(stage)
			return "", fmt.Errorf("restore: %w", err)
		}
	}
	if !m.HyprMissing {
		if err := os.Rename(stage, hypr); err != nil {
			if exists {
				_ = os.Rename(old, hypr)
			}
			_ = removeTree(stage)
			return "", fmt.Errorf("restore: %w", err)
		}
	}
	syncDir(parent)
	return saved, removeTree(old)
}
