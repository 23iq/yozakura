package yozakura

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"yozakura/backend/pkg/mcp"
	"yozakura/backend/pkg/svc/timers"
)

// Timer tools drive the daemon's timers service (countdowns, Pomodoro,
// the stopwatch, reminders). Results that can be reverted carry
// "undo": {"tool", "args"}: calling that tool with those args undoes the
// change (the AI panel shows it as an Undo button).

func timerTools(d Deps) []mcp.ToolDef {
	return []mcp.ToolDef{
		define("timer_start", "Start timer",
			`Start a countdown timer shown in the notch; it rings with a notification (+5 min / Stop) when done. "duration" is human: "10m", "1h30", "90s", "25" (bare number = minutes) or a clock time "18:00" / "7:30pm" (counts down to it). "name" labels it ("tea"). "pomodoro": true starts a Pomodoro instead (work/break cycles; "duration" is then the work length, "break" the break length, defaults from the user's settings, else 25m/5m). Several timers can run at once. For "remind me at/in ..." with a message prefer reminder_add.`,
			`{"type":"object","properties":{"duration":{"type":"string","description":"\"10m\", \"1h30\", \"90s\", \"25\" (minutes) or a clock time \"18:00\"."},"name":{"type":"string","description":"Short label, e.g. \"tea\"."},"pomodoro":{"type":"boolean","default":false},"break":{"type":"string","description":"Pomodoro break length, e.g. \"5m\"."},"rounds":{"type":"integer","minimum":0,"description":"Pomodoro work sessions before it stops (0 = endless, default)."}},"additionalProperties":false}`,
			toolOpts{}, d.timerStart),
		define("timer_list", "List timers",
			`List the running/paused/ringing timers (id, name, state, time left as "4:59" and seconds, end time), the stopwatch (state, elapsed, laps) and pending reminders (id, message, time). Call it first to find ids for timer_control or reminder_cancel.`,
			noArgs, toolOpts{readOnly: true}, d.timerList),
		define("timer_control", "Control timer",
			`Change one timer. "id" is the timer id ("t3") or its name; it may be omitted when only one timer exists. "action": pause | resume | add (needs "amount", e.g. "5m", "-1m"; on a ringing timer it snoozes) | reset (start the current run over) | cancel (delete it) | dismiss (stop a ringing timer; without id stops all ringing ones).`,
			`{"type":"object","properties":{"id":{"type":"string","description":"Timer id or name."},"action":{"type":"string","enum":["pause","resume","add","reset","cancel","dismiss"]},"amount":{"type":"string","description":"For add: \"5m\", \"30s\", \"-2m\"."}},"required":["action"],"additionalProperties":false}`,
			toolOpts{}, d.timerControl),
		define("stopwatch_control", "Control stopwatch",
			`Drive the single stopwatch: start | pause | resume | toggle | lap (records a lap with total and split) | reset | status. Returns state, elapsed ("1:02:03" and ms) and laps.`,
			`{"type":"object","properties":{"action":{"type":"string","enum":["start","pause","resume","toggle","lap","reset","status"]}},"required":["action"],"additionalProperties":false}`,
			toolOpts{}, d.stopwatchControl),
		define("reminder_add", "Add reminder",
			`Remind the user with a notification at a wall-clock time or after a delay. "when": "18:00", "7:30pm", "at 9:15" (next occurrence: tomorrow if it has passed today), "in 20m" / "1h30" (from now) or an RFC 3339 timestamp for other days. "message" is what to remind about. Use this for alarms too (empty message).`,
			`{"type":"object","properties":{"when":{"type":"string","description":"\"18:00\", \"7:30pm\", \"in 20m\", \"1h\"."},"message":{"type":"string"}},"required":["when"],"additionalProperties":false}`,
			toolOpts{}, d.reminderAdd),
		define("reminder_list", "List reminders",
			`List pending reminders (id, message, local time, time left), soonest first.`,
			noArgs, toolOpts{readOnly: true}, d.reminderList),
		define("reminder_cancel", "Cancel reminder",
			`Delete a pending reminder by id ("r4") or by its exact message.`,
			`{"type":"object","properties":{"id":{"type":"string","description":"Reminder id or message."}},"required":["id"],"additionalProperties":false}`,
			toolOpts{destructive: true}, d.reminderCancel),
	}
}

