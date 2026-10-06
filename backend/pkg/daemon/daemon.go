package daemon

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"sync"
	"syscall"
	"time"
	"yozakura/backend/pkg/brand"

	"yozakura/backend/pkg/ipc"
	"yozakura/backend/pkg/mods"
	"yozakura/backend/pkg/paths"
	"yozakura/backend/pkg/svc"
	"yozakura/backend/pkg/svc/agents"
	apphookssvc "yozakura/backend/pkg/svc/apphooks"
	"yozakura/backend/pkg/svc/caffeine"
	"yozakura/backend/pkg/svc/clipboard"
	"yozakura/backend/pkg/svc/compositor"
	configsvc "yozakura/backend/pkg/svc/config"
	"yozakura/backend/pkg/svc/displays"
	"yozakura/backend/pkg/svc/focus"
	"yozakura/backend/pkg/svc/fsbrowse"
	"yozakura/backend/pkg/svc/gamemode"
	"yozakura/backend/pkg/svc/keyboard"
	"yozakura/backend/pkg/svc/keystore"
	"yozakura/backend/pkg/svc/linkpreview"
	mcpsvc "yozakura/backend/pkg/svc/mcp"
	"yozakura/backend/pkg/svc/network"
	nightlight "yozakura/backend/pkg/svc/nightlight"
	notifysvc "yozakura/backend/pkg/svc/notify"
	ocrsvc "yozakura/backend/pkg/svc/ocr"
	"yozakura/backend/pkg/svc/powerprofile"
	"yozakura/backend/pkg/svc/preset"
	"yozakura/backend/pkg/svc/providers"
	recordersvc "yozakura/backend/pkg/svc/recorder"
	"yozakura/backend/pkg/svc/screenshot"
	"yozakura/backend/pkg/svc/sleep"
	"yozakura/backend/pkg/svc/systemmonitor"
	"yozakura/backend/pkg/svc/tasks"
	"yozakura/backend/pkg/svc/timers"
	"yozakura/backend/pkg/svc/transfers"
	"yozakura/backend/pkg/svc/usage"
	voicesvc "yozakura/backend/pkg/svc/voice"
	"yozakura/backend/pkg/svc/wallpaper"
	"yozakura/backend/pkg/svc/weather"
)

// Daemon is the unified yozakura process. It owns the IPC server, all
// background services (clipboard, sleep, compositor, …) and the Quickshell
// child. A single binary acts as both launcher and daemon: this struct's
// Run() method replaces the previous "launch + detached daemon" dance and
// guarantees a clean shutdown of every child the process spawned.
type Daemon struct {
	paths *paths.Paths
	srv   *ipc.Server

	ui         *svc.UIService
	sleep      *sleep.Service
	clipboard  *clipboard.Service
	network    *network.Service
	compositor *compositor.Service
	displays   *displays.Service
	caffeine   *caffeine.Service
	gamemode   *gamemode.Service
	powerprof  *powerprofile.Service
	nightlight *nightlight.Service
	recorder   *recordersvc.Service
	mcp        *mcpsvc.Service
	voice      *voicesvc.Service
	mods       *mods.Manager
	agents     *agents.Manager
	notify     *notifysvc.Service
	timers     *timers.Service
	usage      *usage.Service
	tasks      *tasks.Manager

	shutdownCh   chan struct{}
	shutdownOnce sync.Once

	qsCmd  *exec.Cmd
	qsDone <-chan error

	// sweep kills stray helpers left after shutdown (nil in tests).
	sweep func()
}

