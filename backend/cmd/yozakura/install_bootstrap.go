package main

import (
	"fmt"
	"os"
	"path/filepath"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/fsutil"
	"yozakura/backend/pkg/paths"
	"yozakura/backend/pkg/svc/compositor"
)

// bootstrapBody is the startup-only stand-in for the generated niri.kdl /
// mango.conf: it starts the shell (absolute path, the PATH of a fresh
// session may lack it) and the polkit agent. yozd replaces it on the first
// start with the full generated config, which carries the same two lines.
func bootstrapBody(t simpleTarget, bin, polkit string) string {
	note := "Bootstrap written by " + brand.DisplayName + "; replaced on the first start."
	cmds := []string{bin}
	if polkit != "" {
		cmds = append(cmds, polkit)
	}
	body := t.header + " " + note + "\n"
	for _, c := range cmds {
		if t.name == "Niri" {
			body += fmt.Sprintf("spawn-at-startup %q\n", c)
		} else {
			body += "exec-once = " + c + "\n"
		}
	}
	return body
}

// writeStartupBootstrap creates the file the include line loads when it does
// not exist yet, so the first login after `install niri|mango` starts the
// shell before anything has generated the real one.
func writeStartupBootstrap(t simpleTarget, bin string) {
	name := "mango.conf"
	if t.name == "Niri" {
		name = "niri.kdl"
	}
	path := filepath.Join(paths.New().DataDir, name)
	if fileExists(path) {
		return
	}
	if bin == "" {
		bin = brand.AppID
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		fmt.Fprintf(os.Stderr, "Warning: could not create %s: %v\n", filepath.Dir(path), err)
		return
	}
	if err := fsutil.WriteFile(path, []byte(bootstrapBody(t, bin, compositor.PolkitCommand())), 0o644); err != nil {
		fmt.Fprintf(os.Stderr, "Warning: could not write %s: %v\n", path, err)
	}
}
