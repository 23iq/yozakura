package main

import (
	"context"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strings"

	"yozakura/backend/pkg/specials"
	"yozakura/backend/pkg/termrun"
)

// launchEnv is what `launch` needs from the system (swapped in tests).
type launchEnv struct {
	dirs     []string
	lookPath func(string) (string, error)
	start    func(argv []string) error
	// A terminal app starts the passwd login shell once it differs from
	// the session's $SHELL (cmds_terminal.go); nil: argv as it is.
	readFile   func(string) ([]byte, error)
	loginShell func() string
	shell      func() string
}

func defaultLaunchEnv() launchEnv {
	return launchEnv{
		dirs: specials.ApplicationDirs(), lookPath: exec.LookPath, start: startDetached,
		readFile: os.ReadFile, loginShell: termrun.LoginShell, shell: func() string { return os.Getenv("SHELL") },
	}
}

// runLaunch starts an installed app by desktop id the way the launcher does
// (AppSearch.launchApp): `gio launch <file>` in a new session in $HOME,
// without the caller's Hyprland workspace token. Keybinds of the
// "apps.launch" action render to it (pkg/svc/compositor LaunchCommand).
func runLaunch(args []string, env launchEnv, stderr io.Writer) int {
	if len(args) != 1 || strings.TrimSpace(args[0]) == "" || strings.HasPrefix(args[0], "-") {
		fmt.Fprintln(stderr, branded("Usage: {bin} launch <desktop-id>   (e.g. firefox, org.gnome.Nautilus)"))
		return 2
	}
	id := strings.TrimSuffix(strings.TrimSpace(args[0]), ".desktop")
	file, ok := specials.File(env.dirs, id)
	if !ok {
		fmt.Fprintf(stderr, "launch: no installed app %q\n", id)
		return 1
	}
	argv := []string{"gio", "launch", file}
	if _, err := env.lookPath("gio"); err != nil {
		if _, err := env.lookPath("gtk-launch"); err != nil {
			fmt.Fprintln(stderr, "launch: needs gio (glib2) or gtk-launch")
			return 1
		}
		argv = []string{"gtk-launch", id}
	}
	if env.readFile != nil {
		if data, err := env.readFile(file); err == nil && termrun.IsTerminalEntry(string(data)) {
			argv = withSessionLoginShell(argv, env.loginShell, env.shell)
		}
	}
	if err := env.start(argv); err != nil {
		fmt.Fprintf(stderr, "launch: %v\n", err)
		return 1
	}
	return 0
}

// startDetached runs argv in its own session from $HOME and does not wait.
func startDetached(argv []string) error {
	cmd := exec.CommandContext(context.Background(), argv[0], argv[1:]...)
	if home, err := os.UserHomeDir(); err == nil {
		cmd.Dir = home
	}
	env := os.Environ()[:0:0]
	for _, kv := range os.Environ() {
		if !strings.HasPrefix(kv, "HL_INITIAL_WORKSPACE_TOKEN=") {
			env = append(env, kv)
		}
	}
	cmd.Env = env
	cmd.SysProcAttr = detachAttr()
	if err := cmd.Start(); err != nil {
		return err
	}
	return cmd.Process.Release()
}
