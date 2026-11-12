package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/fsutil"
	"yozakura/backend/pkg/paths"
	"yozakura/backend/pkg/svc/compositor"
)

// bootstrapBody is the startup-only stand-in for the generated niri.kdl /
// mango.conf: it starts the shell (absolute path, the PATH of a fresh
// session may lack it) and polkit (`<bin> polkit-fallback` as argv, nil
// without an external agent), which starts the external polkit agent
// unless the shell registers its own. yozd replaces it on the first start
// with the full generated config.
func bootstrapBody(t simpleTarget, bin string, polkit []string) string {
	note := "Bootstrap written by " + brand.DisplayName + "; replaced on the first start."
	body := t.header + " " + note + "\n"
	if t.name != "Niri" {
		body += "exec-once = " + bin + "\n"
		if len(polkit) > 0 {
			words := make([]string, len(polkit))
			for i, a := range polkit {
				words[i] = compositor.ShellWord(a)
			}
			body += "exec-once = " + strings.Join(words, " ") + "\n"
		}
		return body
	}
	// niri spawns argv, not a shell line: one quoted argument each.
	body += fmt.Sprintf("spawn-at-startup %q\n", bin)
	if len(polkit) > 0 {
		args := make([]string, len(polkit))
		for i, a := range polkit {
			args[i] = fmt.Sprintf("%q", a)
		}
		body += "spawn-at-startup " + strings.Join(args, " ") + "\n"
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
	if err := fsutil.WriteFile(path, []byte(bootstrapBody(t, bin, compositor.FallbackArgv(bin))), 0o644); err != nil {
		fmt.Fprintf(os.Stderr, "Warning: could not write %s: %v\n", path, err)
	}
}
