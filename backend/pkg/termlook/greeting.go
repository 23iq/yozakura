package termlook

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"yozakura/backend/pkg/apphooks"
	"yozakura/backend/pkg/brand"
)

// The greeting: fastfetch when a terminal opens, in fish, bash and zsh,
// independent of the prompt. Everything it writes is owned and removable:
//
//	<config>/<app>/fastfetch.jsonc        the generated fastfetch config
//	<config>/<app>/fastfetch-kitty.jsonc  the same with a picture logo (kitty)
//	<config>/<app>/fastfetch-logo.txt     the bundled text logo
//	<config>/<app>/greeting.sh            sourced by bash and zsh
//	<config>/fish/conf.d/<app>-greeting.fish
//	~/.bashrc, ~/.zshrc                   one marked line sourcing greeting.sh
//
// The user's own fastfetch config is never read or written: the "own"
// preset runs plain fastfetch.

// GreetingConfig is the terminal domain subset the greeting writer needs.
type GreetingConfig struct {
	On       bool   // terminal.greeting == "fastfetch"
	Preset   string // terminal.fastfetchPreset
	Logo     string // terminal.fastfetchLogo
	LogoPath string // terminal.fastfetchLogoPath
	// LoginShell is the user's shell (passwd): its rc file is created when
	// missing; other shells' rc files are only edited when they exist.
	LoginShell string
}

// Shell greeting states.
const (
	ShellOn      = "on"      // the greeting runs there
	ShellOff     = "off"     // greeting off
	ShellForeign = "foreign" // the user's own files run a fetch tool already
	ShellManaged = "managed" // the rc file is read-only / in the Nix store
	ShellAbsent  = "absent"  // the shell is not installed (or no rc file)
	ShellError   = "error"
)

// ShellGreeting is the state of one shell.
type ShellGreeting struct {
	Shell string `json:"shell"` // fish | bash | zsh
	State string `json:"state"`
	File  string `json:"file,omitempty"` // the rc / conf.d file, or the foreign one
}

// GreetingStatus is what the settings page shows.
type GreetingStatus struct {
	On                 bool            `json:"on"`
	FastfetchInstalled bool            `json:"fastfetchInstalled"`
	OwnConfig          bool            `json:"ownConfig"` // ~/.config/fastfetch has a config
	Shells             []ShellGreeting `json:"shells"`
	LogoError          string          `json:"logoError,omitempty"`
	ImageLogo          bool            `json:"imageLogo,omitempty"` // shown in kitty, text logo elsewhere
}

const greetingVar = brand.EnvPrefix + "GREETED"

func appDir(env Env) string { return filepath.Join(env.ConfigHome, env.AppID) }

// FetchConfigFile is the generated fastfetch config.
func FetchConfigFile(env Env) string { return filepath.Join(appDir(env), "fastfetch.jsonc") }

func fetchKittyFile(env Env) string { return filepath.Join(appDir(env), "fastfetch-kitty.jsonc") }
func fetchLogoFile(env Env) string  { return filepath.Join(appDir(env), "fastfetch-logo.txt") }

// GreetingScriptFile is the script bash and zsh source.
func GreetingScriptFile(env Env) string { return filepath.Join(appDir(env), "greeting.sh") }

// FishGreetingFile is the owned fish conf.d file of the greeting.
func FishGreetingFile(env Env) string {
	return filepath.Join(env.ConfigHome, "fish", "conf.d", env.AppID+"-greeting.fish")
}

// rcMarker marks the line in ~/.bashrc and ~/.zshrc.
func rcMarker(env Env) string { return env.AppID + " fastfetch" }

func (e Env) zdotdir() string {
	if e.ZDotDir != "" {
		return e.ZDotDir
	}
	if e.ResolveZDotDir != nil {
		if d := e.ResolveZDotDir(); d != "" {
			return d
		}
	}
	return e.Home
}

