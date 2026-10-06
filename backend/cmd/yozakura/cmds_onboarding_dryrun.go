package main

import (
	"fmt"
	"io"
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
// clicked without changing anything. The instance runs with
// XDG_CONFIG_HOME, XDG_CACHE_HOME and XDG_STATE_HOME on dirs of a temp dir
// holding plain copies (symlinks dereferenced: nothing in it points back at
// the real dirs) of the app's config, its cache (folders over
// dryRunDirCap stay empty) and the font/Qt settings needed to render
// (dryRunForeignConfig); the state dir starts empty (StateService is
// daemon-backed, its writes are mocked). Daemon calls other than known
// reads are mocked and journaled by the shell (BackendService,
// DryRunMethods.js, DryRunBackend.js); the journal is printed after the
// instance exits. <PREFIX>DRYRUN_FAIL=id1,id2 makes those fake installs fail.

// dryRunEnv is where the dry run reads from and what it runs (tests swap it).
type dryRunEnv struct {
	configHome, cacheHome string // the user's XDG base dirs
	tmpParent             string // "" = os.TempDir()
	qs                    string // Quickshell binary
	shellDir              string // shell source (onboarding-dryrun.qml)
	environ               []string
}

const dryRunQML = "onboarding-dryrun.qml"

// Other apps' config the shell reads to render (fonts, Qt icon theme).
var dryRunForeignConfig = []string{"fontconfig", "qt6ct"}

// Folders larger than this are left empty in the copy (thumbnails etc.).
var dryRunDirCap int64 = 64 << 20

// The whole sandbox copy stops with an error past this.
var dryRunCopyCap int64 = 256 << 20

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
	vars := map[string]string{
		brand.EnvPrefix + "DRYRUN":     "1",
		brand.EnvPrefix + "DRYRUN_DIR": dir,
		"XDG_CONFIG_HOME":              filepath.Join(dir, "config"),
		"XDG_CACHE_HOME":               filepath.Join(dir, "cache"),
		"XDG_STATE_HOME":               filepath.Join(dir, "state"),
	}
	if err := buildDryRunSandbox(env, vars); err != nil {
		fmt.Fprintf(errOut, "Error: %v\n", err)
		return 1
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
	// Ctrl+C / kill / a closed terminal end the wizard; the journal is
	// still printed and the temp dir removed (a gone reader of stdout must
	// not kill us before the cleanup: SIGPIPE is ignored, writes just fail).
	signal.Ignore(syscall.SIGPIPE)
	sigs := make(chan os.Signal, 1)
	signal.Notify(sigs, os.Interrupt, syscall.SIGTERM, syscall.SIGHUP)
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

// buildDryRunSandbox fills the XDG dirs of vars: copies only, no link
// into the user's dirs, at most dryRunCopyCap bytes in all.
func buildDryRunSandbox(env dryRunEnv, vars map[string]string) error {
	config, cache, state := vars["XDG_CONFIG_HOME"], vars["XDG_CACHE_HOME"], vars["XDG_STATE_HOME"]
	for _, d := range []string{filepath.Join(config, brand.AppID), filepath.Join(cache, brand.AppID), filepath.Join(state, brand.AppID)} {
		if err := os.MkdirAll(d, 0o700); err != nil {
			return err
		}
	}
	c := newTreeCopier(dryRunCopyCap)
	if err := copyIfExists(filepath.Join(env.configHome, brand.AppID), filepath.Join(config, brand.AppID), c.tree); err != nil {
		return fmt.Errorf("copy config: %w", err)
	}
	for _, name := range dryRunForeignConfig {
		src := filepath.Join(env.configHome, name)
		if size, ok := treeSize(src, dryRunDirCap); ok && size > 0 {
			if err := c.tree(src, filepath.Join(config, name)); err != nil {
				return fmt.Errorf("copy %s: %w", name, err)
			}
		}
	}
	if err := copyIfExists(filepath.Join(env.cacheHome, brand.AppID), filepath.Join(cache, brand.AppID), c.cache); err != nil {
		return fmt.Errorf("copy cache: %w", err)
	}
	return nil
}

func copyIfExists(src, dst string, copyFn func(src, dst string) error) error {
	if _, err := os.Stat(src); os.IsNotExist(err) {
		return nil
	}
	return copyFn(src, dst)
}

// fileKey identifies a file across links (device + inode).
func fileKey(info os.FileInfo) ([2]uint64, bool) {
	st, ok := info.Sys().(*syscall.Stat_t)
	if !ok {
		return [2]uint64{}, false
	}
	return [2]uint64{uint64(st.Dev), st.Ino}, true
}

// treeCopier copies trees with every symlink replaced by what it points
// to (other file types are skipped), each folder once (a link cycle ends
// there) and fails once more than limit bytes would be copied.
type treeCopier struct {
	seen          map[[2]uint64]bool
	copied, limit int64
}

func newTreeCopier(limit int64) *treeCopier {
	return &treeCopier{seen: map[[2]uint64]bool{}, limit: limit}
}

func (c *treeCopier) tree(src, dst string) error {
	info, err := os.Stat(src)
	if err != nil {
		if os.IsNotExist(err) {
			return nil // dangling link
		}
		return err
	}
	switch {
	case info.IsDir():
		if key, ok := fileKey(info); ok {
			if c.seen[key] {
				return nil
			}
			c.seen[key] = true
		}
		if err := os.MkdirAll(dst, 0o700); err != nil {
			return err
		}
		entries, err := os.ReadDir(src)
		if err != nil {
			return err
		}
		for _, e := range entries {
			if err := c.tree(filepath.Join(src, e.Name()), filepath.Join(dst, e.Name())); err != nil {
				return err
			}
		}
		return nil
	case info.Mode().IsRegular():
		c.copied += info.Size()
		if c.copied > c.limit {
			return fmt.Errorf("more than %d MiB to copy (at %s)", c.limit>>20, src)
		}
		return copyFile(src, dst)
	}
	return nil
}

// cache copies the app's cache: its files (wallpapers.json, colors.json,
// ...) and every folder up to dryRunDirCap (thumbnails, schemes); a larger
// folder is created empty, a larger file left out.
func (c *treeCopier) cache(src, dst string) error {
	if err := os.MkdirAll(dst, 0o700); err != nil {
		return err
	}
	entries, err := os.ReadDir(src)
	if err != nil {
		return err
	}
	for _, e := range entries {
		from, to := filepath.Join(src, e.Name()), filepath.Join(dst, e.Name())
		if _, ok := treeSize(from, dryRunDirCap); !ok {
			if info, statErr := os.Stat(from); statErr == nil && info.IsDir() {
				err = os.MkdirAll(to, 0o700)
			}
		} else {
			err = c.tree(from, to)
		}
		if err != nil {
			return err
		}
	}
	return nil
}

// treeSize is the size of src (symlinks followed, each folder once); ok is
// false once it passes limit.
func treeSize(src string, limit int64) (int64, bool) {
	var total int64
	seen := map[[2]uint64]bool{}
	var walk func(p string) bool
	walk = func(p string) bool {
		info, err := os.Stat(p)
		if err != nil {
			return true
		}
		if !info.IsDir() {
			total += info.Size()
			return total <= limit
		}
		if key, ok := fileKey(info); ok {
			if seen[key] {
				return true
			}
			seen[key] = true
		}
		entries, _ := os.ReadDir(p)
		for _, e := range entries {
			if !walk(filepath.Join(p, e.Name())) {
				return false
			}
		}
		return true
	}
	ok := walk(src)
	return total, ok
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
