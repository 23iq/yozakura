package displays

import (
	"errors"

	yipc "yozakura/backend/pkg/yozd/ipc"
)

// ErrLastOutput refuses a change that would leave no monitor showing
// anything: once kept it is saved into displays.monitors and the screen
// stays black on every login. Enforced here so the settings page, the CLI
// and the MCP tools all get it.
var ErrLastOutput = errors.New("refusing to disable the last enabled monitor")

// leavesNoOutput reports whether applying cand to the connected outputs
// disables an enabled one and leaves none enabled. A mirror shows another
// output's picture, so it does not count as one left on; outputs that are
// not connected show nothing either way.
func leavesNoOutput(current []yipc.Output, cand []yipc.OutputConfig) bool {
	want := map[string]bool{}
	for _, c := range cand {
		want[c.Name] = c.Enabled
	}
	disables, on := false, 0
	for _, o := range current {
		enabled := o.Enabled
		if w, ok := want[o.Name]; ok {
			disables = disables || (o.Enabled && !w)
			enabled = w
		}
		if enabled && o.MirrorOf == "" {
			on++
		}
	}
	return disables && on == 0
}
