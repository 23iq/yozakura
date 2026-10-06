package exclusive

import (
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"time"
)

// copyTree copies src to the new dir dst keeping symlinks as symlinks and
// file/dir permissions and mtimes; every file is fsynced, then every dir.
// Special files (fifos, sockets, devices) are an error: the copy must be
// complete. Hard links become independent copies. Dir modes are applied
// last so read-only dirs can be filled.
func copyTree(src, dst string) error {
	type dirMeta struct {
		path string
		mode fs.FileMode
		mod  time.Time
	}
	var dirs []dirMeta
	err := filepath.WalkDir(src, func(p string, _ fs.DirEntry, err error) error {
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
		return fmt.Errorf("cannot copy special file %s (%s)", p, info.Mode().Type())
	})
	if err != nil {
		return err
	}
	for i := len(dirs) - 1; i >= 0; i-- {
		syncDir(dirs[i].path)
		if err := os.Chmod(dirs[i].path, dirs[i].mode); err != nil {
			return err
		}
		_ = os.Chtimes(dirs[i].path, dirs[i].mod, dirs[i].mod)
	}
	syncDir(filepath.Dir(dst))
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
	if err := out.Sync(); err != nil {
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

// writeFileSync writes and fsyncs a new or truncated file.
func writeFileSync(path string, data []byte, perm fs.FileMode) error {
	f, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, perm)
	if err != nil {
		return err
	}
	if _, err := f.Write(data); err != nil {
		f.Close()
		return err
	}
	if err := f.Sync(); err != nil {
		f.Close()
		return err
	}
	return f.Close()
}

// replaceFile atomically puts data at path: fsynced temp file, rename (a
// symlink at path is replaced, never written through), fsynced dir.
func replaceFile(path string, data []byte, perm fs.FileMode) error {
	tmp := filepath.Join(filepath.Dir(path), "."+filepath.Base(path)+".exclusive-tmp")
	if err := writeFileSync(tmp, data, perm); err != nil {
		os.Remove(tmp)
		return err
	}
	if err := os.Rename(tmp, path); err != nil {
		os.Remove(tmp)
		return err
	}
	syncDir(filepath.Dir(path))
	return nil
}

// syncDir flushes a directory's entries (best effort).
func syncDir(dir string) {
	if d, err := os.Open(dir); err == nil {
		_ = d.Sync()
		d.Close()
	}
}

// removeTree removes path like os.RemoveAll, first making its dirs
// writable so read-only dirs (copied with their modes) can be emptied.
// Symlinks are never followed.
func removeTree(path string) error {
	if _, err := os.Lstat(path); os.IsNotExist(err) {
		return nil
	}
	_ = filepath.WalkDir(path, func(p string, d fs.DirEntry, err error) error {
		if err == nil && d.IsDir() {
			if info, err := d.Info(); err == nil {
				_ = os.Chmod(p, info.Mode().Perm()|0o700)
			}
		}
		return nil
	})
	return os.RemoveAll(path)
}

// freeName returns base, or base-N for the first N that does not exist.
func freeName(base string) string {
	name := base
	for i := 1; ; i++ {
		if _, err := os.Lstat(name); os.IsNotExist(err) {
			return name
		}
		name = fmt.Sprintf("%s-%d", base, i)
	}
}
