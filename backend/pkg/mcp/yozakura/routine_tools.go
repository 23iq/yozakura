package yozakura

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	"yozakura/backend/pkg/mcp"
	"yozakura/backend/pkg/svc/routines"
)

// Routine tools manage the daemon's routines (svc/routines): saved,
// deterministic step lists the user runs from a keybind, the launcher or
// an automation, without a model.

const routineStepSchema = `{"type":"object","properties":{"kind":{"type":"string","enum":["action","tool","delay"]},"action":{"type":"string","description":"Bind action id (kind action), e.g. \"media.play-pause\", \"apps.launch\", \"workspace.switch\" — find ids with binds_search."},"tool":{"type":"string","description":"Yozakura tool name (kind tool), e.g. \"dnd_set\", \"volume_set\", \"timer_start\"."},"args":{"type":"object","description":"Arguments of the action (e.g. {\"app\":\"firefox\"}) or the tool."},"ms":{"type":"integer","minimum":1,"maximum":600000,"description":"Delay length (kind delay)."}},"required":["kind"],"additionalProperties":false}`

func routineTools(d Deps) []mcp.ToolDef {
	return []mcp.ToolDef{
		define("routines_list", "List routines",
			`List the user's saved routines: id, name, icon and steps (kind action = a keybind action {action, args}; kind tool = a Yozakura tool {tool, args}; kind delay = wait {ms}). Routines run deterministically from a keybind, the launcher, an automation or routine_run.`,
			noArgs, toolOpts{readOnly: true}, d.routinesList),
		define("routine_run", "Run routine",
			`Run a saved routine by id or name and return a per-step report (status ok/failed/skipped, output, error). A failed step stops the routine unless it was saved with continueOnError. A routine that closes windows, edits keybinds or runs a command line asks the user first.`,
			`{"type":"object","properties":{"id":{"type":"string","description":"Routine id or name."}},"required":["id"],"additionalProperties":false}`,
			toolOpts{}, d.routineRun),
		define("routine_save", "Save routine",
			`Create or update a routine — use it when the user says "save this as a routine" or wants one keypress to do several things. Steps run in order: {"kind":"action","action":"<bind action id>","args":{...}} (ids from binds_search), {"kind":"tool","tool":"<yozakura tool>","args":{...}} (any tool of this server except the routine ones) and {"kind":"delay","ms":2000}. Prefer tool steps for things tools do (dnd_set, volume_set, timer_start, wallpaper_set, app_launch); action steps for shell panels and window/workspace actions. Give "id" of an existing routine to replace it. Returns the routine and an undo. Offer to bind it afterwards (binds_set with action {"id":"utilities.routine","args":{"routine":"<id>"}}).`,
			`{"type":"object","properties":{"id":{"type":"string","description":"Existing routine to replace; omit for a new one."},"name":{"type":"string"},"icon":{"type":"string","description":"Phosphor icon name, e.g. \"sun\", \"moon\", \"briefcase\", \"lightning\"."},"keywords":{"type":"string","description":"Extra search words (launcher, binds_search)."},"continueOnError":{"type":"boolean","default":false},"steps":{"type":"array","items":`+routineStepSchema+`,"minItems":1,"maxItems":40}},"required":["name","steps"],"additionalProperties":false}`,
			toolOpts{idempotent: true}, d.routineSave),
		define("routine_delete", "Delete routine",
			`Delete a saved routine by id or name (binds that run it stop working). Always confirm with the user first. Returns an undo that restores it.`,
			`{"type":"object","properties":{"id":{"type":"string","description":"Routine id or name."}},"required":["id"],"additionalProperties":false}`,
			toolOpts{destructive: true, idempotent: true}, d.routineDelete),
	}
}

func (d Deps) routinesCall(method string, params, out any) error {
	raw, err := d.call("routines."+method, params)
	if err != nil {
		return err
	}
	if out == nil {
		return nil
	}
	return json.Unmarshal(raw, out)
}

func routineOut(r routines.Routine) map[string]any {
	steps := make([]map[string]any, 0, len(r.Steps))
	for _, s := range r.Steps {
		m := map[string]any{"kind": s.Kind, "label": routines.StepLabel(s)}
		switch s.Kind {
		case routines.KindAction:
			m["action"] = s.Action
		case routines.KindTool:
			m["tool"] = s.Tool
		case routines.KindDelay:
			m["ms"] = s.Ms
		}
		if len(s.Args) > 0 {
			m["args"] = s.Args
		}
		steps = append(steps, m)
	}
	out := map[string]any{"id": r.ID, "name": r.Name, "icon": r.Icon, "steps": steps}
	if r.Keywords != "" {
		out["keywords"] = r.Keywords
	}
	if r.ContinueOnError {
		out["continueOnError"] = true
	}
	return out
}

// routineArgs is a routine as routine_save takes it (also its undo).
func routineArgs(r routines.Routine) map[string]any {
	steps := make([]any, 0, len(r.Steps))
	for _, s := range r.Steps {
		steps = append(steps, s)
	}
	m := map[string]any{"id": r.ID, "name": r.Name, "icon": r.Icon, "steps": steps}
	if r.Keywords != "" {
		m["keywords"] = r.Keywords
	}
	if r.ContinueOnError {
		m["continueOnError"] = true
	}
	return m
}

func (d Deps) routinesList(_ context.Context, _ json.RawMessage) (*mcp.CallToolResult, error) {
	var res struct{ Routines []routines.Routine }
	if err := d.routinesCall("list", nil, &res); err != nil {
		return nil, err
	}
	out := make([]map[string]any, 0, len(res.Routines))
	for _, r := range res.Routines {
		out = append(out, routineOut(r))
	}
	return mcp.JSONResult(map[string]any{"routines": out}), nil
}

func (d Deps) routineRun(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ ID string }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	if strings.TrimSpace(a.ID) == "" {
		return nil, fmt.Errorf("id is required (see routines_list)")
	}
	var rep routines.Report
	if err := d.routinesCall("run", map[string]any{"id": a.ID, "quiet": true, "agent": true}, &rep); err != nil {
		return nil, err
	}
	res := mcp.JSONResult(rep)
	res.IsError = !rep.OK
	return res, nil
}

func (d Deps) routineSave(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var r routines.Routine
	if err := decode(args, &r); err != nil {
		return nil, err
	}
	if _, err := routines.Normalize(r); err != nil {
		return nil, err
	}
	params := map[string]any{"routine": r}
	if r.ID != "" {
		params["replace"] = r.ID
	}
	var res struct {
		Routine  routines.Routine
		Previous *routines.Routine
	}
	if err := d.routinesCall("save", params, &res); err != nil {
		return nil, err
	}
	out := map[string]any{"routine": routineOut(res.Routine),
		"bindAction": map[string]any{"id": routines.RoutineAction, "args": map[string]any{"routine": res.Routine.ID}}}
	if res.Previous != nil {
		out["undo"] = undo("routine_save", routineArgs(*res.Previous))
	} else {
		out["undo"] = undo("routine_delete", map[string]any{"id": res.Routine.ID})
	}
	return mcp.JSONResult(out), nil
}

func (d Deps) routineDelete(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ ID string }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	var res struct{ Routine routines.Routine }
	if err := d.routinesCall("delete", map[string]any{"id": a.ID}, &res); err != nil {
		return nil, err
	}
	return mcp.JSONResult(map[string]any{"deleted": res.Routine.ID, "name": res.Routine.Name,
		"undo": undo("routine_save", routineArgs(res.Routine))}), nil
}
