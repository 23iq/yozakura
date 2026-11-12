package main

import (
	"context"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/catalog"
	"yozakura/backend/pkg/paths"
	uc "yozakura/backend/pkg/updatechannel"
)

const updateUsage = `Usage: {bin} update [--channel stable|beta|git] [--check] [--allow-downgrade]
       {bin} update channel [stable|beta|git]

Updates a source install: fetches, moves the checkout to the target of the
update channel, rebuilds and reinstalls the binaries (install.sh --update).

Channels (setting system.updateChannel, default stable):
    stable    X.Y.Z releases
    beta      X.Y.Z-beta.N pre-releases, and any newer stable release
    git       every commit on main (the least stable)

A checkout already at or past the channel's newest release is up to date
(installs that followed main stay where they are until a newer release is
tagged). Local changes are kept and built as they are.

Options:
    --channel NAME       use this channel for this run only; to keep it:
                         {bin} update channel NAME (or {bin} config set
                         system.updateChannel NAME)
    --check              print the installed version, the channel and its
                         target; changes nothing
    --allow-downgrade    move back to an older release (the target of a tag
                         channel when the checkout is ahead of it on another line)

Commands:
    channel              the channel in effect, where it comes from, the
                         installed version and the channel's target
    channel NAME         save the channel (validated like {bin} config set;
                         the running shell picks it up) and show its target;
                         it does not update by itself

Nix installs update through their flake; channels do not apply there.
`

const channelKey = "system.updateChannel"

// updateEnv holds what `update` reads and runs; tests replace the parts
// that leave the sandbox (the installer, the Nix check).
type updateEnv struct {
	out, errOut io.Writer
	src         string // the checkout (paths.FindBaseShellSource)
	exe         string
	nix         bool
	store       func() (*catalog.Store, error)
	// runInstaller runs install.sh with these arguments (bash argv).
	runInstaller func(args []string) error
	// afterUpdate rebuilds mods and suggests a reload.
	afterUpdate func()
}

func defaultUpdateEnv() *updateEnv {
	exe := currentExecutable()
	return &updateEnv{
		out:    os.Stdout,
		errOut: os.Stderr,
		src:    paths.FindBaseShellSource(),
		exe:    exe,
		nix:    fileExists("/etc/NIXOS") || strings.HasPrefix(exe, "/nix/store/"),
		store: func() (*catalog.Store, error) {
			env, err := loadConfigEnv()
			if err != nil {
				return nil, err
			}
			return env.store, nil
		},
		runInstaller: func(args []string) error {
			cmd := exec.CommandContext(context.Background(), "bash", args...)
			cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, os.Stdout, os.Stderr
			return cmd.Run()
		},
		afterUpdate: func() {
			rebuildModsAfterUpdate()
			if isAlive() {
				fmt.Printf("Run '%s reload' to restart the shell on the new version.\n", brand.AppID)
			}
		},
	}
}

// runUpdate implements `yozakura update ...`.
func runUpdate(args []string, e *updateEnv) int {
	if len(args) > 0 && (args[0] == "help" || args[0] == "-h" || args[0] == "--help") {
		fmt.Fprint(e.out, branded(updateUsage))
		return 0
	}
	if len(args) > 0 && args[0] == "channel" {
		return e.channelCmd(args[1:])
	}
	a := parseCLI(args, []string{"check", "allow-downgrade"}, []string{"channel"})
	if len(a.pos) > 0 {
		fmt.Fprintf(e.errOut, "Error: unknown argument %q (see `%s update --help`)\n", a.pos[0], brand.AppID)
		return 2
	}
	channel, source := e.configured()
	if v, ok := a.value("channel"); ok {
		if !uc.Valid(v) {
			fmt.Fprintf(e.errOut, "Error: unknown channel %q (one of: %s)\n", v, strings.Join(uc.Channels, ", "))
			return 2
		}
		channel, source = v, "--channel, this run only"
	}
	if e.nix {
		fmt.Fprintf(e.out, "%s is installed through Nix: update your flake input (nix flake update) or run '%s refresh' for a nix profile install.\n", brand.DisplayName, brand.AppID)
		fmt.Fprintln(e.out, "Update channels do not apply to Nix installs.")
		return 0
	}
	if !e.hasCheckout() {
		fmt.Fprintf(e.errOut, "Error: no git checkout of %s found. Install it with:\n  curl -fsSL %s | bash\n", brand.DisplayName, installerURL())
		return 1
	}
	repo := uc.GitRepo{Dir: e.src}
	if a.has("check") {
		st := uc.Resolve(repo, channel, e.installedVersion())
		e.printStatus(st, source)
		return 0
	}
	fmt.Fprintf(e.out, "Checking the %s channel for %s in %s...\n", channel, brand.DisplayName, e.src)
	if err := repo.Fetch(); err != nil {
		fmt.Fprintf(e.errOut, "Error: cannot fetch updates: %v\n", err)
		return 1
	}
	st := uc.Resolve(repo, channel, e.installedVersion())
	return e.apply(st, source, a.has("allow-downgrade"))
}

