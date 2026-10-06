package displays

import (
	"fmt"
	"path/filepath"
	"strings"
	"syscall"

	"yozakura/backend/pkg/fsutil"
	"yozakura/backend/pkg/yozd/ipc"
)

// MoveConflicts comments out every importable conflict (so a second run
// finds nothing to move) and returns the parsed configs for import. A rule
// is skipped, with a Reason, when it cannot be imported losslessly or its
// file must not be rewritten (a link into /nix/store, a file outside home,
// a read-only file). A file whose write fails has all its rules skipped and
// the walk goes on: Moved and Outputs only list rules that really changed.
func MoveConflicts(hyprDir, dataDir, home string) (MoveResult, error) {
	res := MoveResult{Outputs: []ipc.OutputConfig{}, Moved: []Conflict{}, Skipped: []Conflict{}}
	err := WalkConfigs(hyprDir, dataDir, func(path string, lua bool, lines []string) error {
		idx := conflictLines(lines, lua)
		if len(idx) == 0 {
			return nil
		}
		skipAll := func(reason string) {
			for _, n := range idx {
				res.Skipped = append(res.Skipped, Conflict{File: path, Line: n + 1, Text: strings.TrimSpace(lines[n]), Reason: reason})
			}
		}
		if reason := unwritable(path, home); reason != "" {
			skipAll(reason)
			return nil
		}
		orig := append([]string(nil), lines...)
		var moved []Conflict
		var outs []ipc.OutputConfig
		var skipped []Conflict
		for _, n := range idx {
			c := Conflict{File: path, Line: n + 1, Text: strings.TrimSpace(lines[n])}
			cfg, err := ParseMonitorLine(lines[n], lua)
			if err != nil {
				c.Reason = err.Error()
				skipped = append(skipped, c)
				continue
			}
			lines[n] = movedPrefix(lua) + lines[n]
			moved = append(moved, c)
			outs = append(outs, cfg)
		}
		if len(moved) > 0 {
			if err := fsutil.WriteFile(path, []byte(strings.Join(lines, "\n")), 0o644); err != nil {
				lines = orig
				skipAll("write failed: " + err.Error())
				return nil
			}
		}
		res.Moved = append(res.Moved, moved...)
		res.Outputs = append(res.Outputs, outs...)
		res.Skipped = append(res.Skipped, skipped...)
		return nil
	})
	return res, err
}

// unwritable says why path (through its links) must not be rewritten, or "".
func unwritable(path, home string) string {
	real, err := fsutil.Resolve(path)
	if err != nil {
		return "unresolvable link: " + err.Error()
	}
	if r, err := filepath.EvalSymlinks(real); err == nil {
		real = r
	}
	switch {
	case within(real, "/nix/store"):
		return "read-only: link into /nix/store"
	case home != "" && !within(real, home) && !within(real, evalOr(home)):
		return fmt.Sprintf("outside home: %s", real)
	case syscall.Access(real, 2) != nil || syscall.Access(filepath.Dir(real), 2) != nil: // W_OK
		return "not writable: " + real
	}
	return ""
}

func evalOr(p string) string {
	if r, err := filepath.EvalSymlinks(p); err == nil {
		return r
	}
	return p
}
