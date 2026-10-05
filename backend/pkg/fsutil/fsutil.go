// Package fsutil holds the file helpers every writer of user files shares:
// crash-safe atomic replacement that respects symlinked dotfiles, and
// advisory locks serialising multi-file operations between processes.
package fsutil

import (
	"os"
	"path/filepath"
)

// maxLinks bounds symlink resolution (loops).
const maxLinks = 40

// Resolve follows path's symlinks (also a dangling final link, so a write
// creates the link's target) and returns the real file to write.
func Resolve(path string) (string, error) {
	for i := 0; i < maxLinks; i++ {
		st, err := os.Lstat(path)
		if err != nil || st.Mode()&os.ModeSymlink == 0 {
			if dir, derr := filepath.EvalSymlinks(filepath.Dir(path)); derr == nil {
				return filepath.Join(dir, filepath.Base(path)), nil
			}
			return path, nil
		}
		target, err := os.Readlink(path)
		if err != nil {
			return "", err
		}
		if !filepath.IsAbs(target) {
			target = filepath.Join(filepath.Dir(path), target)
		}
		path = target
	}
	return "", &os.PathError{Op: "resolve", Path: path, Err: os.ErrInvalid}
}

// WriteFile atomically replaces path with data: a unique temp file next to
// the real target (symlinks are followed, never replaced), fsync, rename,
// fsync of the directory. An existing file keeps its permissions; a new
// one gets perm.
func WriteFile(path string, data []byte, perm os.FileMode) error {
	real, err := Resolve(path)
	if err != nil {
		return err
	}
	dir := filepath.Dir(real)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}
	if st, err := os.Stat(real); err == nil {
		perm = st.Mode().Perm()
	}
	tmp, err := os.CreateTemp(dir, "."+filepath.Base(real)+".tmp-*")
	if err != nil {
		return err
	}
	name := tmp.Name()
	ok := false
	defer func() {
		if !ok {
			_ = os.Remove(name)
		}
	}()
	if err := tmp.Chmod(perm); err != nil {
		tmp.Close()
		return err
	}
	if _, err := tmp.Write(data); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Sync(); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	if err := os.Rename(name, real); err != nil {
		return err
	}
	ok = true
	syncDir(dir)
	return nil
}

// syncDir flushes a directory entry change (best effort).
func syncDir(dir string) {
	if d, err := os.Open(dir); err == nil {
		_ = d.Sync()
		d.Close()
	}
}
