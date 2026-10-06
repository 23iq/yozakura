package routines

import (
	"sort"
	"strings"
	"sync"
	"time"

	"yozakura/backend/pkg/brand"
)

// ConfirmTools are the built-in MCP tools that always ask the user, even
// with "allow for this session", a permissive policy or YOLO: they rewrite
// keybinds, close windows, delete routines and notes or install software. The agents policy
// (svc/agents) and the chat policy (modules/services/ai/Permissions.js)
// use the same list.
var ConfirmTools = map[string]bool{
	"binds_set": true, "binds_remove": true, "app_close": true, "routine_delete": true, "notes_delete": true,
	"extras_install": true, // installs software, may enable a repo and asks for root
}

// confirmActions are bind actions a routine step may run that are as
// sensitive as a confirm tool: an arbitrary command line, a raw compositor
// dispatcher, closing the focused window and quitting the shell.
var confirmActions = map[string]bool{
	"command.run": true, "legacy.dispatcher": true, "window.close": true, brand.Action("quit"): true,
}

// ConfirmSteps lists what in r needs the user's confirmation before an AI
// may run it ("app_close", "command.run", ...): confirm tools, sensitive
// actions and the same inside nested routines (lookup resolves them; an
// unknown nested routine counts as "routine <ref>"). Empty: nothing.
func ConfirmSteps(r Routine, lookup func(string) (Routine, bool)) []string {
	seen := map[string]bool{}
	visited := map[string]bool{}
	var walk func(steps []Step, depth int)
	walk = func(steps []Step, depth int) {
		for _, s := range steps {
			switch s.Kind {
			case KindTool:
				if t := strings.TrimSpace(s.Tool); ConfirmTools[t] || unsafeTools[t] {
					seen[t] = true
				}
			case KindAction:
				a := strings.TrimSpace(s.Action)
				if confirmActions[a] {
					seen[a] = true
				}
				if a != RoutineAction {
					continue
				}
				ref := argString(s.Args, "routine")
				var sub Routine
				ok := lookup != nil && depth < maxDepth
				if ok {
					sub, ok = lookup(ref)
				}
				if !ok {
					seen["routine "+ref] = true
					continue
				}
				if visited[sub.ID] {
					continue
				}
				visited[sub.ID] = true
				walk(sub.Steps, depth+1)
			}
		}
	}
	visited[r.ID] = true
	walk(r.Steps, 0)
	out := make([]string, 0, len(seen))
	for k := range seen {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}

// grantTTL bounds how long a confirmation the user gave to an AI's
// routine_run stays usable (the call follows the answer at once).
const grantTTL = 2 * time.Minute

// grants are one-shot confirmations of AI routine runs (routine id ->
// expiry), given when the user allows a routine_run that needs it.
type grants struct {
	mu  sync.Mutex
	m   map[string]time.Time
	now func() time.Time
}

func (g *grants) clock() time.Time {
	if g.now != nil {
		return g.now()
	}
	return time.Now()
}

func (g *grants) add(id string) {
	g.mu.Lock()
	defer g.mu.Unlock()
	if g.m == nil {
		g.m = map[string]time.Time{}
	}
	g.m[id] = g.clock().Add(grantTTL)
}

// take consumes the grant of id; false when there is none (or it expired).
func (g *grants) take(id string) bool {
	g.mu.Lock()
	defer g.mu.Unlock()
	exp, ok := g.m[id]
	delete(g.m, id)
	return ok && g.clock().Before(exp)
}
