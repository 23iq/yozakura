package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"sort"
	"strings"
	"text/tabwriter"
	"time"

	"yozakura/backend/pkg/svc/extras"
)

const extrasHelp = `Usage: {bin} extras list [--category <id>] [--json]
       {bin} extras install <id>... [--yes-multilib]
       {bin} extras status <id> [--json]

Apps and tools the shell can install for you (browsers, AI agents, media,
games ...). list shows every catalog entry with its state; install queues
the entries and streams progress until they finish (system packages ask for
your password through polkit); status shows one entry.
--yes-multilib agrees to enabling the pacman [multilib] repo (needed by
Steam and other 32-bit software).
`

// extrasClient is the daemon access of `extras`: calls plus the event stream.
type extrasClient interface {
	usageCaller
	// Watch streams extras.* events to fn until fn returns true or the
	// connection ends. It returns once the stream is set up.
	Watch(fn func(name string, data json.RawMessage) (stop bool)) (stop func(), err error)
}

type ipcExtras struct {
	usageCaller
	socket string
}

func (c ipcExtras) Watch(fn func(string, json.RawMessage) bool) (func(), error) {
	conn, err := net.Dial("unix", c.socket)
	if err != nil {
		return nil, err
	}
	req, _ := json.Marshal(map[string]any{"id": 1, "method": "subscribe", "params": map[string]any{"services": []string{"extras"}}})
	if _, err := conn.Write(append(req, '\n')); err != nil {
		conn.Close()
		return nil, err
	}
	go func() {
		defer conn.Close()
		sc := bufio.NewScanner(conn)
		sc.Buffer(make([]byte, 64*1024), 4<<20)
		for sc.Scan() {
			var resp struct {
				Result struct {
					Service string          `json:"service"`
					Data    json.RawMessage `json:"data"`
				} `json:"result"`
			}
			if json.Unmarshal(sc.Bytes(), &resp) != nil || resp.Result.Service == "" {
				continue
			}
			if fn(resp.Result.Service, resp.Result.Data) {
				return
			}
		}
	}()
	return func() { conn.Close() }, nil
}

func extrasErr(errOut io.Writer, err error) int {
	code, data := extras.ParseError(err.Error())
	switch code {
	case extras.CodeNeedsConfirm:
		fmt.Fprintf(errOut, "Error: this needs the pacman [multilib] repo (%v); re-run with --yes-multilib to enable it.\n", data["entries"])
	case extras.CodeUnavailable:
		reasons, _ := data["reasons"].(map[string]any)
		ids := make([]string, 0, len(reasons))
		for id := range reasons {
			ids = append(ids, id)
		}
		sort.Strings(ids)
		fmt.Fprintln(errOut, "Error: can't install on this system:")
		for _, id := range ids {
			fmt.Fprintf(errOut, "  %s: %v\n", id, reasons[id])
		}
	case "":
		fmt.Fprintf(errOut, "Error: %v (is the shell running?)\n", err)
	default:
		fmt.Fprintf(errOut, "Error: %s\n", err)
	}
	return 1
}

// runExtras implements `yozakura extras ...`.
func runExtras(args []string, c extrasClient, out, errOut io.Writer) int {
	var rest []string
	asJSON, yesMultilib, category := false, false, ""
	for i := 0; i < len(args); i++ {
		switch a := args[i]; a {
		case "--json":
			asJSON = true
		case "--yes-multilib":
			yesMultilib = true
		case "--category":
			if i+1 >= len(args) {
				fmt.Fprint(errOut, "Error: --category needs a value\n"+branded(extrasHelp))
				return 2
			}
			i++
			category = args[i]
		case "help", "-h", "--help":
			fmt.Fprint(out, branded(extrasHelp))
			return 0
		default:
			rest = append(rest, a)
		}
	}
	sub := "list"
	if len(rest) > 0 {
		sub, rest = rest[0], rest[1:]
	}
	switch {
	case sub == "list" && len(rest) == 0:
		return extrasList(c, category, asJSON, out, errOut)
	case sub == "status" && len(rest) == 1:
		return extrasStatus(c, rest[0], asJSON, out, errOut)
	case sub == "install" && len(rest) >= 1:
		return extrasInstall(c, rest, yesMultilib, out, errOut)
	}
	fmt.Fprintf(errOut, "Error: unknown arguments %q\n%s", strings.Join(append([]string{sub}, rest...), " "), branded(extrasHelp))
	return 2
}

type extrasRow struct {
	ID       string `json:"id"`
	Name     string `json:"name"`
	Category string `json:"category"`
	State    string `json:"state"`
	Source   string `json:"source,omitempty"`
	Reason   string `json:"reason,omitempty"`
}

func extrasRows(c usageCaller) ([]extrasRow, error) {
	raw, err := c.Call("extras.catalog", nil)
	if err != nil {
		return nil, err
	}
	var cat struct {
		Entries []struct {
			ID, Name, Category string
			Hidden             bool
		} `json:"entries"`
	}
	if err := json.Unmarshal(raw, &cat); err != nil {
		return nil, err
	}
	raw, err = c.Call("extras.status", nil)
	if err != nil {
		return nil, err
	}
	var st map[string]extras.Status
	if err := json.Unmarshal(raw, &st); err != nil {
		return nil, err
	}
	var rows []extrasRow
	for _, e := range cat.Entries {
		if e.Hidden {
			continue
		}
		s := st[e.ID]
		rows = append(rows, extrasRow{e.ID, e.Name, e.Category, string(s.State), s.Source, s.Reason})
	}
	return rows, nil
}