// apply runs the installer when the resolution says so.
func (e *updateEnv) apply(st uc.Status, source string, allowDowngrade bool) int {
	switch st.State {
	case uc.Unknown:
		fmt.Fprintf(e.errOut, "Error: %s\n", st.Note)
		return 1
	case uc.NoTarget:
		fmt.Fprintf(e.out, "No %s release is published yet; nothing to update.\n", st.Channel)
		return 0
	case uc.UpToDate:
		if st.Channel != uc.Git {
			fmt.Fprintf(e.out, "%s %s is up to date on the %s channel (newest release: %s).\n", brand.DisplayName, e.installedLabel(st), st.Channel, st.Target)
			return 0
		}
	case uc.Downgrade:
		if !allowDowngrade {
			fmt.Fprintf(e.out, "%s %s is ahead of %s, the newest %s release; it stays as it is.\n", brand.DisplayName, e.installedLabel(st), st.Target, st.Channel)
			fmt.Fprintf(e.out, "To move back to %s: %s update --channel %s --allow-downgrade\n", st.Target, brand.AppID, st.Channel)
			return 0
		}
	}
	args := updateArgs(e.src, e.exe)
	if args == nil {
		fmt.Fprintf(e.errOut, "Error: %s has no install.sh; update it with git pull && make build.\n", e.src)
		return 1
	}
	if installerHasChannels(args[0]) {
		args = append(args, "--channel", st.Channel)
		if st.Channel != uc.Git {
			args = append(args, "--ref", st.Target)
		}
	} else if st.Channel != uc.Git {
		fmt.Fprintf(e.errOut, "Error: the installer in %s predates update channels; run '%s update --channel git' once, then use the %s channel.\n", e.src, brand.AppID, st.Channel)
		return 1
	}
	if st.Channel == uc.Git {
		fmt.Fprintf(e.out, "Updating %s to the tip of %s...\n", brand.DisplayName, st.Target)
	} else {
		fmt.Fprintf(e.out, "Updating %s %s to %s (%s channel)...\n", brand.DisplayName, e.installedLabel(st), st.Target, st.Channel)
	}
	if err := e.runInstaller(args); err != nil {
		fmt.Fprintf(e.errOut, "Error: update failed: %v\n", err)
		return 1
	}
	if e.afterUpdate != nil {
		e.afterUpdate()
	}
	return 0
}

// installerHasChannels: the checkout's install.sh knows --channel/--ref
// (a checkout older than update channels does not).
func installerHasChannels(script string) bool {
	data, err := os.ReadFile(script)
	return err == nil && strings.Contains(string(data), "--ref)")
}