func (e Env) hooksEnv() apphooks.Env {
	data := e.DataHome
	if data == "" {
		data = filepath.Join(e.Home, ".local", "share")
	}
	return apphooks.Env{Home: e.Home, ConfigHome: e.ConfigHome, DataDir: filepath.Join(data, e.AppID), AppID: e.AppID}
}

// rcFile is the rc file the greeting line goes in; others are the files
// checked for a fetch tool the user runs already.
func rcFiles(shell string, env Env) (rc string, others []string) {
	switch shell {
	case "bash":
		rc = filepath.Join(env.Home, ".bashrc")
		for _, f := range []string{".bash_profile", ".bash_login", ".profile"} {
			others = append(others, filepath.Join(env.Home, f))
		}
	case "zsh":
		rc = filepath.Join(env.zdotdir(), ".zshrc")
		for _, f := range []string{".zprofile", ".zlogin"} {
			others = append(others, filepath.Join(env.zdotdir(), f))
		}
	}
	return rc, others
}

// shQuote single-quotes s for sh; "" for a string with control characters.
func shQuote(s string) string {
	if hasControl(s) {
		return ""
	}
	return "'" + strings.ReplaceAll(s, "'", `'\''`) + "'"
}

// fetchCmd is what the greeting runs: plain fastfetch (cfg "") or with a
// config; kitty is the picture-logo config used in kitty only ("" none).
type fetchCmd struct{ cfg, kitty string }

// GreetingScript is greeting.sh for bash and zsh. It prints only in an
// interactive shell on a terminal (never for scp/rsync/ssh commands or
// IDE probes, which have no tty or are not interactive), once per
// terminal (the tty is remembered in the environment, so a shell started
// inside it stays quiet while a new window greets), never in tmux or
// screen panes, and costs nothing when fastfetch is missing.
func greetingScript(c fetchCmd) (string, error) {
	q, k := shQuote(c.cfg), shQuote(c.kitty)
	if (c.cfg != "" && q == "") || (c.kitty != "" && k == "") {
		return "", fmt.Errorf("termlook: config path contains control characters")
	}
	fn := "__" + brand.AppID + "_greeting"
	var b strings.Builder
	b.WriteString("# Managed by " + brand.DisplayName + ". fastfetch when a terminal opens; turn it off in\n")
	b.WriteString("# Settings > Terminal (this file and the line that loads it go away).\n")
	b.WriteString(fn + "() {\n")
	b.WriteString("    case $- in *i*) ;; *) return 0 ;; esac\n")
	b.WriteString("    [ -t 0 ] && [ -t 1 ] || return 0\n")
	b.WriteString("    [ -z \"${TMUX-}\" ] && [ -z \"${STY-}\" ] || return 0\n")
	b.WriteString("    case \"${TERM-}\" in '' | dumb) return 0 ;; esac\n")
	b.WriteString("    command -v fastfetch >/dev/null 2>&1 || return 0\n")
	b.WriteString("    local t\n")
	b.WriteString("    t=$(tty 2>/dev/null) || return 0\n")
	b.WriteString("    [ \"${" + greetingVar + "-}\" = \"$t\" ] && return 0\n")
	b.WriteString("    export " + greetingVar + "=\"$t\"\n")
	if c.cfg == "" {
		b.WriteString("    fastfetch\n")
	} else {
		b.WriteString("    local c=" + q + "\n")
		if c.kitty != "" {
			b.WriteString("    if [ -n \"${KITTY_WINDOW_ID-}\" ] && [ -z \"${SSH_TTY-}${SSH_CONNECTION-}\" ]; then\n")
			b.WriteString("        c=" + k + "\n")
			b.WriteString("    fi\n")
		}
		b.WriteString("    [ -r \"$c\" ] || return 0\n")
		b.WriteString("    fastfetch --config \"$c\"\n")
	}
	b.WriteString("}\n")
	b.WriteString(fn + "\n")
	b.WriteString("unset -f " + fn + "\n")
	return b.String(), nil
}