func extrasList(c usageCaller, category string, asJSON bool, out, errOut io.Writer) int {
	rows, err := extrasRows(c)
	if err != nil {
		return extrasErr(errOut, err)
	}
	var shown []extrasRow
	for _, r := range rows {
		if category == "" || r.Category == category {
			shown = append(shown, r)
		}
	}
	if asJSON {
		_ = printJSON(out, shown, nil)
		return 0
	}
	w := tabwriter.NewWriter(out, 0, 0, 2, ' ', 0)
	fmt.Fprintln(w, "ID\tNAME\tCATEGORY\tSTATE")
	for _, r := range shown {
		state := r.State
		if r.Reason != "" {
			state += " (" + r.Reason + ")"
		}
		fmt.Fprintf(w, "%s\t%s\t%s\t%s\n", r.ID, r.Name, r.Category, state)
	}
	_ = w.Flush()
	return 0
}

func extrasStatus(c usageCaller, id string, asJSON bool, out, errOut io.Writer) int {
	rows, err := extrasRows(c)
	if err != nil {
		return extrasErr(errOut, err)
	}
	for _, r := range rows {
		if r.ID != id {
			continue
		}
		if asJSON {
			_ = printJSON(out, r, nil)
			return 0
		}
		fmt.Fprintf(out, "%s: %s", r.ID, r.State)
		if r.Source != "" {
			fmt.Fprintf(out, " (via %s)", r.Source)
		}
		if r.Reason != "" {
			fmt.Fprintf(out, " [%s]", r.Reason)
		}
		fmt.Fprintln(out)
		return 0
	}
	fmt.Fprintf(errOut, "Error: unknown entry %q\n", id)
	return 1
}

// extrasInstall queues ids and streams the jobs' progress until they end.
func extrasInstall(c extrasClient, ids []string, yesMultilib bool, out, errOut io.Writer) int {
	events := make(chan extras.Progress, 256)
	stop, err := c.Watch(func(name string, data json.RawMessage) bool {
		var p extras.Progress
		if name == "extras.progress" && json.Unmarshal(data, &p) == nil {
			events <- p
		}
		return false
	})
	if err != nil {
		return extrasErr(errOut, err)
	}
	defer stop()
	raw, err := c.Call("extras.install", map[string]any{"ids": ids, "confirmMultilib": yesMultilib})
	if err != nil {
		return extrasErr(errOut, err)
	}
	var res struct {
		Jobs []struct {
			ID      string   `json:"id"`
			Kind    string   `json:"kind"`
			Entries []string `json:"entries"`
		} `json:"jobs"`
	}
	if err := json.Unmarshal(raw, &res); err != nil {
		return extrasErr(errOut, err)
	}
	if len(res.Jobs) == 0 {
		fmt.Fprintln(out, "Nothing to install (already installed).")
		return 0
	}
	open := map[string]bool{}
	for _, j := range res.Jobs {
		open[j.ID] = true
		fmt.Fprintf(out, "queued %s: %s\n", j.ID, strings.Join(j.Entries, " "))
	}
	return extrasFollow(c, open, events, out, errOut)
}

func extrasFollow(c usageCaller, open map[string]bool, events <-chan extras.Progress, out, errOut io.Writer) int {
	code := 0
	last := map[string]string{}
	quiet := time.NewTimer(10 * time.Second)
	for len(open) > 0 {
		select {
		case p := <-events:
			if !open[p.Job] {
				continue
			}
			quiet.Reset(10 * time.Second)
			switch p.State {
			case extras.JobDone:
				fmt.Fprintf(out, "%s: done\n", p.Job)
				delete(open, p.Job)
			case extras.JobFailed, extras.JobCancelled:
				fmt.Fprintf(errOut, "%s: %s (%s)\n", p.Job, p.State, p.Reason)
				delete(open, p.Job)
				code = 1
			case extras.JobRunning:
				line := fmt.Sprintf("%3d%% %s", max(p.Percent, 0), p.Phase)
				if p.Percent < 0 {
					line = "     " + p.Phase
				}
				if line != last[p.Job] && strings.TrimSpace(line) != "" {
					last[p.Job] = line
					fmt.Fprintf(out, "%s: %s\n", p.Job, line)
				}
			}
		case <-quiet.C:
			// A missed terminal event must not hang the CLI: stop when the
			// daemon reports nothing installing any more.
			quiet.Reset(10 * time.Second)
			raw, err := c.Call("extras.status", nil)
			if err != nil {
				return extrasErr(errOut, err)
			}
			var st map[string]extras.Status
			if json.Unmarshal(raw, &st) == nil && !anyInstalling(st) {
				return code
			}
		}
	}
	return code
}

func anyInstalling(st map[string]extras.Status) bool {
	for _, s := range st {
		if s.State == extras.StateInstalling {
			return true
		}
	}
	return false
}
