package voice

import (
	"errors"
	"fmt"
	"os/exec"
	"strings"
)

// Runner executes a command with optional stdin; tests replace it.
type Runner func(stdin string, name string, args ...string) error

func execRunner(stdin string, name string, args ...string) error {
	cmd := exec.Command(name, args...)
	if stdin != "" {
		cmd.Stdin = strings.NewReader(stdin)
	}
	// No captured output: wl-copy forks a daemon that inherits stdout and
	// stderr, and waiting for those pipes to close would block forever.
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("%s: %w", name, err)
	}
	return nil
}

// Typer types dictated text into the focused window.
type Typer struct {
	Run      Runner
	LookPath func(string) (string, error)
}

// NewTyper returns a Typer using the real tools.
func NewTyper() *Typer {
	return &Typer{Run: execRunner, LookPath: exec.LookPath}
}

// Type sends text with method "auto" | "wtype" | "ydotool" | "clipboard".
// auto prefers wtype (virtual-keyboard protocol, full Unicode), then
// ydotool, then the clipboard (wl-copy + Ctrl+V via wtype).
func (t *Typer) Type(text, method string) (string, error) {
	if text == "" {
		return "", nil
	}
	have := func(n string) bool { _, err := t.LookPath(n); return err == nil }
	order := []string{method}
	if method == "auto" || method == "" {
		order = []string{"wtype", "ydotool", "clipboard"}
	}
	var errs []error
	for _, m := range order {
		var err error
		switch m {
		case "wtype":
			if !have("wtype") {
				err = errors.New("wtype not installed")
				break
			}
			err = t.Run("", "wtype", "--", text)
		case "ydotool":
			if !have("ydotool") {
				err = errors.New("ydotool not installed")
				break
			}
			err = t.Run("", "ydotool", "type", "--", text)
		case "clipboard":
			if !have("wl-copy") || !have("wtype") {
				err = errors.New("clipboard typing needs wl-copy and wtype")
				break
			}
			if err = t.Run(text, "wl-copy"); err == nil {
				err = t.Run("", "wtype", "-M", "ctrl", "v", "-m", "ctrl")
			}
		default:
			err = fmt.Errorf("unknown typing method %q", m)
		}
		if err == nil {
			return m, nil
		}
		errs = append(errs, err)
	}
	return "", errors.Join(errs...)
}
