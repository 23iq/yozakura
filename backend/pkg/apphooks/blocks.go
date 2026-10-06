package apphooks

import (
	"errors"
	"os"
	"path/filepath"
	"strings"
	"syscall"

	"yozakura/backend/pkg/fsutil"
)

// ErrManaged marks a file we must not write: it lives in the Nix store or
// is read-only (managed by a dotfile manager).
var ErrManaged = errors.New("file is managed elsewhere (read-only or Nix store)")

// BlockMarkers returns the conf-style marker lines for an app id.
func BlockMarkers(id string) (start, end string) {
	return "# >>> " + id + " >>>", "# <<< " + id + " <<<"
}

// findBlock locates the marked block: s is the start of the start-marker
// line, e the index after the end-marker line (and its newline).
func findBlock(content, marker string) (s, e int, ok bool) {
	start, end := BlockMarkers(marker)
	pos := 0
	s = -1
	for pos <= len(content) {
		nl := strings.IndexByte(content[pos:], '\n')
		lineEnd := len(content)
		next := len(content)
		if nl >= 0 {
			lineEnd = pos + nl
			next = lineEnd + 1
		}
		line := strings.TrimRight(content[pos:lineEnd], "\r \t")
		if s < 0 && line == start {
			s = pos
		} else if s >= 0 && line == end {
			return s, next, true
		}
		if nl < 0 {
			break
		}
		pos = next
	}
	return 0, 0, false
}

// UpsertBlock adds the block (marker is the app id) at the end of content,
// or replaces an existing one in place. It reports whether content changed.
// RemoveBlock undoes an add byte for byte.
func UpsertBlock(content, marker, body string) (string, bool) {
	start, end := BlockMarkers(marker)
	block := start + "\n" + strings.TrimRight(body, "\n") + "\n" + end
	if s, e, ok := findBlock(content, marker); ok {
		repl := block
		if strings.HasSuffix(content[s:e], "\n") {
			repl += "\n"
		}
		out := content[:s] + repl + content[e:]
		return out, out != content
	}
	switch {
	case content == "":
		return block + "\n", true
	case strings.HasSuffix(content, "\n"):
		return content + "\n" + block + "\n", true
	default:
		return content + "\n\n" + block, true
	}
}

// RemoveBlock deletes the block (and the separator UpsertBlock added).
func RemoveBlock(content, marker string) (string, bool) {
	s, e, ok := findBlock(content, marker)
	if !ok {
		return content, false
	}
	before, after := content[:s], content[e:]
	if strings.HasSuffix(content[s:e], "\n") {
		before = strings.TrimSuffix(before, "\n")
		if before != "" && !strings.HasSuffix(before, "\n") {
			before += "\n" // block sat right after content: keep its newline
		}
		if strings.HasSuffix(content[:s], "\n\n") {
			return before + after, true
		}
		return content[:s] + after, true
	}
	if strings.HasSuffix(before, "\n\n") {
		before = strings.TrimSuffix(before, "\n\n")
	}
	return before + after, true
}

// HasLine reports whether content has the line (whitespace-normalised),
// ignoring comment lines.
func HasLine(content, line string) bool {
	want := strings.Join(strings.Fields(line), " ")
	for _, l := range strings.Split(content, "\n") {
		t := strings.TrimSpace(l)
		if t == "" || strings.HasPrefix(t, "#") {
			continue
		}
		if strings.Join(strings.Fields(t), " ") == want {
			return true
		}
	}
	return false
}

const nixStore = "/nix/store/"

// checkWritable returns ErrManaged when path (or a parent) resolves into
// the Nix store or neither it nor its nearest existing directory is
// writable.
func checkWritable(path string) error {
	real, err := fsutil.Resolve(path)
	if err != nil {
		return err
	}
	if strings.HasPrefix(real, nixStore) {
		return ErrManaged
	}
	probe := real
	if _, err := os.Stat(probe); err != nil {
		for {
			probe = filepath.Dir(probe)
			if _, err := os.Stat(probe); err == nil || probe == filepath.Dir(probe) {
				break
			}
		}
	}
	if resolved, err := filepath.EvalSymlinks(probe); err == nil && strings.HasPrefix(resolved, nixStore) {
		return ErrManaged
	}
	if err := syscall.Access(probe, 2); err != nil {
		return ErrManaged
	}
	if probe == real {
		// Existing file: the temp+rename needs a writable directory too.
		if err := syscall.Access(filepath.Dir(real), 2); err != nil {
			return ErrManaged
		}
	}
	return nil
}

// isManaged reports whether writing path would be refused.
func isManaged(path string) bool { return errors.Is(checkWritable(path), ErrManaged) }

// WriteFileSafe atomically writes data (temp+rename, keeping the mode of an
// existing file) unless the path is managed elsewhere (ErrManaged).
func WriteFileSafe(path string, data []byte) error {
	if err := checkWritable(path); err != nil {
		return err
	}
	return fsutil.WriteFile(path, data, 0o644)
}
