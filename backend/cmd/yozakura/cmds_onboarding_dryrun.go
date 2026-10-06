package main

import (
	"fmt"
	"io"
	"io/fs"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"

	"yozakura/backend/pkg/brand"
)

// `<app> onboarding --dry-run [--keep]`: the setup wizard in a separate
// Quickshell instance (onboarding-dryrun.qml) where every button can be
// clicked without changing anything. The app's config, cache and state
// dirs are copied into a temp dir and the instance runs with XDG_CONFIG_HOME,
// XDG_CACHE_HOME and XDG_STATE_HOME pointed there, so its own file writes
// land in the copies. Other entries of those dirs are symlinked (fonts,
// Qt/GTK settings and thumbnails read the same); the shell itself never
// writes there in dry-run mode (DryRun guards the theme generators and
// the compositor writer). Mutating daemon calls are mocked and journaled
// by the shell (modules/services/BackendService.qml, DryRunBackend.js);
// the journal is printed after the instance exits.
// <PREFIX>DRYRUN_FAIL=id1,id2 makes those fake installs fail.

// dryRunEnv is where the dry run reads from and what it runs (tests swap it).
type dryRunEnv struct {
	configHome, cacheHome, stateHome string // the user's XDG base dirs
	tmpParent                        string // "" = os.TempDir()
	qs                               string // Quickshell binary
	shellDir                         string // shell source (onboarding-dryrun.qml)
	environ                          []string
}

const dryRunQML = "onboarding-dryrun.qml"

func defaultDryRunEnv() dryRunEnv {
	home, _ := os.UserHomeDir()
	base := func(env, def string) string {
		if v := os.Getenv(env); v != "" {
			return v
		}
		return filepath.Join(home, def)
	}
	qs := brand.Env("QS")
	if qs == "" {
		qs = "qs"
	}
	return dryRunEnv{
		configHome: base("XDG_CONFIG_HOME", ".config"),
		cacheHome:  base("XDG_CACHE_HOME", ".cache"),
		stateHome:  base("XDG_STATE_HOME", ".local/state"),
		qs:         qs,
		shellDir:   shellDir(),
		environ:    os.Environ(),
	}
}

func isDryRunArgs(args []string) bool {
	for _, a := range args {
		if a == "--dry-run" {
			return true
		}
	}
	return false
}

func runOnboardingDryRun(args []string, env dryRunEnv, out, errOut io.Writer) int {
	keep := false
	for _, a := range args {
		switch a {
		case "--dry-run":
		case "--keep":
			keep = true
		default:
			fmt.Fprintf(errOut, "usage: %s onboarding --dry-run [--keep]\n", brand.AppID)
			return 2
		}
	}
	qml := filepath.Join(env.shellDir, dryRunQML)
	if _, err := os.Stat(qml); err != nil {
		fmt.Fprintf(errOut, "Error: %s not found in the shell source (%s)\n", dryRunQML, env.shellDir)
		return 1
	}
	dir, err := os.MkdirTemp(env.tmpParent, brand.AppID+"-dryrun-")
	if err != nil {
		fmt.Fprintf(errOut, "Error: %v\n", err)
		return 1
	}
	if !keep {
		defer os.RemoveAll(dir)
	}
	sandbox := []struct {
		name, real, env string
		copyApp         func(src, dst string) error
	}{
		{"config", env.configHome, "XDG_CONFIG_HOME", copyTree},
		{"cache", env.cacheHome, "XDG_CACHE_HOME", copyFilesLinkDirs},
		{"state", env.stateHome, "XDG_STATE_HOME", copyTree},
	}
	vars := map[string]string{
		brand.EnvPrefix + "DRYRUN":     "1",
		brand.EnvPrefix + "DRYRUN_DIR": dir,
	}
	for _, s := range sandbox {
		dst := filepath.Join(dir, s.name)
		if err := sandboxBase(s.real, dst, s.copyApp); err != nil {
			fmt.Fprintf(errOut, "Error: copy %s: %v\n", s.name, err)
			return 1
		}
		vars[s.env] = dst
	}

	logPath := filepath.Join(dir, "quickshell.log")
	logFile, err := os.Create(logPath)
	if err != nil {
		fmt.Fprintf(errOut, "Error: %v\n", err)
		return 1
	}
	defer logFile.Close()
	fmt.Fprintf(out, "%s setup wizard, dry run: nothing is changed. Close or finish the wizard to see what it would have done.\n", brand.DisplayName)

	cmd := exec.Command(env.qs, "-p", qml)
	cmd.Env = withEnv(env.environ, vars)
	cmd.Stdout = logFile
	cmd.Stderr = logFile
	cmd.SysProcAttr = &syscall.SysProcAttr{Pdeathsig: syscall.SIGTERM}
	if err := cmd.Start(); err != nil {
		fmt.Fprintf(errOut, "Error: start %s: %v\n", env.qs, err)
		return 1
	}
	// Ctrl+C / kill end the wizard; the journal is still printed and the
	// temp dir removed.
	sigs := make(chan os.Signal, 1)
	signal.Notify(sigs, os.Interrupt, syscall.SIGTERM)
	go func() {
		for sig := range sigs {
			_ = cmd.Process.Signal(sig)
		}
	}()
	waitErr := cmd.Wait()
	signal.Stop(sigs)
	close(sigs)

	printDryRunJournal(filepath.Join(dir, "dryrun.log"), out)
	if waitErr != nil {
		fmt.Fprintf(errOut, "Quickshell exited: %v (log: %s)\n", waitErr, logPath)
	}
	if keep {
		fmt.Fprintf(out, "Kept the dry-run files in %s\n", dir)
	}
	return 0
}

