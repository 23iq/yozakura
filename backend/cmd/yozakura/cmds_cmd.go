package main

import (
	"bytes"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strings"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/commands"
)

const cmdUsage = `Usage: {bin} cmd [list [--json]] | <command> [argument]

Run a shell command from the command registry (assets/commands/commands.json),
the same commands the launcher offers after ">" (e.g. "> dnd", "> glass 0.6").

Commands:
    list [--json]           Every command with its usage and description
    <command> [argument]    Run one, e.g. "{bin} cmd preset Neon Tokyo",
                            "{bin} cmd glass 0.6", "{bin} cmd wallpaper random"

UI commands need the running shell; config and CLI commands work without it.
`

// cmdEnv holds the injectable side effects of `cmd` (tests replace them).
type cmdEnv struct {
	root string
	exec commands.Executor
}

func defaultCmdEnv(out, errOut io.Writer) cmdEnv {
	return cmdEnv{
		root: shellSourceForCmd(),
		exec: commands.Executor{
			Call: func(method string, params any) error {
				if !isAlive() {
					return fmt.Errorf("%s is not running", brand.DisplayName)
				}
				_, err := newClient().Call(method, params)
				return err
			},
			Exec: func(args []string) (string, error) {
				self, err := os.Executable()
				if err != nil {
					self = brand.AppID
				}
				c := exec.Command(self, args...)
				var buf bytes.Buffer
				c.Stdout = &buf
				c.Stderr = errOut
				err = c.Run()
				return strings.TrimRight(buf.String(), "\n"), err
			},
			SetConfig: func(key string, value any) (string, error) {
				env, err := loadConfigEnv()
				if err != nil {
					return "", err
				}
				return commands.ConfigSetter(env.store)(key, value)
			},
		},
	}
}

func shellSourceForCmd() string {
	env, err := loadConfigEnv()
	if err != nil {
		return ""
	}
	return env.src
}

// runCmd implements `yozakura cmd ...`.
func runCmd(args []string, out, errOut io.Writer) int {
	return runCmdWith(defaultCmdEnv(out, errOut), args, out, errOut)
}

func runCmdWith(env cmdEnv, args []string, out, errOut io.Writer) int {
	if len(args) > 0 && (args[0] == "help" || args[0] == "-h" || args[0] == "--help") {
		fmt.Fprint(out, branded(cmdUsage))
		return 0
	}
	reg, err := commands.Load(env.root)
	if err != nil {
		fmt.Fprintf(errOut, "Error: %v\n", err)
		return 1
	}
	if len(args) == 0 || args[0] == "list" || args[0] == "ls" {
		a := parseCLI(args, []string{"json"}, nil)
		if a.has("json") {
			if err := writeJSON(out, reg.Views()); err != nil {
				fmt.Fprintf(errOut, "Error: %v\n", err)
				return 1
			}
			return 0
		}
		width := 0
		for _, v := range reg.Views() {
			width = max(width, len(v.Usage))
		}
		for _, v := range reg.Views() {
			text := v.Title
			if v.Description != "" {
				text += ": " + v.Description
			}
			fmt.Fprintf(out, "%-*s  %s\n", width, v.Usage, text)
		}
		return 0
	}
	switch args[0] {
	case "__ids":
		for _, id := range reg.IDs() {
			fmt.Fprintln(out, id)
		}
		return 0
	case "__args":
		if len(args) > 1 {
			if c, ok := reg.Find(args[1]); ok && c.TakesArg() {
				switch c.Arg.Kind {
				case commands.ArgEnum:
					fmt.Fprintln(out, strings.Join(c.Arg.Values, "\n"))
				case commands.ArgPreset:
					if m, err := presetManager(); err == nil {
						for _, p := range m.List() {
							fmt.Fprintln(out, p.Name)
						}
					}
				}
			}
		}
		return 0
	}
	res, err := reg.Run(env.exec, args[0], strings.Join(args[1:], " "))
	if err != nil {
		fmt.Fprintf(errOut, "Error: %v\n", err)
		return 1
	}
	if res != "" {
		fmt.Fprintln(out, res)
	}
	return 0
}
