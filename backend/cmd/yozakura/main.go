package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"
	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/envclean"
	"yozakura/backend/pkg/instancelock"
	"yozakura/backend/pkg/migrate"

	"yozakura/backend/pkg/daemon"
	"yozakura/backend/pkg/ipc"
	"yozakura/backend/pkg/paths"
)

var version = "dev"

// envCleanMsgs holds what envclean changed at startup; only the shell
// supervisor prints it, one-shot subcommands stay quiet.
var envCleanMsgs []string

func main() {
	ensureSelfOnPath()
	envCleanMsgs = envclean.CleanProcess()
	args := os.Args[1:]

	if len(args) >= 1 {
		switch args[0] {
		case "version", "-v", "--version":
			fmt.Printf("%s %s\n", brand.DisplayName, readVersion())
			return
		case "help", "--help", "-h":
			showHelp()
			return
		case "update":
			runUpdate()
			return
		case "refresh":
			runRefresh()
			return
		case "install":
			runInstall(args[1:])
			return
		case "remove":
			runRemove(args[1:])
			return
		case "goodbye":
			runGoodbye(args[1:])
			return
		case "doctor":
			os.Exit(runDoctor(args[1:], os.Stdout))
		case "mods":
			runMods(args[1:])
			return
		case "mcp":
			os.Exit(runMCP(args[1:]))
		case "schemes":
			os.Exit(runSchemes(args[1:], schemesCacheDir()))
		case "config":
			os.Exit(runConfig(args[1:], os.Stdout, os.Stderr))
		case "preset", "presets":
			os.Exit(runPreset(args[1:], os.Stdout, os.Stderr))
		case "completion":
			os.Exit(runCompletion(args[1:], os.Stdout, os.Stderr))
		case "cmd", "command":
			os.Exit(runCmd(args[1:], os.Stdout, os.Stderr))
		case "binds", "bind":
			os.Exit(runBinds(args[1:], defaultBindsEnv(), os.Stdout, os.Stderr))
		case "special", "specials":
			os.Exit(runSpecial(args[1:], os.Stdout, os.Stderr))
		case "launch":
			os.Exit(runLaunch(args[1:], defaultLaunchEnv(), os.Stderr))
		case "timer", "timers":
			os.Exit(runTimer(args[1:], os.Stdout, os.Stderr))
		case "stopwatch", "sw":
			os.Exit(runStopwatch(args[1:], os.Stdout, os.Stderr))
		case "remind", "reminder":
			os.Exit(runRemind(args[1:], os.Stdout, os.Stderr))
		case "routine", "routines":
			os.Exit(runRoutine(args[1:], os.Stdin, os.Stdout, os.Stderr))
		case "usage":
			os.Exit(runUsage(args[1:], newClient(), os.Stdout, os.Stderr))
		case "focus":
			os.Exit(runFocus(args[1:], newClient(), os.Stdout, os.Stderr))
		case "providers", "provider":
			os.Exit(runProviders(args[1:], newClient(), os.Stdout, os.Stderr))
		case "display", "displays":
			os.Exit(runDisplay(args[1:], defaultDisplayEnv(os.Stdin, os.Stdout), os.Stdout, os.Stderr))
		case "keyboard":
			os.Exit(runKeyboard(args[1:], defaultKeyboardEnv(), os.Stdout, os.Stderr))
		case "term":
			os.Exit(runTerm(args[1:], ipcTerm{newClient()}, os.Stdout, os.Stderr))
		case "extras":
			os.Exit(runExtras(args[1:], ipcExtras{newClient(), socketPath()}, os.Stdout, os.Stderr))
		case "task", "tasks":
			os.Exit(runTask(args[1:], os.Stdout, os.Stderr))
		case "sys":
			os.Exit(runSys(args[1:], defaultSysEnv(os.Stdout), os.Stdout, os.Stderr))
		case "onboarding":
			if msg := onboardingArgsError(args[1:]); msg != "" {
				fmt.Fprintln(os.Stderr, msg)
				os.Exit(2)
			}
			// before migrations: a dry run never touches the user's files
			if isDryRunArgs(args[1:]) {
				os.Exit(runOnboardingDryRun(args[1:], defaultDryRunEnv(), os.Stdout, os.Stderr))
			}
		}
	}

	if len(args) == 0 {
		refuseIfLegacyRunning() // before migration touches user files
	}
	migrateLegacy()
	if len(args) == 0 {
		migrateDaemonFiles() // the shell start owns the daemon's files
	}
	markExistingInstallOnboarded()
	markLegacyKeyboard()
	ensureConfigFiles()

	if len(args) == 0 {
		runShell()
		return
	}

	switch args[0] {
	case "run":
		cmd := ""
		if len(args) > 1 {
			cmd = args[1]
		}
		if cmd == "" {
			fmt.Println("Error: No command specified for run")
			os.Exit(1)
		}
		mustCall("ui.run", map[string]any{"command": cmd})
	case "toggle":
		cmd := ""
		if len(args) > 1 {
			cmd = args[1]
		}
		if cmd == "" {
			fmt.Println("Error: No command specified for toggle")
			os.Exit(1)
		}
		mustCall("ui.toggle", map[string]any{"command": cmd})
	case "lock":
		mustCall("ui.run", map[string]any{"command": "lockscreen"})
	case "onboarding":
		mustCall("ui.run", map[string]any{"command": "onboarding"})
	case "reload":
		restartShell()
	case "quit":
		quitShell()
	case "screen":
		runScreen(args[1:])
	case "suspend":
		doSuspend()
	case "brightness":
		runBrightness(args[1:])
	case "colorpicker":
		os.Exit(runColorPicker())
	case "lockwall":
		os.Exit(runLockWall(args[1:]))
	case "thumbs":
		os.Exit(runThumbs(args[1:], 140, true))
	case "dthumbs":
		os.Exit(runThumbs(args[1:], 64, false))
	case "ipc":
		os.Exit(runIpc(args[1:]))
	case "chatlist":
		os.Exit(runChatList(args[1:]))
	case "wallpaper":
		os.Exit(runWallpaper(args[1:]))
	case "voice":
		os.Exit(runVoice(args[1:]))
	default:
		fmt.Printf("Error: Unknown command '%s'\n", args[0])
		showHelp()
		os.Exit(1)
	}
}

