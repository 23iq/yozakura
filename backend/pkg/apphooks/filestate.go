package apphooks

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"sync"

	"yozakura/backend/pkg/fsutil"
)

// Apply remembers what it created (a file that did not exist, a JSON key the
// user did not have) in a small sidecar so Revert can give the user's
// pre-existing file back byte for byte and only delete what we made.
var stateMu sync.Mutex

func stateFile(env Env) string { return filepath.Join(env.DataDir, "apphooks-state.json") }

// loadMarks reads the sidecar, moving a copy an earlier version left in the
// cache dir over once.
func loadMarks(env Env) map[string]bool {
	marks := map[string]bool{}
	data, err := os.ReadFile(stateFile(env))
	if err != nil && env.CacheDir != "" {
		old := filepath.Join(env.CacheDir, "apphooks-state.json")
		if od, oerr := os.ReadFile(old); oerr == nil {
			if _ = os.MkdirAll(env.DataDir, 0o755); fsutil.WriteFile(stateFile(env), od, 0o644) == nil {
				_ = os.Remove(old)
			}
			data, err = od, nil
		}
	}
	if err == nil {
		_ = json.Unmarshal(data, &marks)
	}
	return marks
}

func hasMark(env Env, key string) bool {
	if env.DataDir == "" {
		return false
	}
	stateMu.Lock()
	defer stateMu.Unlock()
	return loadMarks(env)[key]
}

func setMark(env Env, key string, on bool) {
	if env.DataDir == "" {
		return
	}
	stateMu.Lock()
	defer stateMu.Unlock()
	marks := loadMarks(env)
	if marks[key] == on {
		return
	}
	if on {
		marks[key] = true
	} else {
		delete(marks, key)
	}
	if len(marks) == 0 {
		_ = os.Remove(stateFile(env))
		return
	}
	data, _ := json.MarshalIndent(marks, "", "  ")
	_ = os.MkdirAll(env.DataDir, 0o755)
	_ = fsutil.WriteFile(stateFile(env), data, 0o644)
}

func createdKey(id, path string) string { return "created:" + id + ":" + path }

// removeFile deletes the real file behind path (symlinks resolved first, so a
// link is never what disappears) unless it is managed elsewhere.
func removeFile(path string) error {
	if err := checkWritable(path); err != nil {
		return err
	}
	real, err := fsutil.Resolve(path)
	if err != nil {
		return err
	}
	if err := os.Remove(real); err != nil && !errors.Is(err, os.ErrNotExist) {
		return err
	}
	return nil
}

// writeBlockFile writes out (content with our block) to path, recording
// whether Apply created the file.
func writeBlockFile(env Env, id, path string, existed bool, out string) error {
	if err := WriteFileSafe(path, []byte(out)); err != nil {
		return err
	}
	setMark(env, createdKey(id, path), !existed) // a stale mark must not survive
	return nil
}

// revertBlockFile removes our block from path. The file is deleted only when
// Apply created it and nothing else is left in it; otherwise it is rewritten
// without the block. It reports whether the file changed.
func revertBlockFile(env Env, id, path string) (bool, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		setMark(env, createdKey(id, path), false)
		return false, nil
	}
	out, changed := RemoveBlock(string(data), env.AppID)
	if !changed {
		setMark(env, createdKey(id, path), false) // nothing of ours left
		return false, nil
	}
	if isManaged(path) {
		return false, ErrManaged
	}
	key := createdKey(id, path)
	if strings.TrimSpace(out) == "" && hasMark(env, key) {
		err = removeFile(path)
	} else {
		err = WriteFileSafe(path, []byte(out))
	}
	if err != nil {
		return false, err
	}
	setMark(env, key, false)
	return true, nil
}
