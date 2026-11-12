//go:build ignore

// Command fetchsample writes the greeting samples
// (assets/terminal/fastfetch/samples/<id>.ans) the settings preview shows
// while fastfetch is not installed: every look with the sakura logo, run
// by the fastfetch on PATH with termlook.SampleConfig (fixed, neutral
// values) in termlook.SamplePalette (marker colours swapped for the
// palette at preview time). Run from backend/ on a machine with fastfetch:
//
//	go run ../tools/render/fetchsample.go ../assets/terminal/fastfetch
//
// With -print it writes nothing and prints each sample instead.
package main

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	"yozakura/backend/pkg/termlook"
)

func main() {
	args := os.Args[1:]
	print := len(args) > 0 && args[0] == "-print"
	if print {
		args = args[1:]
	}
	if len(args) != 1 {
		fmt.Fprintln(os.Stderr, "usage: fetchsample [-print] <assets/terminal/fastfetch>")
		os.Exit(2)
	}
	dir := args[0]
	presets, err := termlook.LoadFetchPresets(dir)
	check(err)
	tmp, err := os.MkdirTemp("", "fetchsample-")
	check(err)
	defer os.RemoveAll(tmp)
	logo := filepath.Join(tmp, "logo.txt")
	art, err := os.ReadFile(termlook.SakuraLogoFile(dir))
	check(err)
	check(os.WriteFile(logo, art, 0o644))
	for _, p := range presets {
		if p.Own {
			continue
		}
		s, err := termlook.SampleConfig(p)
		check(err)
		cfg, err := termlook.RenderFetch(s, termlook.SamplePalette(), termlook.FetchLogo{Kind: "file", Source: logo})
		check(err)
		file := filepath.Join(tmp, p.ID+".jsonc")
		check(os.WriteFile(file, cfg, 0o644))
		cmd := exec.Command("fastfetch", "--config", file, "--pipe", "false")
		cmd.Env = []string{"PATH=" + os.Getenv("PATH"), "HOME=" + tmp, "TERM=xterm-256color", "LANG=C.UTF-8"}
		var out, errb bytes.Buffer
		cmd.Stdout, cmd.Stderr = &out, &errb
		if err := cmd.Run(); err != nil {
			fmt.Fprintf(os.Stderr, "%s: %v: %s\n", p.ID, err, errb.String())
			os.Exit(1)
		}
		if print {
			fmt.Printf("== %s\n%s\n", p.ID, out.String())
			continue
		}
		check(os.MkdirAll(filepath.Join(dir, "samples"), 0o755))
		check(os.WriteFile(filepath.Join(dir, "samples", p.ID+".ans"), out.Bytes(), 0o644))
	}
}

func check(err error) {
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
