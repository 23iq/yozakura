package main

import (
	"fmt"
	"io"
	"os"
	"os/exec"
	"strings"
	"syscall"

	"yozakura/backend/pkg/paths"
	"yozakura/backend/pkg/svc/compositor"
)

// polkitEnv is what polkit-fallback reads from the host (faked in tests).
type polkitEnv struct {
	shellAgent func() bool
	command    func() string
	lookPath   func(string) (string, error)
	exec       func(bin string, argv []string) error
}

func defaultPolkitEnv() polkitEnv {
	return polkitEnv{
		shellAgent: func() bool { return compositor.ShellAgent(paths.New().Config("system")) },
		command:    compositor.PolkitCommand,
		lookPath:   exec.LookPath,
		exec: func(bin string, argv []string) error {
			return syscall.Exec(bin, argv, os.Environ())
		},
	}
}

// runPolkitFallback (`<app> polkit-fallback`, run at login by the
// compositor's startup lines) starts the installed external polkit agent,
// replacing this process, unless the shell registers its own agent
// (system.polkitAgent on and a Quickshell with the Polkit module): two
// agents race to register and only one can. Exit 0 when the shell's agent
// takes the prompts.
func runPolkitFallback(args []string, env polkitEnv, stderr io.Writer) int {
	if len(args) > 0 {
		fmt.Fprintf(stderr, "Usage: %s\n", compositor.FallbackVerb)
		return 2
	}
	if env.shellAgent() {
		return 0
	}
	argv := strings.Fields(env.command())
	if len(argv) == 0 {
		fmt.Fprintln(stderr, "polkit-fallback: no polkit agent is installed")
		return 1
	}
	bin, err := env.lookPath(argv[0])
	if err != nil {
		fmt.Fprintf(stderr, "polkit-fallback: %v\n", err)
		return 1
	}
	if err := env.exec(bin, argv); err != nil {
		fmt.Fprintf(stderr, "polkit-fallback: %v\n", err)
		return 1
	}
	return 0
}