// readVersion returns the contents of the source tree's version file:
// next to the binary (`make build` output at the repo root), one level up
// (backend/), or in the shell source the binary runs. Falls back to the
// version baked in at link time.
func readVersion() string {
	dirs := []string{}
	if exe, err := os.Executable(); err == nil {
		dirs = append(dirs, filepath.Dir(exe), filepath.Dir(filepath.Dir(exe)))
	}
	if src := paths.FindBaseShellSource(); src != "" {
		dirs = append(dirs, src)
	}
	for _, dir := range dirs {
		if data, err := os.ReadFile(filepath.Join(dir, "version")); err == nil {
			return strings.TrimSpace(string(data))
		}
	}
	return version
}

// migrateLegacy copies a legacy (Ambxst) install on first start, before
// anything creates the new config dir. Failures are reported, never fatal:
// the shell then starts from defaults and the legacy dirs are untouched.
func migrateLegacy() {
	res, err := migrate.Run(*paths.New(), migrate.DefaultLegacy())
	if err != nil {
		fmt.Fprintf(os.Stderr, "Warning: migration from %s failed: %v\n", brand.LegacyName, err)
		return
	}
	if res.Migrated {
		fmt.Printf("Imported settings from your previous %s install (log: %s)\n", brand.LegacyName,
			filepath.Join(paths.New().DataDir, migrate.MarkerFile))
	}
}

// migrateDaemonFiles renames the files of the external compositor daemon
// the built-in one replaced (config, saved brightness) once.
func migrateDaemonFiles() {
	userConfig, _ := os.UserConfigDir()
	done, err := migrate.MigrateDaemonFiles(migrate.DaemonMoves(*paths.New(), userConfig))
	if err != nil {
		fmt.Fprintf(os.Stderr, "Warning: %s file migration: %v\n", brand.Daemon, err)
	}
	for _, m := range done {
		fmt.Printf("Moved %s -> %s\n", m.From, m.To)
	}
}

