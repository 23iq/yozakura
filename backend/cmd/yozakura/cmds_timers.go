package main

import (
	"encoding/json"
	"fmt"
	"io"
	"strings"
	"time"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/svc/timers"
)

const timerUsage = `Usage: {bin} timer <time> [name]          Start a countdown ("10m tea", "1h30", "25", "18:00")
       {bin} timer list [--json]               Timers, stopwatch and reminders
       {bin} timer pause|resume|reset|cancel [id|name]
       {bin} timer add <id|name> <time>        Add time ("5m"; "-1m" removes; snoozes a ringing one)
       {bin} timer stop [id|name]              Stop ringing timers (all without an id)
       {bin} timer pomodoro [work] [break]     Pomodoro (defaults: system.pomodoro settings)
       {bin} stopwatch [start|pause|resume|toggle|lap|reset|status] [--json]
       {bin} remind <time|in time> <text>      Reminder ("18:00 call mom", "in 20m stretch")
       {bin} remind list | cancel <id|text>

Times: "10m", "1h30", "1h30m", "90s", "25" (minutes), "1:30:00"; clock
times "18:00", "7:30pm" (next occurrence). The id may be omitted when only
one timer exists. Timers live in the running shell's daemon and survive restarts.
`

// timerCaller calls the daemon's timers service (tests fake it).
type timerCaller func(method string, params any) (json.RawMessage, error)

func defaultTimerCaller(method string, params any) (json.RawMessage, error) {
	if !isAlive() {
		return nil, fmt.Errorf("%s is not running", brand.DisplayName)
	}
	return newClient().Call("timers."+method, params)
}

func runTimer(args []string, out, errOut io.Writer) int {
	return runTimerWith(defaultTimerCaller, args, out, errOut)
}

func runStopwatch(args []string, out, errOut io.Writer) int {
	return runStopwatchWith(defaultTimerCaller, args, out, errOut)
}

func runRemind(args []string, out, errOut io.Writer) int {
	return runRemindWith(defaultTimerCaller, args, out, errOut)
}

func timerFail(errOut io.Writer, err error) int {
	fmt.Fprintf(errOut, "Error: %v\n", err)
	return 1
}

func timerUsageErr(errOut io.Writer) int {
	fmt.Fprint(errOut, branded(timerUsage))
	return 2
}

func runTimerWith(call timerCaller, args []string, out, errOut io.Writer) int {
	if len(args) == 0 || args[0] == "help" || args[0] == "--help" || args[0] == "-h" {
		return timerUsageErr(errOut)
	}
	var res struct{ Timer timers.Timer }
	switch sub := args[0]; sub {
	case "list", "ls":
		return printTimerList(call, len(args) > 1 && args[1] == "--json", out, errOut)
	case "pause", "resume", "reset", "cancel":
		raw, err := call(sub, map[string]any{"id": strings.Join(args[1:], " ")})
		if err != nil {
			return timerFail(errOut, err)
		}
		_ = json.Unmarshal(raw, &res)
		fmt.Fprintf(out, "%s: %s\n", timerLine(res.Timer), map[string]string{"pause": "paused", "resume": "resumed",
			"reset": "reset", "cancel": "cancelled"}[sub])
		return 0
	case "stop", "dismiss":
		raw, err := call("dismiss", map[string]any{"id": strings.Join(args[1:], " ")})
		if err != nil {
			return timerFail(errOut, err)
		}
		var r struct{ Dismissed int }
		_ = json.Unmarshal(raw, &r)
		fmt.Fprintf(out, "Stopped %d timer(s)\n", r.Dismissed)
		return 0
	case "add":
		if len(args) < 3 {
			return timerUsageErr(errOut)
		}
		raw, err := call("add", map[string]any{"id": args[1], "spec": strings.Join(args[2:], " ")})
		if err != nil {
			return timerFail(errOut, err)
		}
		_ = json.Unmarshal(raw, &res)
		fmt.Fprintln(out, timerLine(res.Timer))
		return 0
	case "pomodoro", "pomo":
		p := map[string]any{}
		if len(args) > 1 {
			p["work"] = args[1]
		}
		if len(args) > 2 {
			p["break"] = args[2]
		}
		raw, err := call("pomodoro", p)
		if err != nil {
			return timerFail(errOut, err)
		}
		_ = json.Unmarshal(raw, &res)
		fmt.Fprintf(out, "Started %s\n", timerLine(res.Timer))
		return 0
	}
	text := strings.Join(args, " ")
	text = strings.TrimPrefix(text, "start ")
	_, name, err := timers.SplitSpec(text, time.Now())
	if err != nil {
		return timerFail(errOut, fmt.Errorf("%v (try \"10m\", \"1h30\", \"18:00\")", err))
	}
	spec := strings.TrimSpace(strings.TrimSuffix(text, name))
	raw, err := call("start", map[string]any{"spec": spec, "name": name})
	if err != nil {
		return timerFail(errOut, err)
	}
	_ = json.Unmarshal(raw, &res)
	fmt.Fprintf(out, "Started %s\n", timerLine(res.Timer))
	return 0
}

