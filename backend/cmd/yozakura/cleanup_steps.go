package main

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"yozakura/backend/pkg/apphooks"
	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/exclusive"
	"yozakura/backend/pkg/fsutil"
	"yozakura/backend/pkg/paths"
	"yozakura/backend/pkg/svc/displays"
	exclusivesvc "yozakura/backend/pkg/svc/exclusive"
	"yozakura/backend/pkg/termlook"
)

func init() {
	// Order matters: exclusive restore swaps the whole hypr tree back, so
	// the line-level steps below run on the restored files.
	RegisterCleanup("exclusive", cleanupExclusive)
	RegisterCleanup("apphooks", cleanupAppHooks)
	RegisterCleanup("fish prompt", cleanupFishHook)
	RegisterCleanup("monitor rules", cleanupMovedMonitors)
	RegisterCleanup("polkit autostart", cleanupPolkitLines)
	RegisterCleanup("bin links", cleanupBinLinks)
	RegisterCleanup("root helper", cleanupSysHelper)
	RegisterCleanup("downloads", cleanupPurge)
}

func cleanupExclusive(env CleanupEnv) ([]string, error) {
	o := exclusivesvc.Host()
	// by the entry file: goodbye often runs outside a Hyprland session,
	// where the compositor is not detected
	if !exclusive.Active(o.HyprDir) {
		return nil, nil
	}
	if o.Compositor == "" {
		o.Compositor = "hyprland"
	}
	if !env.Confirm("Exclusive mode is active. Restore your backed-up Hyprland config first?") {
		return nil, nil
	}
	st, err := exclusive.Restore(o, "")
	if err != nil {
		return nil, err
	}
	return []string{"exclusive mode (restored " + st.Backup + ")"}, nil
}

func cleanupAppHooks(env CleanupEnv) ([]string, error) {
	var removed []string
	for _, id := range revertAppHooks(env.Out, apphooks.DefaultEnv(), apphooks.All()) {
		removed = append(removed, "hook "+id)
	}
	return removed, nil
}

func cleanupFishHook(env CleanupEnv) ([]string, error) {
	tenv := termlook.Env{ConfigHome: filepath.Dir(paths.New().ConfigDir), AppID: brand.AppID}
	file := termlook.HookFile(tenv)
	before := fileExists(file)
	removeTermHook(env.Out, tenv)
	if before && !fileExists(file) {
		return []string{"fish prompt file"}, nil
	}
	return nil, nil
}

func cleanupMovedMonitors(env CleanupEnv) ([]string, error) {
	got, skipped, err := displays.RestoreMoved(paths.HyprDir(), paths.New().DataDir, env.Home)
	var out []string
	for _, c := range got {
		out = append(out, fmt.Sprintf("uncommented %s:%d", c.File, c.Line))
	}
	for _, c := range skipped {
		fmt.Fprintf(env.Out, "Left %s:%d commented out (%s)\n", c.File, c.Line, c.Reason)
	}
	return out, err
}

// polkitSuffixes are the comment tails install.sh puts on the polkit line:
// [0] for hyprlang (.conf), [1] for Lua.
func polkitSuffixes() []string {
	return []string{"# " + brand.AppID + ": polkit", "-- " + brand.AppID + ": polkit"}
}

// isPolkitLine matches exactly what the installer appends: a start of the
// polkit agent ending in our marker, in the form of the file's language.
func isPolkitLine(line string, lua bool) bool {
	line = strings.TrimRight(line, " \t\r")
	if lua {
		return strings.HasPrefix(line, "hl.on(") && strings.HasSuffix(line, " "+polkitSuffixes()[1])
	}
	return strings.HasPrefix(line, "exec-once = ") && strings.HasSuffix(line, " "+polkitSuffixes()[0])
}

// removePolkitLines drops the installer's polkit line (and the blank line it
// put before itself) from path; it returns how many lines went.
func removePolkitLines(path string) (int, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return 0, nil
	}
	lua := strings.HasSuffix(path, ".lua")
	lines := strings.Split(string(data), "\n")
	out := make([]string, 0, len(lines))
	n := 0
	for _, l := range lines {
		if isPolkitLine(l, lua) {
			n++
			// The blank line the installer wrote before its line goes too,
			// unless it is one of several (then it was the user's).
			if k := len(out); k > 0 && out[k-1] == "" && (k == 1 || out[k-2] != "") {
				out = out[:len(out)-1]
			}
			continue
		}
		out = append(out, l)
	}
	if n == 0 {
		return 0, nil
	}
	return n, fsutil.WriteFile(path, []byte(strings.Join(out, "\n")), 0o644)
}