// New wires every service into a freshly constructed server. The caller is
// expected to call Run() next.
func New() (*Daemon, error) {
	p := paths.New()
	d := &Daemon{
		paths:      p,
		srv:        ipc.NewServer(p.SocketPath()),
		shutdownCh: make(chan struct{}),
		sweep:      sweepStrayHelpers,
	}

	// Migrate states.json before any service reads from it. Idempotent.
	configSvc := configsvc.NewService(p)
	if err := configSvc.MigrateStates(); err != nil {
		log.Printf("[yozakura] states migrate: %v", err)
	}

	uiSvc := svc.NewUIService()
	uiSvc.Register(d.srv)

	sysMon := systemmonitor.NewService(2000, []string{"/"})
	sysMon.Register(d.srv)

	sleepSvc, err := sleep.NewService()
	if err != nil {
		return nil, fmt.Errorf("sleep service: %w", err)
	}
	d.sleep = sleepSvc
	sleepSvc.Register(d.srv)

	weatherSvc := weather.NewService()
	weatherSvc.Register(d.srv)

	clipSvc := clipboard.NewService(d.paths)
	clipSvc.Register(d.srv)
	d.clipboard = clipSvc

	netSvc := network.NewService()
	netSvc.Register(d.srv)
	d.network = netSvc

	// Brightness lives in yozd now; the yozakura CLI is a thin shim that
	// shells out to it (see backend/cmd/yozakura/brightness.go).

	configSvc.Register(d.srv)

	compSvc := compositor.NewService(d.paths)
	compSvc.Register(d.srv)
	d.compositor = compSvc

	d.displays = displays.NewService(d.paths)
	d.displays.Register(d.srv)
	var layoutSrc keyboard.StateSource
	if m := compSvc.Manager(); m != nil {
		layoutSrc = m
	}
	keyboard.NewService(layoutSrc).Register(d.srv)
	apphookssvc.NewService().Register(d.srv)

	keySvc := keystore.NewService(d.paths)
	keySvc.Register(d.srv)

	linkSvc := linkpreview.NewService()
	linkSvc.Register(d.srv)
	fsbrowse.NewService().Register(d.srv)

	gmSvc := gamemode.NewService(d.paths)
	gmSvc.Register(d.srv)
	d.gamemode = gmSvc
	compSvc.SetGameModeFn(gmSvc.IsEnabled)

	caffeineSvc := caffeine.NewService(d.paths)
	caffeineSvc.Register(d.srv)
	d.caffeine = caffeineSvc

	powerprofSvc := powerprofile.NewService()
	powerprofSvc.Register(d.srv)
	d.powerprof = powerprofSvc

	nlSvc := nightlight.NewService(d.paths)
	nlSvc.Register(d.srv)
	d.nightlight = nlSvc

	wallpaperSvc := wallpaper.NewService()
	wallpaperSvc.Register(d.srv)

	presetSvc := preset.NewService(d.paths)
	presetSvc.Register(d.srv)

	modsManager := mods.NewManager(d.paths)
	modsSvc := mods.NewService(modsManager)
	modsSvc.Register(d.srv)
	d.mods = modsManager

	shotSvc := screenshot.NewService(d.paths)
	shotSvc.Register(d.srv)

	recSvc := recordersvc.NewService(d.paths)
	recSvc.Register(d.srv)
	d.recorder = recSvc

	ocrSvc := ocrsvc.NewService()
	ocrSvc.Register(d.srv)

	// notify — exposes notify.send so CLIs (colorpicker, screen, …) can
	// route their notifications through the running shell instead of
	// shelling out to notify-send. See pkg/svc/notify for the rationale.
	notifySvc := notifysvc.NewService()
	notifySvc.Register(d.srv)
	d.notify = notifySvc

	// Timers, stopwatch, reminders (persisted, wall clock); finished
	// timers notify through notify.Send. The scheduler starts in Run.
	d.timers = timers.NewService(timers.Options{
		Path:     filepath.Join(p.DataDir, timers.FileName),
		Notify:   func(sp notifysvc.SendParams) { _, _ = notifySvc.Send(sp) },
		Pomodoro: func() timers.PomodoroConfig { return timers.SystemPomodoro(p.Config("system")) },
	})
	d.timers.Register(d.srv)
	// Focus mode as the shell reports it (CLI/MCP read it).
	focus.NewService(func(id string) (timers.Timer, bool) {
		for _, t := range d.timers.View().Timers {
			if t.ID == id {
				return t, true
			}
		}
		return timers.Timer{}, false
	}).Register(d.srv)

	// AI usage ledger + subscription limits (see pkg/svc/usage). The
	// agents service can feed it through usage.Recorder / usage.LimitsSink.
	d.usage = usage.NewService(usage.Options{
		Dir:            usage.DefaultDir(p.DataDir),
		Prices:         usage.LoadPrices(usage.BundledPricesPath(paths.FindShellSource()), usage.OverridePricesPath(p.ConfigDir)),
		PricesOverride: usage.OverridePricesPath(p.ConfigDir),
		ClaudeFetch:    usage.NewClaudeFetcher().Fetch,
		Notify: func(sp notifysvc.SendParams) {
			sp.AppIcon, sp.ReplaceKey = "dialog-warning", "usage-limit"
			_, _ = notifySvc.Send(sp)
		},
	})
	d.usage.Register(d.srv)

	// CLI coding agents (Claude Code, Codex, OpenCode) for the AI center.
	agentsMgr := agents.NewManager(filepath.Join(p.DataDir, "agents"))
	agents.NewService(agentsMgr).Register(d.srv)
	d.agents = agentsMgr
	// AI-first coding tasks: worktrees, verify loop, review/accept.
	d.tasks = newTasks(d.srv, p, agentsMgr, notifySvc, uiSvc)
	// Chat providers: Ollama probe, connection tests, model capability table.
	provSvc := providers.NewService(p)
	provSvc.SetCredentials(func() []providers.Credential {
		var out []providers.Credential
		for _, c := range keySvc.Credentials() {
			out = append(out, providers.Credential{Provider: c.Provider, Key: c.APIKey, Endpoint: c.Endpoint})
		}
		return out
	})
	provSvc.Register(d.srv)
	// Local speech-to-text (whisper.cpp server started on demand).
	d.voice = voicesvc.NewService(d.paths)
	d.voice.Register(d.srv)

	// Live activity downloads/copies/updates; sources start on demand.
	transfers.NewService().Register(d.srv)

	// MCP: imported servers (Claude Code, Codex, OpenCode) + the built-in
	// Yozakura tools; proxies tools for chat models and feeds CLI agents.
	d.mcp = mcpsvc.NewService()
	d.mcp.Register(d.srv)
	agentsMgr.SetUsageSink(d.usage)
	// Routines: deterministic step lists (bind actions, built-in tools).
	agentsMgr.SetConfirmGate(routineGate{svc: newRoutines(d.srv, p, d.mcp, notifySvc)})
	agentsMgr.SetMCPProvider(func() []agents.MCPServer {
		specs := d.mcp.EnabledSpecs()
		out := make([]agents.MCPServer, 0, len(specs))
		for _, sp := range specs {
			out = append(out, agents.MCPServer{
				Name: sp.Name, Transport: sp.Transport, Command: sp.Command, Args: sp.Args,
				Env: sp.Env, URL: sp.URL, Headers: sp.Headers,
			})
		}
		return out
	})

	// system.shutdown → triggers the same exit path as a terminal signal.
	d.srv.Register(&ipc.Service{
		Name: "system",
		Methods: map[string]ipc.HandlerFunc{
			"shutdown": func(_ json.RawMessage) (any, error) {
				d.TriggerShutdown()
				return "ok", nil
			},
		},
	})

	d.ui = uiSvc
	return d, nil
}

