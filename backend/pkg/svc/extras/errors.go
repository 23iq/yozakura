package extras

import (
	"encoding/json"
	"errors"
	"io/fs"
	"os"
	"regexp"
	"strings"
	"syscall"

	"yozakura/backend/pkg/brand"
)

// Error codes of the extras IPC service. IPC errors are plain strings, so a
// coded error reads "<code>: <JSON object>"; ParseError splits it again.
const (
	CodeNeedsConfirm   = "needs_confirm"   // {"kind":"multilib","entries":[...]}
	CodeUnavailable    = "unavailable"     // {"reasons":{"<id>":"<reason>"}}
	CodeNotCancellable = "not_cancellable" // a running system install can't be stopped
	CodeUnknownJob     = "unknown_job"
)

type codedError struct {
	code string
	data map[string]any
}

func (e *codedError) Error() string {
	b, _ := json.Marshal(e.data)
	return e.code + ": " + string(b)
}

var reCoded = regexp.MustCompile(`^([a-z_]+): (\{.*\})$`)

// ParseError splits an error message produced by the service into its code
// and JSON payload. code is "" for plain errors.
func ParseError(msg string) (code string, data map[string]any) {
	m := reCoded.FindStringSubmatch(strings.TrimSpace(msg))
	if m == nil {
		return "", nil
	}
	if json.Unmarshal([]byte(m[2]), &data) != nil {
		return "", nil
	}
	return m[1], data
}

// codeOf maps planner / queue errors to coded errors.
func codeOf(err error) error {
	var nc *ErrNeedsConfirm
	var un *UnavailableError
	switch {
	case errors.As(err, &nc):
		return &codedError{CodeNeedsConfirm, map[string]any{"kind": nc.Kind, "entries": nc.Entries}}
	case errors.As(err, &un):
		return &codedError{CodeUnavailable, map[string]any{"reasons": un.Reasons}}
	case errors.Is(err, ErrNotCancellable):
		return &codedError{CodeNotCancellable, map[string]any{"message": err.Error()}}
	case errors.Is(err, ErrUnknownJob):
		return &codedError{CodeUnknownJob, map[string]any{"message": err.Error()}}
	}
	return err
}

// installedHelper is the root-owned copy of the binary the installer puts
// in place; pkexec runs it in preference to the user-writable build.
var installedHelper = "/usr/local/lib/" + brand.AppID + "/" + brand.AppID + "-sys"

// helperPath is the binary pkexec runs for `sys ...`: the installed helper
// when it is a regular file, owned by root and not group/world writable;
// otherwise fallback (the running binary).
func helperPath(candidate, fallback string, lstat func(string) (fs.FileInfo, error)) string {
	fi, err := lstat(candidate)
	if err != nil || !fi.Mode().IsRegular() || fi.Mode().Perm()&0o022 != 0 {
		return fallback
	}
	if st, ok := fi.Sys().(*syscall.Stat_t); !ok || st.Uid != 0 {
		return fallback
	}
	return candidate
}

// defaultHelper resolves the helper with the real filesystem.
func defaultHelper() string {
	self, err := os.Executable()
	if err != nil {
		self = brand.AppID
	}
	return helperPath(installedHelper, self, os.Lstat)
}
