package main

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"yozakura/backend/pkg/apphooks"
	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/paths"
	"yozakura/backend/pkg/termlook"
)

// runUpdate updates a source install the same way the hosted installer
// does: install.sh --update in the checkout pulls, rebuilds the backend and
// reinstalls the binary where this one lives. Nix installs update through
// their flake instead.
func runUpdate() {
	exe := currentExecutable()
	if fileExists("/etc/NIXOS") || strings.HasPrefix(exe, "/nix/store/") {
		fmt.Printf("%s is installed through Nix: update your flake input (nix flake update) or run '%s refresh' for a nix profile install.\n", brand.DisplayName, brand.AppID)
		return
	}
	src := paths.FindBaseShellSource()
	if src == "" || !fileExists(filepath.Join(src, ".git")) {
		fmt.Fprintf(os.Stderr, "Error: no git checkout of %s found. Install it with:\n  curl -fsSL %s | bash\n", brand.DisplayName, installerURL())
		os.Exit(1)
	}
	fmt.Println("Updating " + brand.DisplayName + " in " + src + "...")
	args := updateArgs(src, exe)
	if args == nil {
		fmt.Fprintf(os.Stderr, "Error: %s has no install.sh; update it with git pull && make build.\n", src)
		os.Exit(1)
	}
	cmd := exec.Command("bash", args...)
	cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, os.Stdout, os.Stderr
	if err := cmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: update failed: %v\n", err)
		os.Exit(1)
	}
	rebuildModsAfterUpdate()
	if isAlive() {
		fmt.Printf("Run '%s reload' to restart the shell on the new version.\n", brand.AppID)
	}
}

// updateArgs builds the installer command line for an update of src. The
// binary is reinstalled next to the running one when that directory is
// writable (a source build run in place counts too); otherwise the installer
// default applies. Returns nil when the checkout has no installer.
func updateArgs(src, exe string) []string {
	script := filepath.Join(src, "install.sh")
	if !fileExists(script) {
		return nil
	}
	args := []string{script, "--update", "--dir", src}
	if exe != "" {
		if dir := filepath.Dir(exe); dirWritable(dir) {
			args = append(args, "--bin-dir", dir)
		}
	}
	return args
}

func currentExecutable() string {
	exe, err := os.Executable()
	if err != nil {
		return ""
	}
	if resolved, err := filepath.EvalSymlinks(exe); err == nil {
		return resolved
	}
	return exe
}

func dirWritable(dir string) bool {
	f, err := os.CreateTemp(dir, ".write-test-*")
	if err != nil {
		return false
	}
	name := f.Name()
	f.Close()
	os.Remove(name)
	return true
}

func installerURL() string {
	return strings.Replace(brand.RepoURL, "https://github.com/", "https://raw.githubusercontent.com/", 1) + "/main/install.sh"
}

// revertAppHooks takes the shell out of the apps it connected to (terminals,
// Vesktop), reporting what it could not undo and returning the
// ids it disconnected.
func revertAppHooks(w io.Writer, env apphooks.Env, hooks []apphooks.Hook) []string {
	connected := map[string]bool{}
	for _, h := range hooks {
		connected[h.ID()] = h.Status(env).State == apphooks.StateConnected
	}
	var done []string
	for _, o := range apphooks.RevertAll(env, hooks) {
		if o.Err != nil {
			fmt.Fprintf(w, "Could not disconnect %s: %s\n", o.Status.ID, o.Err)
		} else if connected[o.Status.ID] {
			done = append(done, o.Status.ID)
		}
	}
	return done
}

// removeTermHook deletes the fish prompt file the shell owns (conf.d), so
// fish stops loading an engine config that goodbye leaves behind.
func removeTermHook(w io.Writer, env termlook.Env) {
	if err := termlook.Apply(termlook.Config{}, nil, nil, env); err != nil {
		fmt.Fprintf(w, "Could not remove the fish prompt file: %s\n", err)
	}
}

// runGoodbye uninstalls: every registered cleanup (see RegisterCleanup),
// compositor blocks (backups kept), the binary, and on request the source
// checkout and the configuration. --purge also deletes downloaded models,
// venvs and extras logs.
func runGoodbye(args []string) {
	purge := parseCLI(args, []string{"purge"}, nil).has("purge")
	reader := bufio.NewReader(os.Stdin)
	confirm := func(question string) bool {
		fmt.Print(question + " (y/N): ")
		reply, _ := reader.ReadString('\n')
		reply = strings.TrimSpace(reply)
		return reply == "y" || reply == "Y"
	}

	fmt.Println("Uninstalling " + brand.DisplayName + "...")
	if !confirm("Are you sure?") {
		fmt.Println("Uninstall aborted.")
		return
	}
	if isAlive() {
		quitShell()
	}
	home, _ := os.UserHomeDir()
	runCleanups(CleanupEnv{Out: os.Stdout, Confirm: confirm, Purge: purge, Home: home}, registeredCleanups())

	exe := currentExecutable()
	if fileExists("/etc/NIXOS") || strings.HasPrefix(exe, "/nix/store/") {
		out, _ := exec.Command("nix", "profile", "list").Output()
		if strings.Contains(strings.ToLower(string(out)), brand.AppID) {
			fmt.Println("Removing from nix profile...")
			exec.Command("nix", "profile", "remove", brand.DisplayName).Run()
			exec.Command("nix", "profile", "remove", brand.AppID).Run()
		} else {
			fmt.Println("Remove " + brand.DisplayName + " from your NixOS/home-manager configuration and rebuild.")
		}
		return
	}

	removeHyprland()
	removeSimpleTarget(niriConfig)
	removeSimpleTarget(mangoConfig)

	p := paths.New()
	src := paths.FindBaseShellSource()
	os.Remove(p.ShellPathFile())
	if exe != "" && (src == "" || filepath.Dir(exe) != src) {
		// The daemon is installed next to the CLI.
		for _, bin := range []string{exe, filepath.Join(filepath.Dir(exe), brand.Daemon)} {
			if !fileExists(bin) {
				continue
			}
			if err := os.Remove(bin); err == nil {
				fmt.Println("Removed " + bin)
			} else {
				fmt.Printf("Could not remove %s (%v); remove it by hand.\n", bin, err)
			}
		}
	}
	if src != "" && confirm("Remove the source checkout "+src+"?") {
		os.RemoveAll(src)
		fmt.Println("Removed " + src)
	}
	if confirm("Remove configuration files (" + p.ConfigDir + ")?") {
		os.RemoveAll(p.ConfigDir)
		fmt.Println("Configuration files removed.")
	}
	fmt.Printf("Data and cache stay in %s and %s.\n", p.DataDir, p.CacheDir)
	fmt.Println(brand.DisplayName + " uninstalled. :(")
}