func printDryRunJournal(path string, out io.Writer) {
	data, _ := os.ReadFile(path)
	lines := strings.Split(strings.TrimSpace(string(data)), "\n")
	if len(data) == 0 || len(lines) == 0 || lines[0] == "" {
		fmt.Fprintln(out, "Dry run finished: nothing would have been changed.")
		return
	}
	fmt.Fprintf(out, "Dry run finished. It would have done (%d):\n", len(lines))
	for _, l := range lines {
		fmt.Fprintf(out, "  - %s\n", l)
	}
}

// withEnv returns environ with vars set (replacing existing entries).
func withEnv(environ []string, vars map[string]string) []string {
	out := make([]string, 0, len(environ)+len(vars))
	for _, kv := range environ {
		k, _, _ := strings.Cut(kv, "=")
		if _, ok := vars[k]; !ok {
			out = append(out, kv)
		}
	}
	for k, v := range vars {
		out = append(out, k+"="+v)
	}
	return out
}

// sandboxBase makes dst stand in for the XDG base dir real: the app's own
// dir is copied (copyApp), every other entry is a symlink to the real one.
func sandboxBase(real, dst string, copyApp func(src, dst string) error) error {
	if err := os.MkdirAll(dst, 0o700); err != nil {
		return err
	}
	entries, err := os.ReadDir(real)
	if err != nil && !os.IsNotExist(err) {
		return err
	}
	for _, e := range entries {
		if e.Name() == brand.AppID {
			continue
		}
		if err := os.Symlink(filepath.Join(real, e.Name()), filepath.Join(dst, e.Name())); err != nil {
			return err
		}
	}
	app := filepath.Join(real, brand.AppID)
	if _, err := os.Stat(app); os.IsNotExist(err) {
		return os.MkdirAll(filepath.Join(dst, brand.AppID), 0o700)
	}
	return copyApp(app, filepath.Join(dst, brand.AppID))
}

// copyTree copies a directory recursively (symlinks stay symlinks).
func copyTree(src, dst string) error {
	return filepath.WalkDir(src, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel, _ := filepath.Rel(src, path)
		target := filepath.Join(dst, rel)
		switch {
		case d.IsDir():
			return os.MkdirAll(target, 0o700)
		case d.Type()&fs.ModeSymlink != 0:
			link, err := os.Readlink(path)
			if err != nil {
				return err
			}
			return os.Symlink(link, target)
		case d.Type().IsRegular():
			return copyFile(path, target)
		}
		return nil
	})
}

// copyFilesLinkDirs copies the files directly in src (wallpapers.json,
// colors.json, ...) and links its folders (thumbnails, schemes: large and
// only read).
func copyFilesLinkDirs(src, dst string) error {
	if err := os.MkdirAll(dst, 0o700); err != nil {
		return err
	}
	entries, err := os.ReadDir(src)
	if err != nil {
		return err
	}
	for _, e := range entries {
		from, to := filepath.Join(src, e.Name()), filepath.Join(dst, e.Name())
		if e.Type().IsRegular() {
			err = copyFile(from, to)
		} else {
			err = os.Symlink(from, to)
		}
		if err != nil {
			return err
		}
	}
	return nil
}

func copyFile(src, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	info, err := in.Stat()
	if err != nil {
		return err
	}
	o, err := os.OpenFile(dst, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, info.Mode().Perm())
	if err != nil {
		return err
	}
	if _, err := io.Copy(o, in); err != nil {
		o.Close()
		return err
	}
	return o.Close()
}
