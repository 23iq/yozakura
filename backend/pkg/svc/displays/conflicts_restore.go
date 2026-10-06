package displays

import (
	"strings"

	"yozakura/backend/pkg/fsutil"
)

// RestoreMoved undoes MoveConflicts: every line commented out with the
// "<comment> <app>: moved " prefix is uncommented again. It returns the
// restored rules and, in skipped, the ones left commented out (a file that
// cannot be rewritten, see unwritable, or whose write failed) with a Reason.
func RestoreMoved(hyprDir, dataDir, home string) (restored, skipped []Conflict, err error) {
	restored = []Conflict{}
	skipped = []Conflict{}
	err = WalkConfigs(hyprDir, dataDir, func(path string, lua bool, lines []string) error {
		prefix := movedPrefix(lua)
		var found []Conflict
		for n, l := range lines {
			if rest, ok := strings.CutPrefix(l, prefix); ok {
				found = append(found, Conflict{File: path, Line: n + 1, Text: strings.TrimSpace(rest)})
				lines[n] = rest
			}
		}
		if len(found) == 0 {
			return nil
		}
		reason := unwritable(path, home)
		if reason == "" {
			if err := fsutil.WriteFile(path, []byte(strings.Join(lines, "\n")), 0o644); err != nil {
				reason = "write failed: " + err.Error()
			}
		}
		if reason != "" {
			for i := range found {
				found[i].Reason = reason
			}
			skipped = append(skipped, found...)
			return nil
		}
		restored = append(restored, found...)
		return nil
	})
	return restored, skipped, err
}
