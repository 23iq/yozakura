// Package yozdcli calls the compositor daemon's display and keyboard RPCs
// through its CLI (`<daemon> monitor outputs`, ...), the way other backend
// services reach it. Values travel as argv (JSON in one argument), never
// through a shell.
package yozdcli

import (
	"encoding/json"
	"errors"
	"fmt"
	"os/exec"
	"strings"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/paths"
	"yozakura/backend/pkg/yozd/ipc"
)

// Client runs daemon CLI commands. Run is replaceable in tests.
type Client struct {
	Run func(args ...string) ([]byte, error)
}

// New returns a client for the installed daemon binary.
func New() *Client {
	return &Client{Run: func(args ...string) ([]byte, error) {
		return exec.Command(paths.DaemonBinary(), args...).Output()
	}}
}

// call runs args and turns the CLI's error lines (printed with exit status
// 0) into an error; "not supported" maps to ipc.ErrNotSupported.
func (c *Client) call(args ...string) ([]byte, error) {
	out, err := c.Run(args...)
	if err != nil {
		return nil, fmt.Errorf("%s %s: %w", brand.Daemon, strings.Join(args[:min(2, len(args))], " "), err)
	}
	// Any "Error..." line is a failure: "Error: <rpc error>" as well as
	// "Error connecting to daemon: ..." when the daemon is down.
	text := strings.TrimSpace(string(out))
	if strings.HasPrefix(text, "Error") {
		if strings.Contains(text, ipc.ErrNotSupported.Error()) {
			return nil, ipc.ErrNotSupported
		}
		msg, ok := strings.CutPrefix(text, "Error:")
		if !ok {
			msg = text
		}
		return nil, errors.New(strings.TrimSpace(msg))
	}
	return out, nil
}

// Outputs lists every output with its modes.
func (c *Client) Outputs() ([]ipc.Output, error) {
	out, err := c.call("monitor", "outputs")
	if err != nil {
		return nil, err
	}
	var outputs []ipc.Output
	if err := json.Unmarshal(out, &outputs); err != nil {
		return nil, fmt.Errorf("parse outputs: %w", err)
	}
	return outputs, nil
}

// ApplyOutput applies one output configuration live.
func (c *Client) ApplyOutput(cfg ipc.OutputConfig) error {
	if err := cfg.Validate(); err != nil {
		return err
	}
	raw, err := json.Marshal(cfg)
	if err != nil {
		return err
	}
	_, err = c.call("monitor", "apply", string(raw))
	return err
}

// ApplyKeyboard applies XKB settings live.
func (c *Client) ApplyKeyboard(s ipc.KeyboardSettings) error {
	if err := s.Validate(); err != nil {
		return err
	}
	raw, err := json.Marshal(s)
	if err != nil {
		return err
	}
	_, err = c.call("keyboard", "apply", string(raw))
	return err
}

// ActiveLayout reports the main keyboard's active layout.
func (c *Client) ActiveLayout() (ipc.KeyboardLayoutState, error) {
	var st ipc.KeyboardLayoutState
	out, err := c.call("keyboard", "active")
	if err != nil {
		return st, err
	}
	if err := json.Unmarshal(out, &st); err != nil {
		return st, fmt.Errorf("parse keyboard state: %w", err)
	}
	return st, nil
}

// ReloadConfig reloads the compositor config (`yozd config reload`).
func (c *Client) ReloadConfig() error {
	_, err := c.call("config", "reload")
	return err
}

// ConfigErrors lists the errors of the compositor's last config load
// (`yozd config errors`); empty when it was clean.
func (c *Client) ConfigErrors() ([]string, error) {
	out, err := c.call("config", "errors")
	if err != nil {
		return nil, err
	}
	var errs []string
	if err := json.Unmarshal(out, &errs); err != nil {
		return nil, fmt.Errorf("parse config errors: %w", err)
	}
	return errs, nil
}

// Compositor names the running compositor (hyprland, niri, mango).
func (c *Client) Compositor() (string, error) {
	out, err := c.call("system", "get-compositor")
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(out)), nil
}

// NextLayout switches to the next keyboard layout.
func (c *Client) NextLayout() error {
	_, err := c.call("system", "switch-keyboard-layout", "next")
	return err
}