func cleanupPolkitLines(env CleanupEnv) ([]string, error) {
	var removed []string
	var firstErr error
	for _, name := range []string{"hyprland.lua", "hyprland.conf"} {
		path := filepath.Join(paths.HyprDir(), name)
		if isHomeManagerManaged(path) {
			continue
		}
		n, err := removePolkitLines(path)
		if err != nil && firstErr == nil {
			firstErr = err
		}
		if n > 0 {
			removed = append(removed, "polkit line in "+path)
		}
	}
	return removed, firstErr
}

// ourBinaries are the files a /usr/local/bin link may legitimately point at.
func ourBinaries() map[string]bool {
	set := map[string]bool{}
	if exe := currentExecutable(); exe != "" {
		set[exe] = true
		set[filepath.Join(filepath.Dir(exe), brand.Daemon)] = true
	}
	if src := paths.FindBaseShellSource(); src != "" {
		set[filepath.Join(src, brand.AppID)] = true
		set[filepath.Join(src, brand.Daemon)] = true
	}
	return set
}

// binLinksIn lists the links in dir that point at one of ours.
func binLinksIn(dir string, ours map[string]bool) []string {
	var links []string
	for _, name := range []string{brand.AppID, brand.Daemon} {
		link := filepath.Join(dir, name)
		target, err := os.Readlink(link)
		if err != nil {
			continue
		}
		if !filepath.IsAbs(target) {
			target = filepath.Join(dir, target)
		}
		if ours[filepath.Clean(target)] {
			links = append(links, link)
		}
	}
	return links
}

// pkexecRm removes root-owned files; a var so tests do not escalate.
var pkexecRm = realPkexecRm

func realPkexecRm(files ...string) error {
	cmd := exec.Command("pkexec", append([]string{"rm", "-f", "--"}, files...)...)
	cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, os.Stdout, os.Stderr
	return cmd.Run()
}

func cleanupBinLinks(env CleanupEnv) ([]string, error) {
	links := binLinksIn("/usr/local/bin", ourBinaries())
	if len(links) == 0 || !env.Confirm("Remove "+strings.Join(links, ", ")+" (needs admin rights)?") {
		return nil, nil
	}
	if err := pkexecRm(links...); err != nil {
		return nil, fmt.Errorf("pkexec rm: %w", err)
	}
	return links, nil
}

// sysHelperPath is where install.sh puts the root helper (tests move it).
var sysHelperPath = func() string { return "/usr/local/lib/" + brand.AppID + "/" + brand.AppID + "-sys" }

// pkexecRmHelper removes the helper and then its folder when that is empty,
// in one authorisation (paths as argv, the script is constant).
var pkexecRmHelper = func(helper, dir string) error {
	cmd := exec.Command("pkexec", "sh", "-c", `rm -f -- "$1" && { rmdir -- "$2" 2>/dev/null || true; }`, "sh", helper, dir)
	cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, os.Stdout, os.Stderr
	return cmd.Run()
}

func cleanupSysHelper(env CleanupEnv) ([]string, error) {
	helper := sysHelperPath()
	if !fileExists(helper) || !env.Confirm("Remove the root helper "+helper+" (needs admin rights)?") {
		return nil, nil
	}
	if err := pkexecRmHelper(helper, filepath.Dir(helper)); err != nil {
		return nil, fmt.Errorf("pkexec rm: %w", err)
	}
	return []string{helper}, nil
}

// purgeDirs are the large downloads and logs that --purge deletes: the
// whisper build and models (voice_setup.sh), the depth venv and weights
// (depth_setup.sh) and the extras install logs.
func purgeDirs() []string {
	p := paths.New()
	return []string{
		filepath.Join(p.DataDir, "whisper"),
		filepath.Join(p.DataDir, "venv-depth"),
		filepath.Join(p.DataDir, "depth-models"),
		filepath.Join(p.StateDir, "extras"),
	}
}

func cleanupPurge(env CleanupEnv) ([]string, error) {
	if !env.Purge {
		return nil, nil
	}
	var present []string
	for _, d := range purgeDirs() {
		if fileExists(d) {
			present = append(present, d)
		}
	}
	if len(present) == 0 || !env.Confirm("Delete downloaded models, venvs and logs ("+strings.Join(present, ", ")+")?") {
		return nil, nil
	}
	var removed []string
	var errs []error
	for _, d := range present {
		if err := os.RemoveAll(d); err != nil {
			errs = append(errs, err)
			continue
		}
		removed = append(removed, d)
	}
	return removed, errors.Join(errs...)
}