func undo(tool string, args map[string]any) map[string]any {
	return map[string]any{"tool": tool, "args": args}
}

// timersCall calls timers.<method> and decodes the result into out.
func (d Deps) timersCall(method string, params, out any) error {
	raw, err := d.call("timers."+method, params)
	if err != nil {
		return err
	}
	if out == nil {
		return nil
	}
	return json.Unmarshal(raw, out)
}

func durText(msv int64) string { return timers.FormatClock(time.Duration(msv) * time.Millisecond) }

func timerOut(t timers.Timer) map[string]any {
	m := map[string]any{"id": t.ID, "name": t.Name, "state": t.State, "left": durText(t.LeftMs),
		"leftSeconds": t.LeftMs / 1000, "total": durText(t.TotalMs)}
	if t.State == timers.StateRunning && t.EndsAt > 0 {
		m["endsAt"] = time.UnixMilli(t.EndsAt).Format("15:04:05")
	}
	if p := t.Pomodoro; p != nil {
		m["pomodoro"] = map[string]any{"phase": p.Phase, "round": p.Round, "rounds": p.Rounds}
	}
	return m
}

func reminderOut(r timers.Reminder) map[string]any {
	return map[string]any{"id": r.ID, "message": r.Message, "at": time.UnixMilli(r.At).Format("Mon 15:04"),
		"atISO": time.UnixMilli(r.At).Format(time.RFC3339), "in": timers.FormatDuration(time.Duration(r.LeftMs) * time.Millisecond)}
}

func stopwatchOut(sw timers.Stopwatch) map[string]any {
	laps := make([]map[string]any, 0, len(sw.Laps))
	for _, l := range sw.Laps {
		laps = append(laps, map[string]any{"n": l.N, "total": durText(l.TotalMs), "split": durText(l.SplitMs)})
	}
	return map[string]any{"state": sw.State, "elapsed": durText(sw.ElapsedMs), "elapsedMs": sw.ElapsedMs, "laps": laps}
}

func (d Deps) timerStart(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct {
		Duration, Name, Break string
		Pomodoro              bool
		Rounds                int
	}
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	var res struct{ Timer timers.Timer }
	if a.Pomodoro {
		p := map[string]any{"name": a.Name, "rounds": a.Rounds}
		if a.Duration != "" {
			p["work"] = a.Duration
		}
		if a.Break != "" {
			p["break"] = a.Break
		}
		if err := d.timersCall("pomodoro", p, &res); err != nil {
			return nil, err
		}
	} else {
		if strings.TrimSpace(a.Duration) == "" {
			return nil, fmt.Errorf("duration is required (\"10m\", \"1h30\", \"18:00\")")
		}
		if err := d.timersCall("start", map[string]any{"spec": a.Duration, "name": a.Name}, &res); err != nil {
			return nil, err
		}
	}
	return mcp.JSONResult(map[string]any{"timer": timerOut(res.Timer),
		"undo": undo("timer_control", map[string]any{"id": res.Timer.ID, "action": "cancel"})}), nil
}

func (d Deps) timerList(_ context.Context, _ json.RawMessage) (*mcp.CallToolResult, error) {
	var v timers.View
	if err := d.timersCall("list", nil, &v); err != nil {
		return nil, err
	}
	ts := make([]map[string]any, 0, len(v.Timers))
	for _, t := range v.Timers {
		ts = append(ts, timerOut(t))
	}
	rs := make([]map[string]any, 0, len(v.Reminders))
	for _, r := range v.Reminders {
		rs = append(rs, reminderOut(r))
	}
	return mcp.JSONResult(map[string]any{"timers": ts, "stopwatch": stopwatchOut(v.Stopwatch), "reminders": rs}), nil
}

