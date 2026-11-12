package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"yozakura/backend/pkg/brand"
	conv "yozakura/backend/pkg/convert"
	"yozakura/backend/pkg/paths"
	convertsvc "yozakura/backend/pkg/svc/convert"
)

const convertUsage = `Usage:
  {bin} convert <file>... [--to <format>] [--out <dir>] [--quality small|balanced|best] [--json]
                                   Convert files (default target: the one the converter proposes);
                                   results go next to each file, never over an existing one
  {bin} convert formats [<file>]   Every format and the installed engines, or what a file
                                   converts to (* = proposed, - = needs a tool)
  {bin} run converter              Open the converter window
`

// convertEnv: the service the command drives (tests swap the engines).
type convertEnv struct {
	svc   *convertsvc.Service
	tick  time.Duration
	tools func() *conv.Tools
	// interrupted closes on SIGINT / SIGTERM: the jobs are cancelled and
	// cleaned up before the command exits (nil = never)
	interrupted <-chan struct{}
}

func defaultConvertEnv() convertEnv {
	s := convertsvc.NewService(paths.New().CacheDir)
	ctx, _ := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	return convertEnv{svc: s, tick: 100 * time.Millisecond, tools: s.Tools, interrupted: ctx.Done()}
}

// runConvert implements `yozakura convert`; it converts in this process
// (no running shell needed).
func runConvert(args []string, env convertEnv, out, errOut io.Writer) int {
	usage := func() int {
		fmt.Fprint(errOut, branded(convertUsage))
		return 2
	}
	if len(args) == 0 {
		return usage()
	}
	switch args[0] {
	case "help", "--help", "-h":
		fmt.Fprint(out, branded(convertUsage))
		return 0
	case "formats":
		return convertFormats(args[1:], env, out, errOut)
	case "__formats":
		fmt.Fprintln(out, strings.Join(conv.IDs(), "\n"))
		return 0
	}
	var files []string
	var to, outDir, quality string
	asJSON := false
	for i := 0; i < len(args); i++ {
		a := args[i]
		val := func() (string, bool) {
			if k, v, ok := strings.Cut(a, "="); ok && strings.HasPrefix(k, "--") {
				return v, true
			}
			if i+1 < len(args) {
				i++
				return args[i], true
			}
			return "", false
		}
		switch {
		case a == "--json":
			asJSON = true
		case a == "--to" || strings.HasPrefix(a, "--to="):
			v, ok := val()
			if !ok {
				return usage()
			}
			to = v
		case a == "--out" || strings.HasPrefix(a, "--out="):
			v, ok := val()
			if !ok {
				return usage()
			}
			outDir = v
		case a == "--quality" || strings.HasPrefix(a, "--quality="):
			v, ok := val()
			if !ok {
				return usage()
			}
			quality = v
		case strings.HasPrefix(a, "-") && a != "-":
			fmt.Fprintf(errOut, "Error: unknown flag %s\n", a)
			return usage()
		default:
			files = append(files, a)
		}
	}
	if len(files) == 0 {
		return usage()
	}
	if to != "" {
		f, ok := conv.Lookup(to)
		if !ok {
			fmt.Fprintf(errOut, "Error: unknown format %q (see `%s convert formats`)\n", to, brand.AppID)
			return 2
		}
		to = f.ID
	}
	tools := env.tools()
	items := make([]convertsvc.Item, 0, len(files))
	for _, f := range files {
		target := to
		if target == "" {
			p := convertsvc.Probe(absPath(f), tools)
			if p.Error != "" {
				fmt.Fprintf(errOut, "%s: %s\n", f, p.Error)
				return 1
			}
			target = p.Default
		}
		items = append(items, convertsvc.Item{Path: f, Target: target})
	}
	if _, err := env.svc.Start(convertsvc.StartParams{Items: items, OutDir: outDir, Quality: quality}); err != nil {
		fmt.Fprintf(errOut, "Error: %v\n", err)
		return 1
	}
	jobs, interrupted := waitJobs(env)
	env.svc.Stop()
	if interrupted {
		fmt.Fprintln(errOut, "Interrupted: conversions stopped")
		return 130
	}
	failed := 0
	for _, j := range jobs {
		if j.State != convertsvc.StateDone {
			failed++
		}
	}
	if asJSON {
		b, _ := json.MarshalIndent(jobs, "", "  ")
		fmt.Fprintln(out, string(b))
	} else {
		for _, j := range jobs {
			if j.State == convertsvc.StateDone {
				fmt.Fprintf(out, "%s -> %s\n", j.Name, j.Output)
			} else {
				fmt.Fprintf(errOut, "%s: %s\n", j.Name, j.Error)
			}
		}
	}
	if failed > 0 {
		return 1
	}
	return 0
}

// waitJobs waits for every job; true when a signal cut it short.
func waitJobs(env convertEnv) ([]convertsvc.Job, bool) {
	for {
		jobs := env.svc.Jobs()
		busy := false
		for _, j := range jobs {
			if j.State == convertsvc.StateQueued || j.State == convertsvc.StateRunning {
				busy = true
			}
		}
		if !busy {
			return jobs, false
		}
		select {
		case <-env.interrupted:
			return jobs, true
		case <-time.After(env.tick):
		}
	}
}

func absPath(p string) string {
	if a, err := filepath.Abs(p); err == nil {
		return a
	}
	return p
}

func convertFormats(args []string, env convertEnv, out, errOut io.Writer) int {
	tools := env.tools()
	if len(args) == 0 {
		var engines []string
		for _, e := range tools.Installed() {
			engines = append(engines, string(e))
		}
		fmt.Fprintf(out, "Engines: native %s\n", strings.Join(engines, " "))
		var kind conv.Kind
		var line []string
		flush := func() {
			if len(line) > 0 {
				fmt.Fprintf(out, "%-9s %s\n", kind+":", strings.Join(line, " "))
			}
			line = nil
		}
		for _, f := range conv.Formats() {
			if f.Kind != kind {
				flush()
				kind = f.Kind
			}
			line = append(line, f.ID)
		}
		flush()
		return 0
	}
	status := 0
	for _, file := range args {
		p := convertsvc.Probe(absPath(file), tools)
		if p.Error != "" {
			fmt.Fprintf(errOut, "%s: %s\n", file, p.Error)
			status = 1
			continue
		}
		fmt.Fprintf(out, "%s: %s (%s)\n", file, p.FormatLabel, p.Kind)
		for _, t := range p.Targets {
			mark := " "
			switch {
			case t.ID == p.Default:
				mark = "*"
			case !t.Available:
				mark = "-"
			}
			note := ""
			if !t.Available {
				note = "  needs " + t.Needs
			}
			fmt.Fprintf(out, "  %s %-5s %s%s\n", mark, t.ID, t.Label, note)
		}
	}
	return status
}
