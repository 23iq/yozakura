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
	"yozakura/backend/pkg/migrate"

	"yozakura/backend/pkg/daemon"
	"yozakura/backend/pkg/ipc"
	"yozakura/backend/pkg/paths"
)

var version = "dev"

func main() {
	ensureSelfOnPath()
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
			runGoodbye()
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

// isAlive returns true only when the daemon is actually reachable: the
// socket file exists, a process is listening on it, and the PID file
// points to a live process. Stale state from previous crashes is cleaned
// up so a subsequent launch can spawn a fresh instance.
func isAlive() bool {
	sock := socketPath()

	info, err := os.Stat(sock)
	if err != nil || info.Mode()&os.ModeSocket == 0 {
		return false
	}

	c, err := net.DialTimeout("unix", sock, 500*time.Millisecond)
	if err != nil {
		os.Remove(sock)
		os.Remove(pidPath())
		return false
	}
	c.Close()

	if data, err := os.ReadFile(pidPath()); err == nil {
		pidStr := strings.TrimSpace(string(data))
		if pid, err := strconv.Atoi(pidStr); err == nil {
			if proc, err := os.FindProcess(pid); err == nil {
				if err := proc.Signal(syscall.Signal(0)); err != nil {
					os.Remove(sock)
					os.Remove(pidPath())
					return false
				}
			}
		}
	}
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
	if isAlive() {
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
	if isAlive() {
		pid := readPIDFile()
		_, _ = newClient().Call("system.shutdown", nil)
		waitForDeath(pid, 5*time.Second)
	}
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
    goodbye                          Uninstall {name}
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