// MCP returns the MCP service (the agents service reads EnabledSpecs).
func (d *Daemon) MCP() *mcpsvc.Service { return d.mcp }

// Server returns the underlying IPC server. Exposed for advanced callers
// (e.g. tests) that need to issue calls directly.
func (d *Daemon) Server() *ipc.Server { return d.srv }

// EnsureModsCurrent recomposes a stale mod generation before Quickshell is
// spawned. Failures are logged and ignored: the shell still starts, either
// from the previous generation or the base source, and the mods panel keeps
// offering a manual rebuild. Must run before the caller resolves the shell
// path, so FindShellSource picks the fresh generation.
func (d *Daemon) EnsureModsCurrent() {
	if d.mods == nil {
		return
	}
	if err := d.mods.EnsureCurrentGeneration(); err != nil {
		log.Printf("[yozakura] mods auto-rebuild: %v", err)
	}
}

// TriggerShutdown requests a graceful shutdown. Safe to call multiple
// times; only the first call has any effect.
func (d *Daemon) TriggerShutdown() {
	d.shutdownOnce.Do(func() { close(d.shutdownCh) })
}

// Run blocks until the Quickshell child exits, an IPC shutdown is
// requested, or a terminating signal is received. On exit it tears down
// every child it owns in the right order:
//
//  1. close the IPC listener (refuse new connections)
//  2. SIGTERM → Quickshell; SIGKILL its process group if it ignores
//  3. compositor.Close()  → yozd daemon + yozd subscribe
//  4. clipboard.Close()   → wl-paste --watch
//  5. sleep.Close()       → dbus connection
func (d *Daemon) Run(qsBin, shellQML string) error {
	if err := d.srv.Listen(); err != nil {
		return fmt.Errorf("ipc listen: %w", err)
	}
	pidPath := pidFile()
	_ = os.WriteFile(pidPath, []byte(fmt.Sprintf("%d\n", os.Getpid())), 0o644)
	defer os.Remove(pidPath)
	defer d.srv.Close()

	if err := d.compositor.Manager().Start(); err != nil {
		log.Printf("[yozakura] compositor manager: %v (continuing)", err)
	}

	// Caffeine + Nightlight restore both depend on side effects that may
	// not be ready immediately: caffeine needs the yozd daemon socket
	// (spun up by the compositor service above), nightlight needs wlsunset
	// on PATH. Run them in a goroutine after a short delay so the yozd
	// child has time to bind its socket.
	go func() {
		time.Sleep(500 * time.Millisecond)
		if d.caffeine != nil {
			if _, err := d.caffeine.Restore(nil); err != nil {
				log.Printf("[yozakura] caffeine restore: %v", err)
			}
		}
		if d.nightlight != nil {
			if _, err := d.nightlight.Restore(nil); err != nil {
				log.Printf("[yozakura] nightlight restore: %v", err)
			}
		}
	}()

	// Timers that expired while the daemon was down fire on the first poll;
	// wait for the shell's notify subscription so their notifications show.
	go func() {
		deadline := time.Now().Add(30 * time.Second)
		for d.notify.Subscribers() == 0 && time.Now().Before(deadline) {
			time.Sleep(250 * time.Millisecond)
		}
		d.timers.Start()
		d.tasks.Start()
	}()

	if err := d.spawnQS(qsBin, shellQML); err != nil {
		return fmt.Errorf("spawn qs: %w", err)
	}

	go d.srv.Serve()

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM, syscall.SIGHUP)
	defer signal.Stop(sigCh)

	d.qsDone = waitForProcess(d.qsCmd)
	var healthTimer *time.Timer
	var healthCh <-chan time.Time
	if d.mods != nil && d.mods.HasPendingActivation() {
		healthTimer = time.NewTimer(8 * time.Second)
		healthCh = healthTimer.C
	}
	defer func() {
		if healthTimer != nil {
			healthTimer.Stop()
		}
	}()

	for {
		select {
		case s := <-sigCh:
			log.Printf("[yozakura] received %v, shutting down", s)
			d.shutdown()
			return nil
		case <-d.shutdownCh:
			log.Printf("[yozakura] shutdown requested via IPC")
			d.shutdown()
			return nil
		case <-healthCh:
			if err := d.mods.MarkHealthy(); err != nil {
				log.Printf("[yozakura] mod activation health check: %v", err)
			}
			healthCh = nil
		case err := <-d.qsDone:
			log.Printf("[yozakura] qs exited: %v", err)
			d.qsCmd = nil
			d.qsDone = nil
			if healthCh != nil {
				recovered, recoverErr := d.mods.RecoverFailedActivation()
				if recoverErr != nil {
					log.Printf("[yozakura] mod activation rollback: %v", recoverErr)
				}
				healthCh = nil
				if recovered {
					fallback := filepath.Join(paths.FindShellSource(), "shell.qml")
					log.Printf("[yozakura] retrying with previous shell generation")
					if spawnErr := d.spawnQS(qsBin, fallback); spawnErr != nil {
						d.shutdown()
						return fmt.Errorf("spawn rollback shell: %w", spawnErr)
					}
					d.qsDone = waitForProcess(d.qsCmd)
					continue
				}
			}
			d.shutdown()
			return nil
		}
	}
}

