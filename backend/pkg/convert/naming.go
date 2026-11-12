package convert

import (
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
)

// maxNameTries bounds the " (n)" suffix search.
const maxNameTries = 10000

// OutputName is the file name of src converted to ext: "photo.jpg" ->
// "photo.png" (a dotfile or a name without extension keeps its name).
func OutputName(src, ext string) string {
	base := filepath.Base(src)
	if e := filepath.Ext(base); e != "" && e != base {
		base = strings.TrimSuffix(base, e)
	}
	return base + "." + ext
}

// Reserve claims a free output path for src converted to ext in dir (the
// source's directory when dir is ""): the plain name, else "name (1).ext",
// "name (2).ext"... It creates the file empty (O_EXCL), so two conversions
// never pick the same name and nothing existing is ever overwritten; the
// caller renames the finished result over it, or removes it on failure.
func Reserve(src, ext, dir string) (string, error) {
	if dir == "" {
		dir = filepath.Dir(src)
	}
	name := OutputName(src, ext)
	stem := strings.TrimSuffix(name, "."+ext)
	for i := 0; i < maxNameTries; i++ {
		cand := name
		if i > 0 {
			cand = fmt.Sprintf("%s (%d).%s", stem, i, ext)
		}
		path := filepath.Join(dir, cand)
		f, err := os.OpenFile(path, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0o644)
		if err == nil {
			f.Close()
			return path, nil
		}
		if !errors.Is(err, fs.ErrExist) {
			return "", fmt.Errorf("cannot write to %s", dir)
		}
	}
	return "", fmt.Errorf("no free name for %s in %s", name, dir)
}