// fishGreeting is the fish conf.d file: the same rules as greetingScript,
// as fish_greeting (fish calls it in interactive shells only). A
// fish_greeting.fish of the user's own wins.
func fishGreeting(c fetchCmd) (string, error) {
	if hasControl(c.cfg) || hasControl(c.kitty) {
		return "", fmt.Errorf("termlook: config path contains control characters")
	}
	var b strings.Builder
	b.WriteString("# Managed by " + brand.DisplayName + ". fastfetch when a terminal opens; remove this file or\n")
	b.WriteString("# turn the greeting off in Settings > Terminal.\n")
	b.WriteString("if status is-interactive; and not test -e $__fish_config_dir/functions/fish_greeting.fish\n")
	b.WriteString("    function fish_greeting\n")
	b.WriteString("        if not test -t 0; or not test -t 1; or set -q TMUX; or set -q STY; or contains -- \"$TERM\" '' dumb\n")
	b.WriteString("            return\n")
	b.WriteString("        end\n")
	b.WriteString("        type -q fastfetch; or return\n")
	b.WriteString("        set -l t (tty 2>/dev/null); or return\n")
	b.WriteString("        test \"$" + greetingVar + "\" = \"$t\"; and return\n")
	b.WriteString("        set -gx " + greetingVar + " $t\n")
	if c.cfg == "" {
		b.WriteString("        fastfetch\n")
	} else {
		b.WriteString("        set -l c " + fishQuote(c.cfg) + "\n")
		if c.kitty != "" {
			b.WriteString("        if set -q KITTY_WINDOW_ID; and not set -q SSH_TTY; and not set -q SSH_CONNECTION\n")
			b.WriteString("            set c " + fishQuote(c.kitty) + "\n")
			b.WriteString("        end\n")
		}
		b.WriteString("        test -r $c; or return\n")
		b.WriteString("        fastfetch --config $c\n")
	}
	b.WriteString("    end\n")
	b.WriteString("end\n")
	return b.String(), nil
}

// rcLine is the marked line that sources greeting.sh.
func rcLine(script string) string {
	q := shQuote(script)
	return "if [ -r " + q + " ]; then . " + q + "; fi"
}

// ApplyGreeting writes (cfg.On) or removes the greeting. presets are the
// bundled looks, sakuraLogo the bundled text logo file. Per-shell problems
// (a managed rc file, the user's own fastfetch call) are reported in the
// status, not as an error.
func ApplyGreeting(cfg GreetingConfig, pal Palette, presets []FetchPreset, sakuraLogo string, env Env) (GreetingStatus, error) {
	if env.AppID == "" || env.ConfigHome == "" || env.Home == "" {
		return GreetingStatus{}, fmt.Errorf("termlook: env needs AppID, Home and ConfigHome")
	}
	if !cfg.On {
		return GreetingState(cfg, env), RemoveGreeting(env)
	}
	p, ok := FindFetchPreset(presets, cfg.Preset)
	if !ok {
		return GreetingState(cfg, env), fmt.Errorf("termlook: unknown fastfetch preset %q", cfg.Preset)
	}
	cmd, logoErr, err := writeFetchConfigs(cfg, p, pal, sakuraLogo, env)
	if err != nil {
		return GreetingState(cfg, env), err
	}
	script, err := greetingScript(cmd)
	if err != nil {
		return GreetingState(cfg, env), err
	}
	fish, err := fishGreeting(cmd)
	if err != nil {
		return GreetingState(cfg, env), err
	}
	if err := writeAtomic(GreetingScriptFile(env), []byte(script)); err != nil {
		return GreetingState(cfg, env), err
	}
	var errs []error
	errs = append(errs, applyFish(fish, env))
	for _, sh := range []string{"bash", "zsh"} {
		errs = append(errs, applyRC(sh, cfg, env))
	}
	st := GreetingState(cfg, env)
	st.LogoError = logoErr
	return st, errors.Join(errs...)
}