// timerLine renders `t3 "tea" 9:59 left (ends 14:32)`.
func timerLine(t timers.Timer) string {
	s := t.ID
	if t.Name != "" {
		s += fmt.Sprintf(" %q", t.Name)
	}
	left := timers.FormatClock(time.Duration(t.LeftMs) * time.Millisecond)
	switch t.State {
	case timers.StateRunning:
		s += " " + left + " left"
		if t.EndsAt > 0 {
			s += " (ends " + time.UnixMilli(t.EndsAt).Format("15:04") + ")"
		}
	case timers.StatePaused:
		s += " paused at " + left
	case timers.StateRinging:
		s += " ringing"
	}
	if p := t.Pomodoro; p != nil {
		s += fmt.Sprintf(" [%s, round %d]", p.Phase, p.Round)
	}
	return s
}

func printTimerList(call timerCaller, asJSON bool, out, errOut io.Writer) int {
	raw, err := call("list", nil)
	if err != nil {
		return timerFail(errOut, err)
	}
	if asJSON {
		fmt.Fprintln(out, string(raw))
		return 0
	}
	var v timers.View
	if err := json.Unmarshal(raw, &v); err != nil {
		return timerFail(errOut, err)
	}
	if len(v.Timers) == 0 && len(v.Reminders) == 0 && v.Stopwatch.State == timers.SWIdle {
		fmt.Fprintln(out, "No timers, reminders or stopwatch running")
		return 0
	}
	for _, t := range v.Timers {
		fmt.Fprintln(out, timerLine(t))
	}
	if v.Stopwatch.State != timers.SWIdle {
		fmt.Fprintln(out, stopwatchLine(v.Stopwatch))
	}
	for _, r := range v.Reminders {
		fmt.Fprintln(out, reminderLine(r))
	}
	return 0
}

func stopwatchLine(sw timers.Stopwatch) string {
	s := fmt.Sprintf("stopwatch %s %s", sw.State, timers.FormatClock(time.Duration(sw.ElapsedMs)*time.Millisecond))
	if n := len(sw.Laps); n > 0 {
		s += fmt.Sprintf(" (%d laps)", n)
	}
	return s
}

func reminderLine(r timers.Reminder) string {
	s := r.ID + " at " + time.UnixMilli(r.At).Format("Mon 15:04")
	if r.Message != "" {
		s += ": " + r.Message
	}
	return s
}

func runStopwatchWith(call timerCaller, args []string, out, errOut io.Writer) int {
	action, asJSON := "status", false
	for _, a := range args {
		switch a {
		case "--json":
			asJSON = true
		case "help", "--help", "-h":
			return timerUsageErr(errOut)
		default:
			action = a
		}
	}
	raw, err := call("stopwatch", map[string]any{"action": action})
	if err != nil {
		return timerFail(errOut, err)
	}
	var res struct{ Stopwatch timers.Stopwatch }
	if err := json.Unmarshal(raw, &res); err != nil {
		return timerFail(errOut, err)
	}
	if asJSON {
		data, _ := json.Marshal(res.Stopwatch)
		fmt.Fprintln(out, string(data))
		return 0
	}
	fmt.Fprintln(out, stopwatchLine(res.Stopwatch))
	if action == "lap" || action == "status" {
		for _, l := range res.Stopwatch.Laps {
			fmt.Fprintf(out, "  lap %d  %s  (+%s)\n", l.N, timers.FormatClock(time.Duration(l.TotalMs)*time.Millisecond),
				timers.FormatClock(time.Duration(l.SplitMs)*time.Millisecond))
		}
	}
	return 0
}

func runRemindWith(call timerCaller, args []string, out, errOut io.Writer) int {
	if len(args) == 0 || args[0] == "help" || args[0] == "--help" || args[0] == "-h" {
		return timerUsageErr(errOut)
	}
	switch args[0] {
	case "list", "ls":
		raw, err := call("list", nil)
		if err != nil {
			return timerFail(errOut, err)
		}
		var v timers.View
		_ = json.Unmarshal(raw, &v)
		if len(v.Reminders) == 0 {
			fmt.Fprintln(out, "No reminders")
		}
		for _, r := range v.Reminders {
			fmt.Fprintln(out, reminderLine(r))
		}
		return 0
	case "cancel", "rm":
		if len(args) < 2 {
			return timerUsageErr(errOut)
		}
		raw, err := call("reminderCancel", map[string]any{"id": strings.Join(args[1:], " ")})
		if err != nil {
			return timerFail(errOut, err)
		}
		var res struct{ Reminder timers.Reminder }
		_ = json.Unmarshal(raw, &res)
		fmt.Fprintf(out, "Cancelled %s\n", reminderLine(res.Reminder))
		return 0
	}
	text := strings.Join(args, " ")
	_, msg, err := timers.SplitSpec(text, time.Now())
	if err != nil {
		return timerFail(errOut, fmt.Errorf("%v (try \"18:00\", \"in 20m\")", err))
	}
	when := strings.TrimSpace(strings.TrimSuffix(text, msg))
	raw, err := call("reminderAdd", map[string]any{"when": when, "message": msg})
	if err != nil {
		return timerFail(errOut, err)
	}
	var res struct{ Reminder timers.Reminder }
	_ = json.Unmarshal(raw, &res)
	fmt.Fprintf(out, "Reminder %s\n", reminderLine(res.Reminder))
	return 0
}
