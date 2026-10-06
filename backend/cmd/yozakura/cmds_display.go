package main

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"strconv"
	"strings"
	"text/tabwriter"
	"time"

	"yozakura/backend/pkg/mcp/yozakura"
	yipc "yozakura/backend/pkg/yozd/ipc"
)

const displayHelp = `Usage: {bin} display [list] [--json]
       {bin} display set <name> [--mode WxH[@HZ]|preferred] [--scale N]
                         [--rotate 0|90|180|270|0-7] [--vrr off|on|fullscreen]
                         [--pos XxY] [--enable|--disable] [--yes] [--json]
       {bin} display identify

Monitors. list shows each connector with its mode, scale and position. set
changes one monitor live and asks to keep it: unless you answer y within 15
seconds (or pass --yes) the change is reverted, so a bad mode never sticks.
Without a terminal and without --yes the change is reverted after the
timeout. A kept change is saved as the monitor layout (displays.monitors)
by the running backend.
`

// displayEnv holds the side effects of `display`, injectable for tests.
type displayEnv struct {
	c       usageCaller
	confirm func(prompt string, timeout time.Duration) (keep, answered bool)
	sleep   func(time.Duration)
	tty     bool
}

func defaultDisplayEnv(in io.Reader, out io.Writer) displayEnv {
	tty := isTerminal(out) && isTerminalFile(in)
	return displayEnv{
		c: newClient(),
		confirm: func(prompt string, timeout time.Duration) (bool, bool) {
			fmt.Fprint(out, prompt)
			line := make(chan string, 1)
			go func() {
				s, _ := bufio.NewReader(in).ReadString('\n')
				line <- s
			}()
			select {
			case s := <-line:
				a := strings.ToLower(strings.TrimSpace(s))
				return a == "y" || a == "yes", true
			case <-time.After(timeout):
				fmt.Fprintln(out)
				return false, false
			}
		},
		sleep: time.Sleep,
		tty:   tty,
	}
}

func isTerminalFile(r io.Reader) bool {
	f, ok := r.(*os.File)
	if !ok {
		return false
	}
	info, err := f.Stat()
	return err == nil && info.Mode()&os.ModeCharDevice != 0
}

// runDisplay implements `yozakura display ...`.
func runDisplay(args []string, env displayEnv, out, errOut io.Writer) int {
	a := parseCLI(args, []string{"json", "yes", "y", "enable", "disable", "help", "h"},
		[]string{"mode", "scale", "rotate", "transform", "vrr", "pos"})
	if a.has("help") || a.has("h") || (len(a.pos) > 0 && a.pos[0] == "help") {
		fmt.Fprint(out, branded(displayHelp))
		return 0
	}
	sub, rest := "list", a.pos
	if len(rest) > 0 {
		sub, rest = rest[0], rest[1:]
	}
	var err error
	switch {
	case sub == "list" && len(rest) == 0:
		err = displayList(env, a.has("json"), out)
	case sub == "identify" && len(rest) == 0:
		_, err = env.c.Call("displays.identify", nil)
	case sub == "set" && len(rest) == 1:
		return displaySet(env, rest[0], a, out, errOut)
	default:
		fmt.Fprintf(errOut, "Error: unknown arguments %q\n", strings.Join(append([]string{sub}, rest...), " "))
		fmt.Fprint(errOut, branded(displayHelp))
		return 2
	}
	if err != nil {
		fmt.Fprintf(errOut, "Error: %v (is the shell running?)\n", err)
		return 1
	}
	return 0
}

func displayList(env displayEnv, asJSON bool, out io.Writer) error {
	outs, err := yozakura.ListOutputs(env.c)
	if err != nil {
		return err
	}
	if asJSON {
		return printJSON(out, outs, nil)
	}
	if len(outs) == 0 {
		fmt.Fprintln(out, "No monitors.")
		return nil
	}
	w := tabwriter.NewWriter(out, 0, 0, 2, ' ', 0)
	fmt.Fprintln(w, "NAME\tMODE\tSCALE\tPOSITION\tROTATION\tVRR\tMODEL")
	for _, o := range outs {
		mode := fmt.Sprintf("%dx%d@%s", o.Width, o.Height, strconv.FormatFloat(float64(int(o.Refresh*100+0.5))/100, 'f', -1, 64))
		if !o.Enabled {
			mode = "disabled"
		}
		vrr := "off"
		if o.VRR {
			vrr = "on"
		}
		fmt.Fprintf(w, "%s\t%s\t%s\t%d,%d\t%d\t%s\t%s\n", o.Name, mode,
			strconv.FormatFloat(o.Scale, 'f', -1, 64), o.X, o.Y, o.Transform*90%360, vrr, strings.TrimSpace(o.Make+" "+o.Model))
	}
	return w.Flush()
}

