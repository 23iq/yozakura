package main

import (
	"fmt"
	"io"
	"os"
	"strings"

	"yozakura/backend/pkg/termrun"
)

const terminalHelp = `Usage: {bin} terminal run [--cwd DIR] [--keep-open=true|false] -- COMMAND

Open the configured terminal (general.terminal; with general.terminalAdvanced
the general.terminalCommand template) running COMMAND, a shell command line.
--cwd starts it in DIR (~ is expanded); --keep-open (default true) leaves
an interactive shell open after the command ends. The command travels as one
argument of a fixed "sh -c" script, it is never pasted into a shell string.
This is what the "Run in terminal" keybind / routine action runs.
`

// terminalEnv is what `terminal run` needs from the system (swapped in tests).
type terminalEnv struct {
	config func() termrun.Config
	home   func() string
	start  func(argv []string) error
}

func defaultTerminalEnv() terminalEnv {
	return terminalEnv{
		config: storedTerminalConfig,
		home:   func() string { h, _ := os.UserHomeDir(); return h },
		start:  startDetached,
	}
}

// storedTerminalConfig reads the same keys as TerminalService.qml.
func storedTerminalConfig() termrun.Config {
	c := termrun.Config{Terminal: "kitty", Template: "$TERMINAL -e $COMMAND"}
	env, err := loadConfigEnv()
	if err != nil {
		return c
	}
	if v, _, err := env.store.Get("general.terminal"); err == nil {
		if s, ok := v.(string); ok && strings.TrimSpace(s) != "" {
			c.Terminal = s
		}
	}
	if v, _, err := env.store.Get("general.terminalAdvanced"); err == nil {
		c.Advanced, _ = v.(bool)
	}
	if v, _, err := env.store.Get("general.terminalCommand"); err == nil {
		if s, ok := v.(string); ok && s != "" {
			c.Template = s
		}
	}
	return c
}

// runTerminal implements `yozakura terminal run ...`.
func runTerminal(args []string, env terminalEnv, errOut io.Writer) int {
	if len(args) == 0 || args[0] != "run" {
		fmt.Fprint(errOut, branded(terminalHelp))
		if len(args) == 0 || args[0] == "help" || args[0] == "-h" || args[0] == "--help" {
			return 0
		}
		return 2
	}
	a := parseCLI(args[1:], nil, []string{"cwd", "keep-open"})
	command := strings.TrimSpace(strings.Join(a.pos, " "))
	if command == "" {
		fmt.Fprint(errOut, branded(terminalHelp))
		return 2
	}
	keep := true
	if v, ok := a.value("keep-open"); ok {
		switch strings.ToLower(strings.TrimSpace(v)) {
		case "true", "1", "yes", "on":
		case "false", "0", "no", "off":
			keep = false
		default:
			fmt.Fprintf(errOut, "terminal: --keep-open takes true or false, not %q\n", v)
			return 2
		}
	}
	cwd, _ := a.value("cwd")
	req := termrun.Request{Command: command, Cwd: termrun.ExpandHome(cwd, env.home()), KeepOpen: keep}
	argv, err := termrun.Argv(env.config(), req)
	if err != nil {
		fmt.Fprintf(errOut, "terminal: %v\n", err)
		return 1
	}
	if err := env.start(argv); err != nil {
		fmt.Fprintf(errOut, "terminal: %v\n", err)
		return 1
	}
	return 0
}
