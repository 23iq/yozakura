package exclusive

import (
	"os/exec"
	"strings"
)

// ExecSystemd drives `systemctl --user` through argv (no shell). Run is
// replaceable for tests; the default executes systemctl.
type ExecSystemd struct {
	Run func(args ...string) ([]byte, error)
}

func (s ExecSystemd) run(args ...string) ([]byte, error) {
	full := append([]string{"--user", "--no-pager"}, args...)
	if s.Run != nil {
		return s.Run(full...)
	}
	return exec.Command("systemctl", full...).CombinedOutput()
}

func (s ExecSystemd) IsEnabled(unit string) bool {
	out, err := s.run("is-enabled", unit)
	return err == nil && strings.TrimSpace(string(out)) == "enabled"
}

func (s ExecSystemd) IsActive(unit string) bool {
	out, err := s.run("is-active", unit)
	return err == nil && strings.TrimSpace(string(out)) == "active"
}

func (s ExecSystemd) Disable(unit string) error {
	return s.check(s.run("disable", "--now", unit))
}

func (s ExecSystemd) Enable(unit string, start bool) error {
	if start {
		return s.check(s.run("enable", "--now", unit))
	}
	return s.check(s.run("enable", unit))
}

// ListUserUnits returns the unit names (file or loaded) matching pattern.
func (s ExecSystemd) ListUserUnits(pattern string) []string {
	out, _ := s.run("list-unit-files", "--plain", "--no-legend", pattern)
	var units []string
	for _, line := range strings.Split(string(out), "\n") {
		if f := strings.Fields(line); len(f) > 0 {
			units = append(units, f[0])
		}
	}
	return units
}

func (s ExecSystemd) check(out []byte, err error) error {
	if err != nil {
		if msg := strings.TrimSpace(string(out)); msg != "" {
			return &unitError{msg}
		}
	}
	return err
}

type unitError struct{ msg string }

func (e *unitError) Error() string { return e.msg }