// parseDisplayChange turns the set flags into an OutputChange.
func parseDisplayChange(name string, a cliArgs) (yozakura.OutputChange, error) {
	ch := yozakura.OutputChange{Name: name}
	if v, ok := a.value("mode"); ok {
		ch.Mode = v
	}
	if v, ok := a.value("scale"); ok {
		f, err := strconv.ParseFloat(v, 64)
		if err != nil {
			return ch, fmt.Errorf("--scale %q is not a number", v)
		}
		ch.Scale = &f
	}
	rot, ok := a.value("rotate")
	if !ok {
		rot, ok = a.value("transform")
	}
	if ok {
		t, err := parseTransform(rot)
		if err != nil {
			return ch, err
		}
		ch.Transform = &t
	}
	if v, ok := a.value("vrr"); ok {
		n, err := parseVRR(v)
		if err != nil {
			return ch, err
		}
		ch.VRR = &n
	}
	if v, ok := a.value("pos"); ok {
		xs, ys, found := strings.Cut(strings.ReplaceAll(v, ",", "x"), "x")
		x, e1 := strconv.Atoi(xs)
		y, e2 := strconv.Atoi(ys)
		if !found || e1 != nil || e2 != nil {
			return ch, fmt.Errorf("--pos %q: use XxY, e.g. 1920x0", v)
		}
		ch.X, ch.Y = &x, &y
	}
	switch {
	case a.has("enable") && a.has("disable"):
		return ch, fmt.Errorf("--enable and --disable together")
	case a.has("enable"), a.has("disable"):
		en := a.has("enable")
		ch.Enabled = &en
	}
	return ch, nil
}

func parseTransform(s string) (int, error) {
	switch strings.ToLower(s) {
	case "normal", "0":
		return 0, nil
	case "90":
		return 1, nil
	case "180":
		return 2, nil
	case "270":
		return 3, nil
	}
	n, err := strconv.Atoi(s)
	if err != nil || n < 0 || n > 7 {
		return 0, fmt.Errorf("--rotate %q: use 0, 90, 180, 270 or a transform 0-7", s)
	}
	return n, nil
}

func parseVRR(s string) (int, error) {
	switch strings.ToLower(s) {
	case "off", "0", "false":
		return 0, nil
	case "on", "1", "true":
		return 1, nil
	case "fullscreen", "2":
		return 2, nil
	}
	return 0, fmt.Errorf("--vrr %q: use off, on or fullscreen", s)
}

func displaySet(env displayEnv, name string, a cliArgs, out, errOut io.Writer) int {
	fail := func(err error) int {
		fmt.Fprintf(errOut, "Error: %v\n", err)
		return 1
	}
	ch, err := parseDisplayChange(name, a)
	if err != nil {
		return fail(err)
	}
	outs, err := yozakura.ListOutputs(env.c)
	if err != nil {
		return fail(fmt.Errorf("%v (is the shell running?)", err))
	}
	o, err := yozakura.FindOutput(outs, name)
	if err != nil {
		return fail(err)
	}
	cfg, err := yozakura.BuildOutputConfig(o, ch)
	if err != nil {
		return fail(err)
	}
	if cfg == yozakura.OutputConfigOf(o) {
		fmt.Fprintf(out, "%s: nothing to change\n", o.Name)
		return 0
	}
	sess, err := yozakura.StartDisplayApply(env.c, []yipc.OutputConfig{cfg})
	if err != nil {
		return fail(err)
	}
	fmt.Fprintf(out, "%s: %s scale %s (was %s scale %s)\n", o.Name, cfg.ModeString(),
		strconv.FormatFloat(cfg.Scale, 'f', -1, 64), yozakura.OutputConfigOf(o).ModeString(), strconv.FormatFloat(o.Scale, 'f', -1, 64))
	timeout := time.Duration(sess.RevertIn) * time.Second
	if timeout <= 0 {
		timeout = 15 * time.Second
	}
	keep := a.has("yes") || a.has("y")
	switch {
	case keep:
	case env.tty:
		keep, _ = env.confirm(fmt.Sprintf("Keep? (y/N, auto-revert in %d s) ", int(timeout.Seconds())), timeout)
	default:
		fmt.Fprintf(errOut, "No terminal to confirm on: reverting in %d s (use --yes to keep).\n", int(timeout.Seconds()))
		env.sleep(timeout)
	}
	if !keep {
		_ = yozakura.RevertDisplays(env.c, sess.Session) // the daemon may have reverted already
		fmt.Fprintln(out, "Reverted.")
		return 3
	}
	saved, err := yozakura.KeepDisplays(env.c, sess.Session)
	if err != nil {
		return fail(err)
	}
	if !saved {
		fmt.Fprintln(errOut, "Warning: kept, but the layout was not saved.")
	}
	fmt.Fprintln(out, "Kept.")
	return 0
}
