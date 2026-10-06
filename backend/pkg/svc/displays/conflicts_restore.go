package displays

import (
	"strings"

	"yozakura/backend/pkg/fsutil"
)

// RestoreMoved undoes MoveConflicts: every line commented out with the
// "<comment> <app>: moved " prefix is uncommented again. It returns the
// restored rules; files that cannot be rewritten (see unwritable) or whose
// write fails are left as they are.
func RestoreMoved(hyprDir, dataDir, home string) ([]Conflict, error) {
	restored := []Conflict{}
	err := WalkConfigs(hyprDir, dataDir, func(path string, lua bool, lines []string) error {
		prefix := movedPrefix(lua)
		var found []Conflict
		for n, l := range lines {
			if rest, ok := strings.CutPrefix(l, prefix); ok {
				found = append(found, Conflict{File: path, Line: n + 1, Text: strings.TrimSpace(rest)})
				lines[n] = rest
			}
		}
		if len(found) == 0 || unwritable(path, home) != "" {
			return nil
		}
		if err := fsutil.WriteFile(path, []byte(strings.Join(lines, "\n")), 0o644); err != nil {
			return nil
		}
		restored = append(restored, found...)
		return nil
	})
	return restored, err
}