// finishMigrationLater switches the deferred user files (Hyprland entry)
// once the daemon has generated the new compositor config.
func finishMigrationLater() {
	go func() {
		for i := 0; i < 150; i++ {
			done, err := migrate.FinishPending(*paths.New())
			if err == nil && len(done) > 0 {
				return
			}
			if !hasPendingMigration() {
				return
			}
			time.Sleep(2 * time.Second)
		}
	}()
}

func hasPendingMigration() bool {
	data, err := os.ReadFile(filepath.Join(paths.New().DataDir, migrate.MarkerFile))
	if err != nil {
		return false
	}
	var lg migrate.Log
	return json.Unmarshal(data, &lg) == nil && len(lg.Pending) > 0
}

// markExistingInstallOnboarded hides the first-run wizard for installs that
// predate it (runs before ensureConfigFiles can create a fresh general.json).
func markExistingInstallOnboarded() {
	if _, err := migrate.EnsureOnboardingFlag(*paths.New()); err != nil {
		fmt.Fprintf(os.Stderr, "Warning: cannot update general.json: %v\n", err)
	}
}

// markLegacyKeyboard gives a keyboard.json from before keyboard.managed its
// value (pure defaults: unmanaged), before the shell or CLI read it.
func markLegacyKeyboard() {
	if _, err := migrate.EnsureKeyboardManaged(*paths.New()); err != nil {
		fmt.Fprintf(os.Stderr, "Warning: cannot update keyboard.json: %v\n", err)
	}
}

func ensureConfigFiles() {
	if err := daemon.EnsureConfigFiles(paths.New(), defaultPresetDir()); err != nil {
		fmt.Fprintf(os.Stderr, "Error: failed to ensure config: %v\n", err)
	}
}

func socketPath() string {
	return paths.New().SocketPath()
}

func newClient() *ipc.Client {
	return ipc.NewClient(socketPath())
}

// runIpc dispatches a JSON-RPC call to the running yozakura process.
//
//	yozakura ipc call <service.method> <json>
func runIpc(args []string) int {
	if len(args) < 2 || args[0] != "call" {
		fmt.Fprintln(os.Stderr, "Usage: "+brand.AppID+" ipc call <service.method> <json>")
		return 2
	}
	method := args[1]
	var params any
	if len(args) >= 3 && args[2] != "" {
		if err := json.Unmarshal([]byte(args[2]), &params); err != nil {
			fmt.Fprintf(os.Stderr, "Error: invalid JSON payload: %v\n", err)
			return 2
		}
	}
	if !isAlive() {
		fmt.Fprintln(os.Stderr, "Error: "+brand.DisplayName+" is not running")
		return 1
	}
	res, err := newClient().Call(method, params)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		return 1
	}
	if len(res) > 0 {
		fmt.Println(string(res))
	}
	return 0
}

func mustCall(method string, params any) json.RawMessage {
	client := newClient()
	if !isAlive() {
		fmt.Fprintln(os.Stderr, "Error: "+brand.DisplayName+" is not running")
		os.Exit(1)
	}
	res, err := client.Call(method, params)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
	return res
}

// isAlive reports whether a daemon is running: it holds the instance lock,
// or (builds that predate the lock) answers on the socket. Read-only: stale
// files are replaced by the next daemon, never deleted here, so a probe can
// not remove the socket of an instance that is just starting.
func isAlive() bool {
	if _, held := instancelock.Held(instancelock.AppPath()); held {
		return true
	}
	return legacyAlive()
}

// legacyAlive dials the socket to find a daemon that holds no lock.
func legacyAlive() bool {
	sock := socketPath()
	info, err := os.Stat(sock)
	if err != nil || info.Mode()&os.ModeSocket == 0 {
		return false
	}
	c, err := net.DialTimeout("unix", sock, 500*time.Millisecond)
	if err != nil {
		return false
	}
	c.Close()
	return true
}

