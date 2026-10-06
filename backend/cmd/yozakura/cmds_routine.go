package main

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"strings"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/svc/routines"
)

const routineUsage = `Usage: {bin} routine list [--json]           Saved routines
       {bin} routine show <id|name> [--json]  Steps of one routine
       {bin} routine run <id|name> [--json]   Run it and print each step's result
       {bin} routine save <file.json|->       Create or replace a routine from JSON
       {bin} routine delete <id|name>

A routine is {"name", "icon", "steps": [{"kind":"action","action":"media.next"},
{"kind":"tool","tool":"dnd_set","args":{"enabled":true}}, {"kind":"delay","ms":2000}]}.
Bind one with the action utilities.routine {"routine": "<id>"}. Routines live in
~/.config/` + brand.AppID + `/routines.json and run in the shell's daemon.
`

// routineCaller calls the daemon's routines service (tests fake it).
type routineCaller func(method string, params any) (json.RawMessage, error)

func defaultRoutineCaller(method string, params any) (json.RawMessage, error) {
	if !isAlive() {
		return nil, fmt.Errorf("%s is not running", brand.DisplayName)
	}
	return newClient().Call("routines."+method, params)
}

func runRoutine(args []string, stdin io.Reader, out, errOut io.Writer) int {
	return runRoutineWith(defaultRoutineCaller, args, stdin, out, errOut)
}

func routineFail(errOut io.Writer, err error) int {
	fmt.Fprintf(errOut, "Error: %v\n", err)
	return 1
}

func printRoutineJSON(out io.Writer, raw json.RawMessage) int {
	var v any
	_ = json.Unmarshal(raw, &v)
	data, _ := json.MarshalIndent(v, "", "  ")
	fmt.Fprintln(out, string(data))
	return 0
}

func runRoutineWith(call routineCaller, args []string, stdin io.Reader, out, errOut io.Writer) int {
	if len(args) == 0 || args[0] == "help" || args[0] == "--help" || args[0] == "-h" {
		fmt.Fprint(errOut, branded(routineUsage))
		return 2
	}
	asJSON := false
	rest := []string{}
	for _, a := range args[1:] {
		if a == "--json" {
			asJSON = true
		} else {
			rest = append(rest, a)
		}
	}
	ref := strings.Join(rest, " ")
	switch args[0] {
	case "list", "ls":
		raw, err := call("list", nil)
		if err != nil {
			return routineFail(errOut, err)
		}
		if asJSON {
			return printRoutineJSON(out, raw)
		}
		var res struct{ Routines []routines.Routine }
		_ = json.Unmarshal(raw, &res)
		if len(res.Routines) == 0 {
			fmt.Fprintln(out, branded("No routines yet. Create one in Settings -> Routines, ask the AI, or `{bin} routine save`."))
		}
		for _, r := range res.Routines {
			fmt.Fprintf(out, "%-20s %s (%d steps)\n", r.ID, r.Name, len(r.Steps))
		}
		return 0
	case "show", "get":
		raw, err := call("get", map[string]any{"id": ref})
		if err != nil {
			return routineFail(errOut, err)
		}
		if asJSON {
			return printRoutineJSON(out, raw)
		}
		var res struct{ Routine routines.Routine }
		_ = json.Unmarshal(raw, &res)
		fmt.Fprintf(out, "%s (%s)\n", res.Routine.Name, res.Routine.ID)
		for i, s := range res.Routine.Steps {
			line := routines.StepLabel(s)
			if len(s.Args) > 0 {
				a, _ := json.Marshal(s.Args)
				line += " " + string(a)
			}
			fmt.Fprintf(out, "  %d. %s\n", i+1, line)
		}
		return 0
	case "run":
		raw, err := call("run", map[string]any{"id": ref, "quiet": true})
		if err != nil {
			return routineFail(errOut, err)
		}
		if asJSON {
			printRoutineJSON(out, raw)
		}
		var rep routines.Report
		_ = json.Unmarshal(raw, &rep)
		if !asJSON {
			for _, st := range rep.Steps {
				line := fmt.Sprintf("  %-7s %d. %s", st.Status, st.Index+1, st.Label)
				if st.Error != "" {
					line += ": " + st.Error
				}
				fmt.Fprintln(out, line)
			}
		}
		if !rep.OK {
			return 1
		}
		return 0
	case "save", "add":
		if ref == "" {
			fmt.Fprint(errOut, branded(routineUsage))
			return 2
		}
		var data []byte
		var err error
		if ref == "-" {
			data, err = io.ReadAll(stdin)
		} else {
			data, err = os.ReadFile(ref)
		}
		if err != nil {
			return routineFail(errOut, err)
		}
		var r routines.Routine
		if err := json.Unmarshal(data, &r); err != nil {
			return routineFail(errOut, fmt.Errorf("invalid routine JSON: %v", err))
		}
		params := map[string]any{"routine": r}
		if r.ID != "" {
			params["replace"] = r.ID
		}
		raw, err := call("save", params)
		if err != nil {
			return routineFail(errOut, err)
		}
		var res struct{ Routine routines.Routine }
		_ = json.Unmarshal(raw, &res)
		fmt.Fprintf(out, "Saved %s (%s)\n", res.Routine.Name, res.Routine.ID)
		return 0
	case "delete", "rm", "remove":
		raw, err := call("delete", map[string]any{"id": ref})
		if err != nil {
			return routineFail(errOut, err)
		}
		var res struct{ Routine routines.Routine }
		_ = json.Unmarshal(raw, &res)
		fmt.Fprintf(out, "Deleted %s\n", res.Routine.Name)
		return 0
	}
	fmt.Fprint(errOut, branded(routineUsage))
	return 2
}