func waitForProcess(cmd *exec.Cmd) <-chan error {
	done := make(chan error, 1)
	go func() { done <- cmd.Wait() }()
	return done
}

// spawnQS launches Quickshell as a child of the current process, in its
// own process group so a single SIGKILL cleans up all of qs's descendants.
func (d *Daemon) spawnQS(qsBin, shellQML string) error {
	cmd := exec.Command(qsBin, "-p", shellQML)
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	env := os.Environ()
	if os.Getenv("MALLOC_CONF") == "" {
		env = append(env, "MALLOC_CONF=dirty_decay_ms:1000,muzzy_decay_ms:1000")
	}
	if os.Getenv("QT_MEDIA_BACKEND") == "" {
		env = append(env, "QT_MEDIA_BACKEND=gstreamer")
	}
	cmd.Env = env
	if err := cmd.Start(); err != nil {
		return err
	}
	d.qsCmd = cmd
	// Publish the Quickshell PID so sibling CLI invocations can dispatch
	// `qs ipc` calls back into the running shell (e.g. `yozakura brightness`
	// notifying the QML IpcHandler so the OSD fires on keybind).
	if pidPath := d.paths.QsPidFile(); pidPath != "" {
		_ = os.WriteFile(pidPath, []byte(fmt.Sprintf("%d\n", cmd.Process.Pid)), 0o644)
	}
	return nil
}

