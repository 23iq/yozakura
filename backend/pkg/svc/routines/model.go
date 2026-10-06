// Package routines stores and runs routines: named, deterministic step
// lists (bind actions, Yozakura MCP tools, delays) that a keybind, the
// launcher, an AI automation or the AI itself can run. No model is
// involved when a routine runs.
package routines

import (
	"fmt"
	"regexp"
	"strings"
)

// Step kinds.
const (
	KindAction = "action" // a bind action of the catalog ({id, args})
	KindTool   = "tool"   // a built-in MCP tool ({tool, args})
	KindDelay  = "delay"  // wait Ms milliseconds
)

// Limits keep a routine quick and bounded.
const (
	MaxSteps   = 40
	MaxDelayMs = 10 * 60 * 1000 // one delay
	MaxTotalMs = 30 * 60 * 1000 // all delays of a routine
	MaxName    = 80
)

// Step is one step of a routine.
type Step struct {
	Kind   string         `json:"kind"`
	Action string         `json:"action,omitempty"`
	Tool   string         `json:"tool,omitempty"`
	Args   map[string]any `json:"args,omitempty"`
	Ms     int            `json:"ms,omitempty"`
}

// Routine is a saved routine.
type Routine struct {
	ID       string `json:"id"`
	Name     string `json:"name"`
	Icon     string `json:"icon,omitempty"`
	Keywords string `json:"keywords,omitempty"`
	// ContinueOnError runs the remaining steps after a failed one.
	ContinueOnError bool   `json:"continueOnError,omitempty"`
	Steps           []Step `json:"steps"`
}

// File is the persisted document.
type File struct {
	Routines []Routine `json:"routines"`
}

var slugRe = regexp.MustCompile(`[^a-z0-9]+`)

// Slug turns a name into an id ("Morning start!" -> "morning-start").
func Slug(name string) string {
	s := strings.Trim(slugRe.ReplaceAllString(strings.ToLower(name), "-"), "-")
	if len(s) > 40 {
		s = strings.TrimRight(s[:40], "-")
	}
	return s
}

// unsafeTools cannot be routine steps: they edit routines themselves or
// recurse into the runner (a routine runs routines through its action).
var unsafeTools = map[string]bool{"routine_run": true, "routine_save": true, "routine_delete": true, "routines_list": true}

// Normalize validates r and fills defaults (id from the name, icon). It
// returns a copy.
func Normalize(r Routine) (Routine, error) {
	r.Name = strings.TrimSpace(r.Name)
	if r.Name == "" {
		return r, fmt.Errorf("a routine needs a name")
	}
	if len([]rune(r.Name)) > MaxName {
		r.Name = string([]rune(r.Name)[:MaxName])
	}
	r.ID = Slug(r.ID)
	if r.ID == "" {
		r.ID = Slug(r.Name)
	}
	if r.ID == "" {
		r.ID = "routine"
	}
	if r.Icon == "" {
		r.Icon = "lightning"
	}
	if len(r.Steps) > MaxSteps {
		return r, fmt.Errorf("a routine has at most %d steps", MaxSteps)
	}
	total := 0
	steps := make([]Step, 0, len(r.Steps))
	for i, s := range r.Steps {
		s.Kind = strings.TrimSpace(s.Kind)
		switch s.Kind {
		case KindAction:
			s.Action = strings.TrimSpace(s.Action)
			if s.Action == "" {
				return r, fmt.Errorf("step %d: an action step needs an action id", i+1)
			}
			s.Tool, s.Ms = "", 0
		case KindTool:
			s.Tool = strings.TrimSpace(s.Tool)
			if s.Tool == "" {
				return r, fmt.Errorf("step %d: a tool step needs a tool name", i+1)
			}
			if unsafeTools[s.Tool] {
				return r, fmt.Errorf("step %d: %s cannot run inside a routine", i+1, s.Tool)
			}
			s.Action, s.Ms = "", 0
		case KindDelay:
			if s.Ms <= 0 || s.Ms > MaxDelayMs {
				return r, fmt.Errorf("step %d: a delay is 1 ms to %d minutes", i+1, MaxDelayMs/60000)
			}
			total += s.Ms
			s.Action, s.Tool, s.Args = "", "", nil
		default:
			return r, fmt.Errorf("step %d: kind must be action, tool or delay", i+1)
		}
		steps = append(steps, s)
	}
	if total > MaxTotalMs {
		return r, fmt.Errorf("delays add up to more than %d minutes", MaxTotalMs/60000)
	}
	r.Steps = steps
	return r, nil
}

// Find returns the index of the routine whose id or (case-insensitive)
// name is ref, or -1.
func Find(list []Routine, ref string) int {
	ref = strings.TrimSpace(ref)
	for i, r := range list {
		if r.ID == ref {
			return i
		}
	}
	for i, r := range list {
		if strings.EqualFold(r.Name, ref) {
			return i
		}
	}
	if s := Slug(ref); s != "" {
		for i, r := range list {
			if r.ID == s {
				return i
			}
		}
	}
	return -1
}

// UniqueID returns id, or id-2, id-3... when another routine (not at
// index skip) already uses it.
func UniqueID(list []Routine, id string, skip int) string {
	taken := map[string]bool{}
	for i, r := range list {
		if i != skip {
			taken[r.ID] = true
		}
	}
	if !taken[id] {
		return id
	}
	for n := 2; ; n++ {
		c := fmt.Sprintf("%s-%d", id, n)
		if !taken[c] {
			return c
		}
	}
}