func (d Deps) timerControl(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ ID, Action, Amount string }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	params := map[string]any{"id": a.ID}
	switch a.Action {
	case "pause", "resume", "reset", "cancel":
	case "add":
		if strings.TrimSpace(a.Amount) == "" {
			return nil, fmt.Errorf("add needs an amount (\"5m\", \"-1m\")")
		}
		params["spec"] = a.Amount
	case "dismiss":
		var r struct{ Dismissed int }
		if err := d.timersCall("dismiss", params, &r); err != nil {
			return nil, err
		}
		return mcp.JSONResult(map[string]any{"dismissed": r.Dismissed}), nil
	default:
		return nil, fmt.Errorf("unknown action %q", a.Action)
	}
	var res struct {
		Timer        timers.Timer
		AddedSeconds float64
	}
	if err := d.timersCall(a.Action, params, &res); err != nil {
		return nil, err
	}
	out := map[string]any{"timer": timerOut(res.Timer)}
	id := res.Timer.ID
	switch a.Action {
	case "pause":
		out["undo"] = undo("timer_control", map[string]any{"id": id, "action": "resume"})
	case "resume":
		out["undo"] = undo("timer_control", map[string]any{"id": id, "action": "pause"})
	case "add":
		if res.Timer.State != timers.StateRinging {
			out["undo"] = undo("timer_control", map[string]any{"id": id, "action": "add",
				"amount": fmt.Sprintf("%ds", -int64(res.AddedSeconds))})
		}
	case "cancel":
		if left := res.Timer.LeftMs / 1000; left > 0 {
			out["undo"] = undo("timer_start", map[string]any{"duration": fmt.Sprintf("%ds", left), "name": res.Timer.Name})
		}
	}
	return mcp.JSONResult(out), nil
}

func (d Deps) stopwatchControl(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ Action string }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	var res struct{ Stopwatch, Previous timers.Stopwatch }
	if err := d.timersCall("stopwatch", map[string]any{"action": a.Action}, &res); err != nil {
		return nil, err
	}
	out := map[string]any{"stopwatch": stopwatchOut(res.Stopwatch)}
	prev := res.Previous.State
	switch {
	case a.Action == "start" && prev == timers.SWIdle:
		out["undo"] = undo("stopwatch_control", map[string]any{"action": "reset"})
	case res.Stopwatch.State != prev && res.Stopwatch.State == timers.SWPaused:
		out["undo"] = undo("stopwatch_control", map[string]any{"action": "resume"})
	case res.Stopwatch.State != prev && prev == timers.SWPaused && res.Stopwatch.State == timers.SWRunning:
		out["undo"] = undo("stopwatch_control", map[string]any{"action": "pause"})
	}
	return mcp.JSONResult(out), nil
}

func (d Deps) reminderAdd(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ When, Message string }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	if strings.TrimSpace(a.When) == "" {
		return nil, fmt.Errorf("when is required (\"18:00\", \"in 20m\")")
	}
	params := map[string]any{"when": a.When, "message": a.Message}
	if at, err := time.Parse(time.RFC3339, strings.TrimSpace(a.When)); err == nil {
		params = map[string]any{"at": at.UnixMilli(), "message": a.Message}
	}
	var res struct{ Reminder timers.Reminder }
	if err := d.timersCall("reminderAdd", params, &res); err != nil {
		return nil, err
	}
	return mcp.JSONResult(map[string]any{"reminder": reminderOut(res.Reminder),
		"undo": undo("reminder_cancel", map[string]any{"id": res.Reminder.ID})}), nil
}

func (d Deps) reminderList(_ context.Context, _ json.RawMessage) (*mcp.CallToolResult, error) {
	var v timers.View
	if err := d.timersCall("list", nil, &v); err != nil {
		return nil, err
	}
	rs := make([]map[string]any, 0, len(v.Reminders))
	for _, r := range v.Reminders {
		rs = append(rs, reminderOut(r))
	}
	return mcp.JSONResult(map[string]any{"reminders": rs}), nil
}

func (d Deps) reminderCancel(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ ID string }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	var res struct{ Reminder timers.Reminder }
	if err := d.timersCall("reminderCancel", map[string]any{"id": a.ID}, &res); err != nil {
		return nil, err
	}
	r := res.Reminder
	out := map[string]any{"cancelled": r.ID, "message": r.Message}
	if r.At > d.now().UnixMilli() {
		out["undo"] = undo("reminder_add", map[string]any{"when": time.UnixMilli(r.At).Format(time.RFC3339), "message": r.Message})
	}
	return mcp.JSONResult(out), nil
}