func pidPath() string {
	if runtime := os.Getenv("XDG_RUNTIME_DIR"); runtime != "" {
		return filepath.Join(runtime, brand.AppID+".pid")
	}
	return "/tmp/" + brand.AppID + ".pid"
}

// runShell becomes the unified yozakura process: starts the IPC server,
// supervises the compositor process manager, spawns Quickshell, and blocks
// until shutdown. If another instance is alive we ask it to shut down via
// IPC and fall back to SIGTERMing the pidfile process so the user can
// transparently upgrade from older builds that lack system.shutdown.
func runShell() {
	refuseIfLegacyRunning()
	// Exclusive for the whole lifetime, taken before the socket, the pid
	// file or any child exists: a second daemon must touch nothing.
	lock, err := instancelock.Acquire(instancelock.AppPath())
	if err != nil {
		var held *instancelock.HeldError
		if errors.As(err, &held) {
			fmt.Printf("%s already running (pid %d)\n", brand.AppID, held.PID)
			os.Exit(0)
		}
		fmt.Fprintf(os.Stderr, "Error: instance lock: %v\n", err)
		os.Exit(1)
	}
	defer lock.Release()
	// We own the lock, so only a build that predates it can still be up.
	if legacyAlive() {
		pid := readPIDFile()
		if _, err := newClient().Call("system.shutdown", nil); err == nil {
			waitForDeath(pid, 5*time.Second)
		} else {
			killPIDFile()
			waitForDeath(pid, 2*time.Second)
		}
		// Sweep children the previous daemon may have leaked (e.g. an
		// older build that didn't track wl-paste/yozd). Run before
		// initialising the new daemon so we don't double-start.
		cleanupOrphans()
	}

	// Quickshell and every other child run the same compositor daemon
	// executable the backend supervises (next to this binary first).
	os.Setenv(paths.DaemonBinEnv, paths.DaemonBinary())

	if home, err := os.UserHomeDir(); err == nil {
		repairHyprlandEntry(home, currentExecutable())
	}

	runDetached("pkill -f 'dunst|mako|swaync'")
	runDetached("pkill -f 'easyeffects.*gapplication-service' ; nohup easyeffects --gapplication-service >/dev/null 2>&1 &")

	if iconTheme, err := exec.Command("gsettings", "get", "org.gnome.desktop.interface", "icon-theme").Output(); err == nil {
		os.Setenv("QS_ICON_THEME", strings.Trim(strings.TrimSpace(string(iconTheme)), "'"))
	}
	os.Setenv("QT_QPA_PLATFORMTHEME", "qt6ct")
	os.Unsetenv("HL_INITIAL_WORKSPACE_TOKEN")
	if tmpdir := defaultTMUXTmpDir(os.Getenv("TMUX_TMPDIR"), os.Getenv("XDG_RUNTIME_DIR")); tmpdir != "" {
		os.Setenv("TMUX_TMPDIR", tmpdir)
	}

	for _, m := range envCleanMsgs {
		fmt.Fprintln(os.Stderr, m)
	}
	d, err := daemon.New()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: init daemon: %v\n", err)
		os.Exit(1)
	}

	finishMigrationLater()

	qsBin := brand.Env("QS")
	if qsBin == "" {
		qsBin = "qs"
	}

	d.EnsureModsCurrent()
	shellQML := filepath.Join(shellDir(), "shell.qml")

	if err := d.Run(qsBin, shellQML); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

// killPIDFile sends SIGTERM to the process recorded in the pidfile. Used
// to migrate from older yozakura builds that don't expose system.shutdown.
func killPIDFile() {
	if pid := readPIDFile(); pid > 0 {
		_ = syscall.Kill(pid, syscall.SIGTERM)
	}
}

// readPIDFile returns the pid recorded by the running daemon, or 0.
func readPIDFile() int {
	data, err := os.ReadFile(pidPath())
	if err != nil {
		return 0
	}
	pid, err := strconv.Atoi(strings.TrimSpace(string(data)))
	if err != nil || pid <= 0 {
		return 0
	}
	return pid
}

func shellDir() string {
	if dir := paths.FindShellSource(); dir != "" {
		return dir
	}
	return filepath.Join(os.Getenv("HOME"), ".local/src", brand.AppID)
}

