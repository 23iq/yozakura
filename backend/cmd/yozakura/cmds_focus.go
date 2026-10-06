package main

import (
	"fmt"
	"io"
	"strconv"
	"time"

	"yozakura/backend/pkg/mcp/yozakura"
)

const focusHelp = `Usage: {bin} focus [status]
       {bin} focus start [minutes]
       {bin} focus stop

Focus mode: Do Not Disturb on, a countdown in the notch, notification
badges hidden; at the end the shell shows what you missed. start without
minutes uses the setting system.focus.minutes; starting again restarts it.
`

// runFocus implements `yozakura focus ...` (start/stop through ui.run like
// the bind commands, status from focus.get).
func runFocus(args []string, c usageCaller, out, errOut io.Writer) int {
	sub := "status"
	if len(args) > 0 {
		sub = args[0]
	}
	switch {
	case sub == "help" || sub == "-h" || sub == "--help":
		fmt.Fprint(out, branded(focusHelp))
		return 0
	case sub == "status" && len(args) <= 1:
		st, err := yozakura.GetFocus(c)
		if err != nil {
			fmt.Fprintf(errOut, "Error: %v (is the shell running?)\n", err)
			return 1
		}
		printFocus(st, out)
		return 0
	case sub == "start" && len(args) <= 2:
		mins := 0
		if len(args) == 2 {
			n, err := strconv.Atoi(args[1])
			if err != nil || n < 1 || n > 480 {
				fmt.Fprintf(errOut, "Error: minutes must be 1-480, got %q\n", args[1])
				return 2
			}
			mins = n
		}
		return focusCommand(c, fmt.Sprintf("focus:%d", mins), errOut)
	case sub == "stop" && len(args) == 1:
		return focusCommand(c, "focus-stop", errOut)
	}
	fmt.Fprint(errOut, branded(focusHelp))
	return 2
}

func focusCommand(c usageCaller, cmd string, errOut io.Writer) int {
	if _, err := c.Call("ui.run", map[string]any{"command": cmd}); err != nil {
		fmt.Fprintf(errOut, "Error: %v (is the shell running?)\n", err)
		return 1
	}
	return 0
}

func printFocus(st yozakura.FocusStatus, out io.Writer) {
	switch {
	case !st.Active && !st.Known:
		fmt.Fprintln(out, "Focus mode: off (not reported by the shell yet)")
	case !st.Active:
		fmt.Fprintln(out, "Focus mode: off")
	case st.Paused:
		fmt.Fprintf(out, "Focus mode: on, paused, %d min left\n", st.MinutesLeft)
	case st.EndsAt > 0:
		fmt.Fprintf(out, "Focus mode: on until %s (%d min left)\n", time.UnixMilli(st.EndsAt).Format("15:04"), st.MinutesLeft)
	default:
		fmt.Fprintln(out, "Focus mode: on")
	}
}