func (d *Daemon) shutdown() {
	// Refuse new IPC first: a request arriving mid-teardown could otherwise
	// start agent processes or MCP servers after their owners shut down.
	d.srv.Close()
	if d.qsCmd != nil && d.qsCmd.Process != nil {
		_ = d.qsCmd.Process.Signal(syscall.SIGTERM)
		if d.qsDone != nil {
			select {
			case <-d.qsDone:
			case <-time.After(1500 * time.Millisecond):
				if pgid, err := syscall.Getpgid(d.qsCmd.Process.Pid); err == nil && pgid > 0 {
					_ = syscall.Kill(-pgid, syscall.SIGKILL)
				} else {
					_ = d.qsCmd.Process.Kill()
				}
				<-d.qsDone
			}
		}
		if pidPath := d.paths.QsPidFile(); pidPath != "" {
			_ = os.Remove(pidPath)
		}
		d.qsCmd = nil
		d.qsDone = nil
	}

	if d.displays != nil {
		d.displays.Close() // reverts an unconfirmed change while yozd is still up
	}
	if d.compositor != nil && d.compositor.Manager() != nil {
		d.compositor.Manager().Close()
	}
	if d.clipboard != nil {
		d.clipboard.Close()
	}
	if d.tasks != nil {
		d.tasks.Close() // before agents: their exits must not fail the runs
	}
	if d.agents != nil {
		d.agents.Shutdown()
	}
	if d.sleep != nil {
		d.sleep.Close()
	}
	if d.nightlight != nil {
		d.nightlight.Close()
	}
	if d.recorder != nil {
		d.recorder.Close()
	}
	if d.mcp != nil {
		d.mcp.Close()
	}
	if d.voice != nil {
		d.voice.Close()
	}
	if d.timers != nil {
		d.timers.Close()
	}
	if d.usage != nil {
		d.usage.Close()
	}

	if d.sweep != nil {
		d.sweep()
	}
}

// strayHelperPatterns are `pkill -f` patterns for helpers that can escape
// the process-group cleanup (e.g. tail -f on a FIFO that survived
// Quickshell's SIGTERM). The sweep runs after the IPC socket is closed, when
// a `reload` replacement may already be starting, so it must never match
// children an instance owns and stops itself (yozd daemon/subscribe via the
// compositor Manager, wl-paste via clipboard, wlsunset via nightlight):
// a global pkill of those killed the new instance's yozd daemon.
var strayHelperPatterns = []string{
	`tail -f .*` + brand.AppID + `_ipc\.pipe`,
}

// sweepStrayHelpers is the defensive sweep over strayHelperPatterns.
// Cheap and idempotent.
func sweepStrayHelpers() {
	for _, p := range strayHelperPatterns {
		_ = exec.Command("pkill", "-f", p).Run()
	}
}

// pidFile returns the daemon pid file path. Kept in sync with
// backend/cmd/yozakura/main.go so other invocations can probe the running
// process without touching the IPC socket.
func pidFile() string {
	if runtime := os.Getenv("XDG_RUNTIME_DIR"); runtime != "" {
		return filepath.Join(runtime, brand.AppID+".pid")
	}
	return "/tmp/" + brand.AppID + ".pid"
}

// EnsureConfigFiles copies preset JSON defaults if missing (legacy ensure_config_files).
func EnsureConfigFiles(p *paths.Paths, presetDir string) error {
	domains := []string{"theme", "bar", "workspaces", "overview", "notch", "compositor", "performance", "weather", "desktop", "lockscreen", "prefix", "system", "dock", "ai", "general"}
	configDir := filepath.Join(p.ConfigDir, "config")
	if err := os.MkdirAll(configDir, 0o755); err != nil {
		return err
	}
	for _, domain := range domains {
		dst := filepath.Join(configDir, domain+".json")
		if _, err := os.Stat(dst); err == nil {
			continue
		}
		src := filepath.Join(presetDir, domain+".json")
		data, err := os.ReadFile(src)
		if err != nil {
			continue
		}
		if err := os.WriteFile(dst, data, 0o644); err != nil {
			return err
		}
	}
	return nil
}
