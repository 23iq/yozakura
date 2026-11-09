package compositor

import (
	"strings"

	"yozakura/backend/pkg/brand"
)

// directTerminal turns the stock "open terminal" bind (`<app> run
// terminal`, the default Super+T) into an exec of the configured terminal
// (general.terminal, sent by the shell as Input.Terminal), so the key
// still opens a terminal while the shell or its daemon is down. The shell
// opens it the same way (TerminalService.open: the binary, no arguments).
// Any other exec line, a user's own terminal command included, is kept;
// without a terminal (older shells) the bind is unchanged too.
func directTerminal(r *Resolved, terminal string) *Resolved {
	terminal = strings.TrimSpace(terminal)
	if r == nil || terminal == "" || r.Dispatcher != "exec" || strings.TrimSpace(r.Argument) != brand.Command("run", "terminal") {
		return r
	}
	out := *r
	out.Argument = shellWord(terminal)
	return &out
}
