package main

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"strings"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/exclusive"
	exclusivesvc "yozakura/backend/pkg/svc/exclusive"
)

const exclusiveHelp = `Usage: {bin} install hyprland --exclusive [-y]
       {bin} install --restore [--from DIR] [-y]

Exclusive mode (Hyprland only) makes {name} the only shell: ~/.config/hypr is
backed up in full, your monitors and keyboard settings are imported, the
Hyprland entry becomes a minimal file that loads {name} plus a user.lua /
user.conf for personal tweaks, and other bars, notification, wallpaper, idle
and lock daemons are disabled in systemd. --restore puts the backed-up files
and the disabled units back (the newest backup, or --from DIR). Without -y it
lists what will happen and asks first.
`

// exclusiveEnv is the environment of the install flags (faked in tests).
type exclusiveEnv struct {
	opts func() exclusive.Options
	in   io.Reader
}

func defaultExclusiveEnv() exclusiveEnv {
	return exclusiveEnv{opts: exclusivesvc.Host, in: os.Stdin}
}

// installFlagsUsed reports whether args carry --exclusive or --restore.
func installFlagsUsed(args []string) bool {
	for _, a := range args {
		switch strings.SplitN(a, "=", 2)[0] {
		case "--exclusive", "-exclusive", "--restore", "-restore":
			return true
		}
	}
	return false
}

// runExclusiveInstall implements the --exclusive / --restore flags of
// `install`; it returns the exit code.
func runExclusiveInstall(args []string, env exclusiveEnv, out, errOut io.Writer) int {
	a := parseCLI(args, []string{"exclusive", "restore", "y", "yes", "help", "h"}, []string{"from"})
	if a.has("help") || a.has("h") {
		fmt.Fprint(out, branded(exclusiveHelp))
		return 0
	}
	if a.has("exclusive") && a.has("restore") {
		fmt.Fprintln(errOut, "Error: use either --exclusive or --restore, not both")
		return 2
	}
	yes := a.has("y") || a.has("yes")
	var err error
	if a.has("restore") {
		if len(a.pos) > 0 && a.pos[0] != "hyprland" {
			fmt.Fprintf(errOut, "Error: exclusive mode is only for Hyprland, not %q\n", a.pos[0])
			return 2
		}
		from, _ := a.value("from")
		err = exclusiveRestore(env, from, yes, out)
	} else {
		if len(a.pos) == 0 || a.pos[0] != "hyprland" || len(a.pos) > 1 {
			fmt.Fprintln(errOut, "Error: --exclusive is only for Hyprland: install hyprland --exclusive")
			return 2
		}
		if _, ok := a.value("from"); ok {
			fmt.Fprintln(errOut, "Error: --from belongs to --restore")
			return 2
		}
		err = exclusiveEnable(env, yes, out)
	}
	if err != nil {
		fmt.Fprintf(errOut, "Error: %v\n", err)
		return 1
	}
	return 0
}

func exclusiveEnable(env exclusiveEnv, yes bool, out io.Writer) error {
	o := env.opts()
	plan, err := exclusive.Preview(o)
	if err != nil {
		return err
	}
	if plan.AlreadyDone {
		fmt.Fprintln(out, "Exclusive mode is already active; nothing to do.")
		return nil
	}
	fmt.Fprintf(out, "Exclusive mode will:\n")
	fmt.Fprintf(out, "  - back up %s to %s/<time>/\n", plan.HyprDir, plan.BackupDir)
	fmt.Fprintf(out, "  - replace %s with a minimal file that loads %s; put your own tweaks in %s\n",
		plan.Entry, brand.DisplayName, plan.UserFile)
	listOrNone(out, "  - disable these systemd user units", plan.Units)
	listOrNone(out, "  - import these monitors", plan.Monitors)
	if plan.Keyboard != "" {
		fmt.Fprintf(out, "  - import the keyboard layouts: %s (and options, key repeat)\n", plan.Keyboard)
	}
	fmt.Fprintf(out, "  - reload Hyprland; on a config error everything is put back\n")
	if !confirm(env.in, out, yes) {
		fmt.Fprintln(out, "Aborted; nothing changed.")
		return nil
	}
	st, err := exclusive.Enable(o)
	if err != nil {
		return err
	}
	fmt.Fprintf(out, "Exclusive mode is on. Backup: %s\n", st.Backup)
	if st.Reason != "" {
		fmt.Fprintf(out, "Note: %s\n", st.Reason)
	}
	fmt.Fprintf(out, "Undo it with: %s install --restore\n", brand.AppID)
	return nil
}

func exclusiveRestore(env exclusiveEnv, from string, yes bool, out io.Writer) error {
	o := env.opts()
	st := exclusive.GetStatus(o)
	if from == "" && !st.Active {
		return exclusive.ErrNotActive
	}
	backup := st.Backup
	if from != "" {
		backup = from
	}
	fmt.Fprintf(out, "Restore will:\n")
	fmt.Fprintf(out, "  - put %s back exactly as it was in %s\n", o.Home+"/.config/hypr", backup)
	fmt.Fprintf(out, "  - save the current files next to the backup (replaced-<time>/), the backup stays\n")
	listOrNone(out, "  - re-enable these systemd user units", st.DisabledUnits)
	fmt.Fprintf(out, "  - keep the imported monitor and keyboard settings\n")
	if !confirm(env.in, out, yes) {
		fmt.Fprintln(out, "Aborted; nothing changed.")
		return nil
	}
	res, err := exclusive.Restore(o, from)
	if err != nil {
		return err
	}
	fmt.Fprintf(out, "Restored from %s\n", res.Backup)
	if res.Replaced != "" {
		fmt.Fprintf(out, "The files replaced by exclusive mode are saved in %s\n", res.Replaced)
	}
	return nil
}

func listOrNone(out io.Writer, head string, items []string) {
	if len(items) == 0 {
		return
	}
	fmt.Fprintf(out, "%s: %s\n", head, strings.Join(items, ", "))
}

func confirm(in io.Reader, out io.Writer, yes bool) bool {
	if yes {
		return true
	}
	fmt.Fprint(out, "Continue? [y/N] ")
	line, _ := bufio.NewReader(in).ReadString('\n')
	ans := strings.ToLower(strings.TrimSpace(line))
	return ans == "y" || ans == "yes"
}
