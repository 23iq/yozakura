package exclusive

import (
	"encoding/json"
	"fmt"
	"io"
	"io/fs"
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
}

// createBackup copies ~/.config/hypr (an empty tree when it is missing)
// into a new <backups>/<stamp>/hypr and returns the backup dir.
func createBackup(o Options) (string, error) {
	root := o.backupRoot()
	if err := os.MkdirAll(root, 0o755); err != nil {
		return "", fmt.Errorf("backup: %w", err)
	}
	stamp := o.now().Format(stampLayout)
	dir := filepath.Join(root, stamp)
	for i := 1; ; i++ {
		err := os.Mkdir(dir, 0o700)
		if err == nil {
			break
		}
		if !os.IsExist(err) || i > 100 {
			return "", fmt.Errorf("backup: %w", err)
		}
		dir = filepath.Join(root, fmt.Sprintf("%s-%d", stamp, i))
	}
	src := o.hyprDir()
	var err error
	if _, statErr := os.Lstat(src); os.IsNotExist(statErr) {
		err = os.Mkdir(filepath.Join(dir, "hypr"), 0o755)
	} else {
		err = copyTree(src, filepath.Join(dir, "hypr"))
	}
	if err != nil {
		os.RemoveAll(dir)
		return "", fmt.Errorf("backup %s: %w", src, err)
	}
	return dir, nil
}

func writeManifest(dir string, m manifest) error {
	data, err := json.MarshalIndent(m, "", "  ")
	if err != nil {
		return err
	}
	tmp := filepath.Join(dir, ".manifest.json.tmp")
	if err := os.WriteFile(tmp, append(data, '\n'), 0o644); err != nil {
		return fmt.Errorf("write manifest: %w", err)
	}
	return os.Rename(tmp, filepath.Join(dir, "manifest.json"))
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

// restoreTree replaces ~/.config/hypr with <dir>/hypr. The copy is staged
// next to it and swapped in with renames, so a failed copy changes nothing.
// With keepCurrent the replaced tree is first saved as
// <dir>/replaced-<stamp>/ (edits made while exclusive are not lost).
func restoreTree(o Options, dir string, keepCurrent bool) error {
	hypr := o.hyprDir()
	parent := filepath.Dir(hypr)
	stage := filepath.Join(parent, ".hypr."+o.appID()+"-restore")
	old := filepath.Join(parent, ".hypr."+o.appID()+"-old")
	os.RemoveAll(stage)
	if err := copyTree(filepath.Join(dir, "hypr"), stage); err != nil {
		os.RemoveAll(stage)
		return fmt.Errorf("restore: %w", err)
	}
	_, statErr := os.Lstat(hypr)
	exists := statErr == nil
	if exists && keepCurrent {
		saved := filepath.Join(dir, "replaced-"+o.now().Format(stampLayout))
		os.RemoveAll(saved)
		if err := copyTree(hypr, saved); err != nil {
			os.RemoveAll(stage)
			return fmt.Errorf("restore: save current tree: %w", err)
		}
	}
	os.RemoveAll(old)
	if exists {
		if err := os.Rename(hypr, old); err != nil {
			os.RemoveAll(stage)
			return fmt.Errorf("restore: %w", err)
		}
	}
	if err := os.Rename(stage, hypr); err != nil {
		if exists {
			os.Rename(old, hypr)
		}
		os.RemoveAll(stage)
		return fmt.Errorf("restore: %w", err)
	}
	return os.RemoveAll(old)
}

// copyTree copies src to the new dir dst keeping symlinks as symlinks and
// file/dir permissions and mtimes. Special files (sockets, fifos) are
// skipped. Dir modes are applied last so read-only dirs can be filled.
func copyTree(src, dst string) error {
	type dirMeta struct {
		path string
		mode fs.FileMode
		mod  time.Time
	}
	var dirs []dirMeta
	err := filepath.WalkDir(src, func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel, err := filepath.Rel(src, p)
		if err != nil {
			return err
		}
		target := filepath.Join(dst, rel)
		info, err := os.Lstat(p)
		if err != nil {
			return err
		}
		switch {
		case info.Mode()&os.ModeSymlink != 0:
			link, err := os.Readlink(p)
			if err != nil {
				return err
			}
			return os.Symlink(link, target)
		case info.IsDir():
			if err := os.Mkdir(target, 0o700); err != nil {
				return err
			}
			dirs = append(dirs, dirMeta{target, info.Mode().Perm(), info.ModTime()})
			return nil
		case info.Mode().IsRegular():
			return copyFile(p, target, info)
		}
		return nil
	})
	if err != nil {
		return err
	}
	for i := len(dirs) - 1; i >= 0; i-- {
		if err := os.Chmod(dirs[i].path, dirs[i].mode); err != nil {
			return err
		}
		_ = os.Chtimes(dirs[i].path, dirs[i].mod, dirs[i].mod)
	}
	return nil
}

func copyFile(src, dst string, info fs.FileInfo) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	out, err := os.OpenFile(dst, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0o600)
	if err != nil {
		return err
	}
	if _, err := io.Copy(out, in); err != nil {
		out.Close()
		return err
	}
	if err := out.Close(); err != nil {
		return err
	}
	if err := os.Chmod(dst, info.Mode().Perm()); err != nil {
		return err
	}
	return os.Chtimes(dst, info.ModTime(), info.ModTime())
}