// writeFetchConfigs writes the fastfetch config(s) and logo of preset p and
// returns what the greeting runs and the custom logo error ("" none).
func writeFetchConfigs(cfg GreetingConfig, p FetchPreset, pal Palette, sakuraLogo string, env Env) (fetchCmd, string, error) {
	if p.Own {
		removeFiles(FetchConfigFile(env), fetchKittyFile(env), fetchLogoFile(env))
		return fetchCmd{}, "", nil
	}
	logo, kitty, logoErr := FetchLogo{Kind: cfg.Logo}, FetchLogo{}, ""
	if cfg.Logo == LogoCustom {
		custom, err := CheckLogoPath(cfg.LogoPath)
		switch {
		case err != nil:
			logoErr, logo.Kind = LogoError(err), LogoSakura
		case custom.Kind == LogoImage:
			logo.Kind = LogoSakura // the text logo outside kitty
			kitty = FetchLogo{Kind: "kitty-direct", Source: custom.Path, Width: custom.Width, Height: custom.Height}
		case custom.Kind == LogoANSI:
			logo = FetchLogo{Kind: "file-raw", Source: custom.Path}
		default:
			logo = FetchLogo{Kind: "file", Source: custom.Path}
		}
	}
	if !p.Logo {
		logo, kitty = FetchLogo{}, FetchLogo{}
	}
	if logo.Kind == LogoSakura {
		art, err := os.ReadFile(sakuraLogo)
		if err != nil {
			return fetchCmd{}, "", fmt.Errorf("termlook: the bundled logo: %w", err)
		}
		if err := writeAtomic(fetchLogoFile(env), art); err != nil {
			return fetchCmd{}, "", err
		}
		logo = FetchLogo{Kind: "file", Source: fetchLogoFile(env)}
	} else {
		removeFiles(fetchLogoFile(env))
	}
	main, err := RenderFetch(p, pal, logo)
	if err != nil {
		return fetchCmd{}, "", err
	}
	if err := writeAtomic(FetchConfigFile(env), main); err != nil {
		return fetchCmd{}, "", err
	}
	cmd := fetchCmd{cfg: FetchConfigFile(env)}
	if kitty.Kind == "" {
		removeFiles(fetchKittyFile(env))
		return cmd, logoErr, nil
	}
	img, err := RenderFetch(p, pal, kitty)
	if err != nil {
		return fetchCmd{}, "", err
	}
	if err := writeAtomic(fetchKittyFile(env), img); err != nil {
		return fetchCmd{}, "", err
	}
	cmd.kitty = fetchKittyFile(env)
	return cmd, logoErr, nil
}

func removeFiles(paths ...string) {
	for _, p := range paths {
		_ = os.Remove(p)
	}
}

// applyFish writes the fish file unless a file of the user's runs a fetch
// tool already (then ours goes) or a file of that name is not ours.
func applyFish(content string, env Env) error {
	file := FishGreetingFile(env)
	exists, ours := hookOwned(file)
	if exists && !ours {
		return nil // not ours: reported as foreign
	}
	if foreignFetch("fish", env) != "" {
		if exists {
			return os.Remove(file)
		}
		return nil
	}
	return writeAtomic(file, []byte(content))
}

// applyRC adds the marked line to the shell's rc file (installed shells
// only; the rc file must exist unless it is the login shell) and removes
// it where the user runs a fetch tool already.
func applyRC(shell string, cfg GreetingConfig, env Env) error {
	rc, _ := rcFiles(shell, env)
	henv := env.hooksEnv()
	if shell == "zsh" {
		for _, stale := range zshRCs(env)[1:] {
			if _, err := apphooks.RevertMarkedBlock(henv, "greeting-zsh", rcMarker(env), stale); ignoreManaged(err) != nil {
				return err
			}
		}
	}
	if foreignFetch(shell, env) != "" || !shellInstalled(shell, env) {
		_, err := apphooks.RevertMarkedBlock(henv, "greeting-"+shell, rcMarker(env), rc)
		return ignoreManaged(err)
	}
	if _, err := os.Stat(rc); err != nil && filepath.Base(cfg.LoginShell) != shell {
		return nil
	}
	_, err := apphooks.UpsertMarkedBlock(henv, "greeting-"+shell, rcMarker(env), rc, rcLine(GreetingScriptFile(env)))
	return ignoreManaged(err)
}