// channelCmd implements `update channel [NAME]`.
func (e *updateEnv) channelCmd(args []string) int {
	if len(args) > 1 {
		fmt.Fprintf(e.errOut, "Usage: %s update channel [%s]\n", brand.AppID, strings.Join(uc.Channels, "|"))
		return 2
	}
	if len(args) == 1 {
		name := strings.ToLower(strings.TrimSpace(args[0]))
		if !uc.Valid(name) {
			fmt.Fprintf(e.errOut, "Error: unknown channel %q (one of: %s)\n", args[0], strings.Join(uc.Channels, ", "))
			return 2
		}
		store, err := e.store()
		if err != nil {
			fmt.Fprintf(e.errOut, "Error: %v\n", err)
			return 1
		}
		old, _ := e.configured()
		if _, err := store.Set(channelKey, name, false); err != nil {
			fmt.Fprintf(e.errOut, "Error: %v\n", err)
			return 1
		}
		if old == name {
			fmt.Fprintf(e.out, "Update channel: %s (unchanged)\n", name)
		} else {
			fmt.Fprintf(e.out, "Update channel: %s -> %s (saved as %s)\n", old, name, channelKey)
		}
	}
	channel, source := e.configured()
	if e.nix {
		fmt.Fprintf(e.out, "Channel    %s (%s)\n", channel, source)
		fmt.Fprintf(e.out, "%s is installed through Nix: channels do not apply; update through your flake.\n", brand.DisplayName)
		return 0
	}
	if !e.hasCheckout() {
		fmt.Fprintf(e.out, "Installed  %s\n", e.installedVersion())
		fmt.Fprintf(e.out, "Channel    %s (%s)\n", channel, source)
		fmt.Fprintln(e.out, "Target     unknown (no git checkout)")
		return 0
	}
	st := uc.Resolve(uc.GitRepo{Dir: e.src}, channel, e.installedVersion())
	e.printStatus(st, source)
	if len(args) == 1 && (st.State == uc.Available || st.State == uc.Downgrade) {
		fmt.Fprintf(e.out, "Nothing was updated; run '%s update' to move to it.\n", brand.AppID)
	}
	return 0
}

// configured: the saved channel and where it comes from.
func (e *updateEnv) configured() (string, string) {
	if e.store == nil {
		return uc.Default, "default"
	}
	store, err := e.store()
	if err != nil {
		return uc.Default, "default"
	}
	v, explicit, err := store.Get(channelKey)
	name, _ := v.(string)
	if err != nil || !uc.Valid(name) {
		return uc.Default, "default"
	}
	if !explicit {
		return name, "default"
	}
	return name, channelKey
}

func (e *updateEnv) hasCheckout() bool {
	return e.src != "" && fileExists(filepath.Join(e.src, ".git"))
}

func (e *updateEnv) installedVersion() string {
	if e.src == "" {
		return readVersion()
	}
	data, err := os.ReadFile(filepath.Join(e.src, "version"))
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(data))
}

// installedLabel: "0.3.1 (1a2b3c4)".
func (e *updateEnv) installedLabel(st uc.Status) string {
	v := st.Installed
	if v == "" {
		v = "?"
	}
	if st.Head == "" {
		return v
	}
	return v + " (" + uc.Short(st.Head) + ")"
}

// printStatus is the --check / `update channel` report.
func (e *updateEnv) printStatus(st uc.Status, source string) {
	where := "detached"
	if st.Branch != "" {
		where = "on " + st.Branch
	}
	installed := st.Installed
	if installed == "" {
		installed = "?"
	}
	if st.Head != "" {
		installed += " (" + uc.Short(st.Head) + ", " + where + ")"
	}
	fmt.Fprintf(e.out, "Installed  %s\n", installed)
	fmt.Fprintf(e.out, "Channel    %s (%s)\n", st.Channel, source)
	switch st.State {
	case uc.Unknown:
		fmt.Fprintf(e.out, "Target     unknown: %s\n", st.Note)
		return
	case uc.NoTarget:
		fmt.Fprintf(e.out, "Target     none: no %s release is published yet\n", st.Channel)
		return
	}
	fmt.Fprintf(e.out, "Target     %s (%s)\n", st.Target, uc.Short(st.TargetCommit))
	var status string
	switch st.State {
	case uc.UpToDate:
		status = "up to date"
	case uc.Available:
		status = "update available: " + brand.AppID + " update"
		if source == "--channel, this run only" {
			status += " --channel " + st.Channel
		}
	case uc.Downgrade:
		status = "the install is ahead of this release; it stays unless you pass --allow-downgrade"
	}
	fmt.Fprintf(e.out, "Status     %s\n", status)
	if st.Note != "" {
		fmt.Fprintf(e.out, "           (%s)\n", st.Note)
	}
}