func defaultPresetDir() string {
	return filepath.Join(shellDir(), "assets", "presets", brand.DisplayName+" Default")
}

func runDetached(cmd string) {
	exec.Command("sh", "-c", cmd).Start()
}

func execCommand(name string, args ...string) {
	cmd := exec.Command(name, args...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

// restartShell triggers a full restart by asking the running instance to
// shut down via IPC, waiting for it to actually die, and re-execing
// ourselves in the background.
func restartShell() {
	// Concurrent reloads collapse into one: the loser waits for the winner
	// to finish and does nothing, instead of racing it into a second daemon.
	rl, err := instancelock.TryAcquire(instancelock.ReloadPath())
	if err != nil {
		var held *instancelock.HeldError
		if errors.As(err, &held) {
			instancelock.WaitFree(instancelock.ReloadPath(), 15*time.Second)
			return
		}
		fmt.Fprintf(os.Stderr, "Error: reload lock: %v\n", err)
		os.Exit(1)
	}
	defer rl.Release()
	if !restartShellLocked(startDaemon) {
		os.Exit(1)
	}
}

// restartShellLocked stops the running instance and starts a replacement.
// The caller holds the reload lock. start launches the new daemon. It
// reports false when the old instance would not exit (nothing is started).
func restartShellLocked(start func()) bool {
	if isAlive() {
		pid := readPIDFile()
		_, _ = newClient().Call("system.shutdown", nil)
		waitForDeath(pid, stopWait)
	}
	// The old instance releases its lock only when it exits; starting
	// earlier would make the new daemon refuse as "already running".
	if !instancelock.WaitFree(instancelock.AppPath(), stopWait) && !forceStopHolder() {
		fmt.Fprintf(os.Stderr, "Error: the previous %s instance did not exit; not starting another\n", brand.AppID)
		return false
	}
	start()
	// Hold the reload lock until the new daemon owns the instance lock, so
	// a reload right behind this one sees it alive and restarts it.
	deadline := time.Now().Add(startWait)
	for time.Now().Before(deadline) {
		if _, held := instancelock.Held(instancelock.AppPath()); held {
			break
		}
		time.Sleep(25 * time.Millisecond)
	}
	return true
}

// Reload timeouts and process hooks; tests swap them.
var (
	stopWait  = 5 * time.Second
	killWait  = 2 * time.Second
	startWait = 3 * time.Second

	isOurProcess = processIsThisExecutable
	signalPID    = syscall.Kill
)

// forceStopHolder SIGTERMs, then SIGKILLs, the process holding the instance
// lock, but only when it is this very executable. Reports whether the lock
// ended up free.
func forceStopHolder() bool {
	pid, held := instancelock.Held(instancelock.AppPath())
	if !held {
		return true
	}
	if pid <= 0 || !isOurProcess(pid) {
		return false
	}
	_ = signalPID(pid, syscall.SIGTERM)
	if instancelock.WaitFree(instancelock.AppPath(), killWait) {
		return true
	}
	_ = signalPID(pid, syscall.SIGKILL)
	return instancelock.WaitFree(instancelock.AppPath(), killWait)
}

// processIsThisExecutable reports whether pid runs the same binary as we do.
func processIsThisExecutable(pid int) bool {
	self, err := os.Readlink("/proc/self/exe")
	if err != nil {
		return false
	}
	other, err := os.Readlink(fmt.Sprintf("/proc/%d/exe", pid))
	if err != nil {
		return false
	}
	trim := func(p string) string { return strings.TrimSuffix(p, " (deleted)") }
	return trim(self) == trim(other)
}

// startDaemon launches the replacement daemon; tests swap it.
var startDaemon = startDetachedDaemon

func startDetachedDaemon() {
	exe, _ := os.Executable()
	cmd := exec.Command(exe)
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	if err := cmd.Start(); err == nil {
		cmd.Process.Release()
	}
}

// waitForDeath waits until the old instance (pid, 0 if unknown) has exited,
// not merely closed its socket: shutdown closes IPC first and only then
// tears down its children, so starting a replacement as soon as the socket
// vanished let the old teardown kill the new instance's children.
func waitForDeath(pid int, timeout time.Duration) {
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		if !isAlive() && !processRunning(pid) {
			return
		}
		time.Sleep(50 * time.Millisecond)
	}
}

// processRunning reports whether pid is a live (non-zombie) process.
func processRunning(pid int) bool {
	if pid <= 0 {
		return false
	}
	if err := syscall.Kill(pid, 0); err != nil && !errors.Is(err, syscall.EPERM) {
		return false
	}
	data, err := os.ReadFile(fmt.Sprintf("/proc/%d/stat", pid))
	if err != nil {
		return !errors.Is(err, os.ErrNotExist)
	}
	// Field 3 follows the parenthesised command name, which may itself
	// contain spaces or parens.
	stat := string(data)
	if i := strings.LastIndexByte(stat, ')'); i >= 0 && i+2 < len(stat) {
		switch stat[i+2] {
		case 'Z', 'X':
			return false
		}
	}
	return true
}

// quitShell asks the running instance to shut down. Falls back to a
// pkill sweep only if the daemon is unresponsive (no socket, no pidfile).
func quitShell() {
	if isAlive() {
		pid := readPIDFile()
		if _, err := newClient().Call("system.shutdown", nil); err == nil {
			waitForDeath(pid, 5*time.Second)
			fmt.Println(brand.DisplayName + " stopped.")
			return
		}
	}
	cleanupOrphans()
	fmt.Println(brand.DisplayName + " stopped.")
}

func cleanupOrphans() {
	exec.Command("pkill", "-f", `tail -f .*`+brand.AppID+`_ipc\.pipe`).Run()
	exec.Command("pkill", "-f", brand.Daemon+".*daemon").Run()
	exec.Command("pkill", "-f", brand.Daemon+" subscribe").Run()
	migrate.StopLegacyDaemon()
	exec.Command("pkill", "-f", "qs.*shell.qml").Run()
	exec.Command("pkill", "-f", "wl-paste --watch").Run()
	_ = os.Remove(ipcPipePath())
	_ = os.Remove("/tmp/" + brand.AppID + "_ipc.pipe")
}

// ipcPipePath resolves the per-user FIFO the Quickshell keybind listener
// reads from; /run/user/<uid> keeps it out of the shared /tmp namespace.
func ipcPipePath() string {
	if runtime := os.Getenv("XDG_RUNTIME_DIR"); runtime != "" {
		return filepath.Join(runtime, brand.AppID+"_ipc.pipe")
	}
	return fmt.Sprintf("/run/user/%d/%s_ipc.pipe", os.Getuid(), brand.AppID)
}

// defaultTMUXTmpDir resolves the tmux socket directory for the daemon's
// process tree: tmux picks its server socket from TMUX_TMPDIR, so aligning
// it with XDG_RUNTIME_DIR keeps Yozakura-spawned tmux on the same server as
// the user's shells. An existing value always wins.
func defaultTMUXTmpDir(current, xdgRuntime string) string {
	if current != "" {
		return current
	}
	return xdgRuntime
}

func showHelp() {
	fmt.Print(branded(`{name} CLI - Desktop Environment Control

Usage: {bin} [COMMAND]

Commands:
    (none)                            Launch {name}
    update                           Update {name} (pull, rebuild, reinstall)
    doctor [-v] [--with f,...]       Check every dependency; prints the install command
    refresh                          Refresh local/dev profile (for developers)
    lock                             Activate lockscreen
    run <command>                    Send a UI command to the shell
    toggle <command>                 Toggle a shell feature (e.g. bar)
    cmd [list | <command> [arg]]     Run a launcher command ("dnd", "glass 0.6",
                                     "preset <name>"; {bin} cmd list)
    launch <desktop-id>              Start an installed app like the launcher does
    onboarding                       Open the welcome / setup wizard again
    onboarding --dry-run [--keep]    Click through the wizard without changing anything
    reload                           Restart {name}
    quit                             Stop {name}
    screen [on|off]                  Control DPMS
    suspend                          Suspend the system
    brightness <percent> [monitor]   Set brightness (0-100)
    brightness +/-<delta> [monitor]  Adjust brightness relatively
    brightness -s [monitor]          Save current brightness
    brightness -r [monitor]          Restore saved brightness
    brightness -l                    List monitors and their brightness
    install <target>                 Install compositor config (hyprland, niri, mango)
    install hyprland --exclusive     Make {name} the only shell (backs up ~/.config/hypr);
    install --restore [--from DIR]   undo it ({bin} install hyprland --exclusive --help)
    remove <target>                  Remove compositor config (hyprland, niri, mango)
    colorpicker                      Pick a screen color (interactive loupe)
    lockwall <wallpaper> <data>      Extract lockscreen frame from video/GIF
    thumbs <config> <cache> [fall] [extra...]  Generate wallpaper thumbnails (140x140)
    dthumbs <dir> <cache>            Generate desktop thumbnails (64x64)
    schemes <image>                  Palette of every matugen scheme (JSON, cached)
    ipc call <method> <json>         Send a raw JSON-RPC call to the daemon
    wallpaper <file>                Set wallpaper (with optional flags)
        -scheme <name>              Use a specific matugen color scheme
        -oled                       Enable OLED mode for this wallpaper only
        -tint                       Enable tint for this wallpaper only
        -monitor <id|name>          Apply to a specific monitor
    config <command>                 Read/change settings: list, get, set, toggle, describe,
                                     reset, search, schema, path ({bin} config help)
    preset <command>                 Presets: list, apply, save, diff, export, import
                                     ({bin} preset help; "{bin} preset <name>" applies)
    special <command>                Special workspaces: list, open, add, set, remove,
                                     app add|remove, import-binds ({bin} special help)
    timer <time> [name]              Start a timer ("10m tea", "1h30", "18:00"); list, pause,
                                     resume, add, stop, pomodoro ({bin} timer help)
    stopwatch [start|pause|lap|reset] Stopwatch (no argument: status)
    remind <time|in time> <text>     Reminder ("18:00 call mom", "in 20m stretch"); list, cancel
    focus [start [min]|stop|status]  Focus mode: DND + countdown ({bin} focus help)
    routine <command>                Routines (step lists): list, show, run, save, delete
    task <command>                   AI coding tasks in git worktrees: new, list, show, run,
                                     accept, discard, followup ({bin} task help)
    binds <command>                  Keybind advisor: search, list, check, suggest, set,
                                     rm, undo ({bin} binds help)
    completion <bash|zsh|fish>       Print a shell completion script
    mods [command]                   Manage {name} modifications
    mcp [--list-tools]               Run the built-in MCP server on stdio (for AI agents)
    voice press <ai|dictation>       Voice input: start (or stop) listening
    voice release|stop|cancel        Voice input: end a hold / finish / discard
    voice status|warm|unload         Voice input: state, preload or stop whisper
    usage [today|week|month] [--by provider|model|day]
                                     AI token usage and cost (--json for raw)
    usage limits                     AI subscription limits (Claude, Codex)
    display [list|set|identify]      Monitors: mode, refresh rate, scale, rotation; set asks to
                                     keep (auto-revert in 15 s) ({bin} display help)
    keyboard [list|add|remove|next]  Keyboard layouts and the layout switch key
                                     ({bin} keyboard help)
    providers [list|test <p>|ollama] AI chat providers: connected ones and their models,
                                     test one, installed Ollama models ({bin} providers help)
    extras [list|install <id>...|status <id>]
                                     Apps and tools the shell can install ({bin} extras help)
    term [list|set <preset>|preview <preset>|status|off]
                                     Fish prompt (Starship / oh-my-posh) in the shell palette
                                     ({bin} term help)
    help                             Show this help message
    version, -v, --version           Show {name} version
    goodbye [--purge]                Uninstall {name} (--purge: also models, venvs, logs)
`))
}

// branded fills the {name} / {bin} placeholders of user-facing text.
func branded(s string) string {
	return strings.NewReplacer("{name}", brand.DisplayName, "{bin}", brand.AppID).Replace(s)
}

func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}