// ignoreManaged: a read-only rc file is a state (the status says to add the
// line by hand), not a failure.
func ignoreManaged(err error) error {
	if errors.Is(err, apphooks.ErrManaged) {
		return nil
	}
	return err
}

func shellInstalled(shell string, env Env) bool {
	_, ok := env.look(shell)
	return ok
}

// RemoveGreeting removes everything the greeting wrote (turning it off,
// goodbye). Foreign files are left alone.
func RemoveGreeting(env Env) error {
	var errs []error
	removeFiles(GreetingScriptFile(env), FetchConfigFile(env), fetchKittyFile(env), fetchLogoFile(env))
	if exists, ours := hookOwned(FishGreetingFile(env)); exists && ours {
		errs = append(errs, os.Remove(FishGreetingFile(env)))
	}
	henv := env.hooksEnv()
	bashrc, _ := rcFiles("bash", env)
	for _, rc := range append([]string{bashrc}, zshRCs(env)...) {
		id := "greeting-bash"
		if rc != bashrc {
			id = "greeting-zsh"
		}
		if _, err := apphooks.RevertMarkedBlock(henv, id, rcMarker(env), rc); err != nil {
			errs = append(errs, fmt.Errorf("%s: %w", rc, err))
		}
	}
	return errors.Join(errs...)
}

// GreetingState reads what is on disk now (no writes).
func GreetingState(cfg GreetingConfig, env Env) GreetingStatus {
	st := GreetingStatus{On: cfg.On}
	_, st.FastfetchInstalled = env.look("fastfetch")
	for _, f := range []string{"config.jsonc", "config.conf"} {
		if _, err := os.Stat(filepath.Join(env.ConfigHome, "fastfetch", f)); err == nil {
			st.OwnConfig = true
		}
	}
	if cfg.On && cfg.Logo == LogoCustom && cfg.Preset != FetchOwn {
		custom, err := CheckLogoPath(cfg.LogoPath)
		st.LogoError = LogoError(err)
		st.ImageLogo = err == nil && custom.Kind == LogoImage
	}
	for _, sh := range []string{"fish", "bash", "zsh"} {
		st.Shells = append(st.Shells, shellState(sh, cfg, env))
	}
	return st
}

func shellState(shell string, cfg GreetingConfig, env Env) ShellGreeting {
	out := ShellGreeting{Shell: shell, State: ShellOff}
	if f := foreignFetch(shell, env); f != "" {
		out.State, out.File = ShellForeign, f
		return out
	}
	if shell == "fish" {
		out.File = FishGreetingFile(env)
		exists, ours := hookOwned(out.File)
		switch {
		case exists && !ours:
			out.State = ShellForeign
		case exists:
			out.State = ShellOn
		case !shellInstalled("fish", env):
			out.State = ShellAbsent
		}
		return out
	}
	rc, _ := rcFiles(shell, env)
	out.File = rc
	data, err := os.ReadFile(rc)
	switch {
	case err == nil && strings.Contains(string(data), "# >>> "+rcMarker(env)+" >>>"):
		out.State = ShellOn
	case !shellInstalled(shell, env) || (err != nil && filepath.Base(cfg.LoginShell) != shell):
		out.State = ShellAbsent
	case cfg.On && apphooks.WriteCheck(rc) != nil:
		out.State = ShellManaged
	}
	return out
}
