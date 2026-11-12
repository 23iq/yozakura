package termlook

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

// greetEnv is a home with bash, zsh, fish and fastfetch "installed".
func greetEnv(t *testing.T, installed ...string) Env {
	t.Helper()
	env := testEnv(t)
	env.DataHome = filepath.Join(env.Home, ".local", "share")
	if installed == nil {
		installed = []string{"bash", "zsh", "fish", "fastfetch"}
	}
	env.LookPath = func(bin string) (string, bool) {
		for _, b := range installed {
			if b == bin {
				return "/usr/bin/" + bin, true
			}
		}
		return "", false
	}
	return env
}

func readFile(t *testing.T, p string) string {
	t.Helper()
	data, err := os.ReadFile(p)
	if err != nil {
		t.Fatal(err)
	}
	return string(data)
}

func writeFile(t *testing.T, p, s string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(p, []byte(s), 0o644); err != nil {
		t.Fatal(err)
	}
}

func applyGreeting(t *testing.T, cfg GreetingConfig, env Env) GreetingStatus {
	t.Helper()
	st, err := ApplyGreeting(cfg, testPalette(t), loadFetch(t), SakuraLogoFile(fetchAssets), env)
	if err != nil {
		t.Fatal(err)
	}
	return st
}

func stateOf(st GreetingStatus, shell string) ShellGreeting {
	for _, s := range st.Shells {
		if s.Shell == shell {
			return s
		}
	}
	return ShellGreeting{}
}

func TestGreetingOnWritesOwnedFilesAndOneRCLine(t *testing.T) {
	env := greetEnv(t)
	bashrc := filepath.Join(env.Home, ".bashrc")
	before := "# my bashrc\nalias ll='ls -l'\n"
	writeFile(t, bashrc, before)
	cfg := GreetingConfig{On: true, Preset: "sakura", Logo: LogoSakura, LoginShell: "/bin/bash"}
	st := applyGreeting(t, cfg, env)
	if stateOf(st, "bash").State != ShellOn || stateOf(st, "fish").State != ShellOn {
		t.Fatalf("status %+v", st)
	}
	// zsh: installed but no .zshrc and not the login shell: left alone
	if s := stateOf(st, "zsh"); s.State != ShellAbsent {
		t.Errorf("zsh %+v", s)
	}
	if _, err := os.Stat(filepath.Join(env.Home, ".zshrc")); err == nil {
		t.Error(".zshrc created for a shell that is not the login shell")
	}
	rc := readFile(t, bashrc)
	if !strings.HasPrefix(rc, before) || strings.Count(rc, GreetingScriptFile(env)) != 2 {
		t.Errorf(".bashrc:\n%s", rc)
	}
	// the config is the sakura look with our logo file
	var conf map[string]any
	if err := json.Unmarshal([]byte(readFile(t, FetchConfigFile(env))), &conf); err != nil {
		t.Fatal(err)
	}
	if conf["logo"].(map[string]any)["source"] != fetchLogoFile(env) {
		t.Errorf("logo %v", conf["logo"])
	}
	if readFile(t, fetchLogoFile(env)) != readFile(t, SakuraLogoFile(fetchAssets)) {
		t.Error("logo file differs from the bundled one")
	}
	script := readFile(t, GreetingScriptFile(env))
	if !strings.Contains(script, "fastfetch --config \"$c\"") || !strings.Contains(script, FetchConfigFile(env)) {
		t.Errorf("script:\n%s", script)
	}
	// idempotent: a second apply changes nothing
	applyGreeting(t, cfg, env)
	if readFile(t, bashrc) != rc {
		t.Error("second apply changed .bashrc")
	}
	// off: everything goes, .bashrc byte for byte as before
	if _, err := ApplyGreeting(GreetingConfig{}, nil, nil, "", env); err != nil {
		t.Fatal(err)
	}
	if got := readFile(t, bashrc); got != before {
		t.Errorf(".bashrc after off:\n%q", got)
	}
	for _, f := range []string{GreetingScriptFile(env), FetchConfigFile(env), fetchLogoFile(env), FishGreetingFile(env)} {
		if _, err := os.Stat(f); err == nil {
			t.Errorf("%s left behind", f)
		}
	}
}

func TestGreetingCreatesTheLoginShellsRCAndRemovesItAgain(t *testing.T) {
	env := greetEnv(t)
	env.ZDotDir = filepath.Join(env.Home, "zdot")
	cfg := GreetingConfig{On: true, Preset: "compact", Logo: LogoDistro, LoginShell: "/usr/bin/zsh"}
	st := applyGreeting(t, cfg, env)
	zshrc := filepath.Join(env.ZDotDir, ".zshrc")
	if s := stateOf(st, "zsh"); s.State != ShellOn || s.File != zshrc {
		t.Fatalf("zsh %+v", s)
	}
	if err := RemoveGreeting(env); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(zshrc); err == nil {
		t.Error("the .zshrc the greeting created was left behind")
	}
}

func TestGreetingLeavesShellsThatRunAFetchToolAlone(t *testing.T) {
	env := greetEnv(t)
	bashrc := filepath.Join(env.Home, ".bashrc")
	writeFile(t, bashrc, "if command -v fastfetch >/dev/null; then fastfetch; fi\n")
	writeFile(t, filepath.Join(env.ConfigHome, "fish", "config.fish"), "if status is-interactive\n    neofetch\nend\n")
	writeFile(t, filepath.Join(env.Home, ".zshrc"), "# fastfetch\nalias ff=fastfetch\ncommand -v fastfetch\n")
	st := applyGreeting(t, GreetingConfig{On: true, Preset: "sakura", Logo: LogoSakura}, env)
	if s := stateOf(st, "bash"); s.State != ShellForeign || s.File != bashrc {
		t.Errorf("bash %+v", s)
	}
	if s := stateOf(st, "fish"); s.State != ShellForeign {
		t.Errorf("fish %+v", s)
	}
	if _, err := os.Stat(FishGreetingFile(env)); err == nil {
		t.Error("fish greeting written next to the user's fetch call")
	}
	if strings.Contains(readFile(t, bashrc), "greeting.sh") {
		t.Error(".bashrc got our line next to the user's fastfetch")
	}
	// comments, aliases and `command -v` are not a fetch run
	if s := stateOf(st, "zsh"); s.State != ShellOn {
		t.Errorf("zsh %+v", s)
	}
}

func TestRunsFetch(t *testing.T) {
	for line, want := range map[string]bool{
		"fastfetch":                         true,
		"  fastfetch --logo none":           true,
		"[[ $- == *i* ]] && fastfetch":      true,
		"if true; then fastfetch; fi":       true,
		"status is-interactive; and pfetch": true,
		"exec neofetch":                     true,
		"# fastfetch":                       false,
		"alias ff='fastfetch'":              false,
		"command -v fastfetch >/dev/null":   false,
		"echo fastfetchy":                   false,
		"/opt/fastfetch/bin/foo":            false,
	} {
		if got := runsFetch(line); got != want {
			t.Errorf("runsFetch(%q) = %v", line, got)
		}
	}
}

func TestGreetingCustomLogos(t *testing.T) {
	env := greetEnv(t)
	art := filepath.Join(env.Home, "art.txt")
	writeFile(t, art, "$1<>\n")
	pic := filepath.Join(env.Home, "me.png")
	writePNG(t, pic, 32, 32)
	logoOf := func(file string) map[string]any {
		var conf map[string]any
		if err := json.Unmarshal([]byte(readFile(t, file)), &conf); err != nil {
			t.Fatal(err)
		}
		return conf["logo"].(map[string]any)
	}
	applyGreeting(t, GreetingConfig{On: true, Preset: "sakura", Logo: LogoCustom, LogoPath: art}, env)
	if l := logoOf(FetchConfigFile(env)); l["type"] != "file" || l["source"] != fetchLogoFile(env) || readFile(t, fetchLogoFile(env)) != "$1<>\n" {
		t.Errorf("text logo %v", l)
	}
	st := applyGreeting(t, GreetingConfig{On: true, Preset: "sakura", Logo: LogoCustom, LogoPath: pic}, env)
	if !st.ImageLogo {
		t.Error("status misses the picture")
	}
	if l := logoOf(FetchConfigFile(env)); l["source"] != fetchLogoFile(env) {
		t.Errorf("picture: the text config must use the sakura logo, got %v", l)
	}
	if l := logoOf(fetchKittyFile(env)); l["type"] != "kitty-direct" || l["source"] != pic {
		t.Errorf("kitty config %v", l)
	}
	script := readFile(t, GreetingScriptFile(env))
	if !strings.Contains(script, "KITTY_WINDOW_ID") || !strings.Contains(script, "SSH_TTY") {
		t.Errorf("script misses the kitty guard:\n%s", script)
	}
	// a broken path: the sakura logo, the error in the status, no kitty config
	st = applyGreeting(t, GreetingConfig{On: true, Preset: "sakura", Logo: LogoCustom, LogoPath: "relative.png"}, env)
	if st.LogoError != "logo_path" {
		t.Errorf("logo error %q", st.LogoError)
	}
	if _, err := os.Stat(fetchKittyFile(env)); err == nil {
		t.Error("kitty config left after the picture went")
	}
	if strings.Contains(readFile(t, GreetingScriptFile(env)), "KITTY_WINDOW_ID") {
		t.Error("kitty branch left in the script")
	}
}

func TestGreetingOwnPresetRunsPlainFastfetch(t *testing.T) {
	env := greetEnv(t)
	userCfg := filepath.Join(env.ConfigHome, "fastfetch", "config.jsonc")
	writeFile(t, userCfg, `{"modules":["os"]}`)
	applyGreeting(t, GreetingConfig{On: true, Preset: "sakura", Logo: LogoSakura}, env)
	st := applyGreeting(t, GreetingConfig{On: true, Preset: FetchOwn, Logo: LogoSakura}, env)
	if !st.OwnConfig {
		t.Error("own config not reported")
	}
	script := readFile(t, GreetingScriptFile(env))
	if !strings.Contains(script, "    fastfetch\n") || strings.Contains(script, "--config") {
		t.Errorf("own script:\n%s", script)
	}
	if !strings.Contains(readFile(t, FishGreetingFile(env)), "        fastfetch\n") {
		t.Error("fish file does not run plain fastfetch")
	}
	if _, err := os.Stat(FetchConfigFile(env)); err == nil {
		t.Error("generated config left for the own look")
	}
	if readFile(t, userCfg) != `{"modules":["os"]}` {
		t.Error("the user's fastfetch config changed")
	}
}

func TestGreetingScriptsQuoteAnyPath(t *testing.T) {
	odd := `/h/it's "q" $(rm -rf ~) ` + "`x`" + `;\ &/fastfetch.jsonc`
	sh, err := greetingScript(fetchCmd{cfg: odd, kitty: odd + "k"})
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(sh, `'/h/it'\''s "q" $(rm -rf ~) `+"`x`"+`;\ &/fastfetch.jsonc'`) {
		t.Errorf("not quoted:\n%s", sh)
	}
	fish, err := fishGreeting(fetchCmd{cfg: odd})
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(fish, fishQuote(odd)) {
		t.Errorf("fish not quoted:\n%s", fish)
	}
	for _, bad := range []string{"/a\nb", "/a\x00b", "/a\rb"} {
		if _, err := greetingScript(fetchCmd{cfg: bad}); err == nil {
			t.Errorf("%q accepted", bad)
		}
		if _, err := fishGreeting(fetchCmd{cfg: bad}); err == nil {
			t.Errorf("fish %q accepted", bad)
		}
	}
	if line := rcLine(odd); !strings.HasPrefix(line, "if [ -r '/h/it'\\''s") {
		t.Errorf("rc line %s", line)
	}
	if bash, err := exec.LookPath("bash"); err == nil {
		f := filepath.Join(t.TempDir(), "g.sh")
		writeFile(t, f, sh+rcLine(odd)+"\n")
		if out, err := exec.Command(bash, "-n", f).CombinedOutput(); err != nil {
			t.Errorf("bash -n: %v: %s", err, out)
		}
	}
	for _, shell := range []string{"zsh", "fish"} {
		bin, err := exec.LookPath(shell)
		if err != nil {
			continue
		}
		text := sh
		if shell == "fish" {
			text = fish
		}
		f := filepath.Join(t.TempDir(), "g."+shell)
		writeFile(t, f, text)
		if out, err := exec.Command(bin, "-n", f).CombinedOutput(); err != nil {
			t.Errorf("%s -n: %v: %s", shell, err, out)
		}
	}
}

// Sourced by a non-interactive bash (scp, rsync, `ssh host cmd`, scripts),
// the script prints nothing, runs nothing and leaves status 0.
func TestGreetingScriptQuietOutsideInteractiveTerminals(t *testing.T) {
	bash, err := exec.LookPath("bash")
	if err != nil {
		t.Skip("bash not installed")
	}
	dir := t.TempDir()
	bin := filepath.Join(dir, "bin")
	mark := filepath.Join(dir, "ran")
	writeFile(t, filepath.Join(bin, "fastfetch"), "#!/bin/sh\necho FETCH\ntouch "+mark+"\n")
	if err := os.Chmod(filepath.Join(bin, "fastfetch"), 0o755); err != nil {
		t.Fatal(err)
	}
	cfg := filepath.Join(dir, "f.jsonc")
	writeFile(t, cfg, "{}")
	sh, _ := greetingScript(fetchCmd{cfg: cfg})
	script := filepath.Join(dir, "greeting.sh")
	writeFile(t, script, sh)
	for _, args := range [][]string{
		{"-c", ". " + script + "; echo status=$?"},
		{"-ic", ". " + script + "; echo status=$?"}, // interactive, but stdout is a pipe (IDE probes)
	} {
		cmd := exec.Command(bash, append([]string{"--norc", "--noprofile"}, args...)...)
		cmd.Env = []string{"PATH=" + bin + ":/usr/bin:/bin", "HOME=" + dir, "TERM=xterm-256color"}
		out, _ := cmd.Output()
		if strings.TrimSpace(string(out)) != "status=0" {
			t.Errorf("%v: output %q", args, out)
		}
	}
	if _, err := os.Stat(mark); err == nil {
		t.Error("fastfetch ran outside an interactive terminal")
	}
}

// The greeting and the prompt hook are separate files: switching the
// prompt never touches the greeting and the other way round.
func TestGreetingAndPromptHookAreIndependent(t *testing.T) {
	env := greetEnv(t)
	presets, err := LoadPresets("../../../assets/terminal/prompts")
	if err != nil {
		t.Fatal(err)
	}
	pal := testPalette(t)
	prompt := Config{Enabled: true, Engine: EngineStarship, Prompt: "plain", Greeting: "fastfetch"}
	if err := Apply(prompt, pal, presets, env); err != nil {
		t.Fatal(err)
	}
	hook := readFile(t, HookFile(env))
	if strings.Contains(hook, "fastfetch") {
		t.Errorf("prompt hook runs fastfetch:\n%s", hook)
	}
	applyGreeting(t, GreetingConfig{On: true, Preset: "sakura", Logo: LogoSakura}, env)
	greeting := readFile(t, FishGreetingFile(env))
	if err := Apply(Config{}, nil, nil, env); err != nil { // prompt off
		t.Fatal(err)
	}
	if readFile(t, FishGreetingFile(env)) != greeting {
		t.Error("turning the prompt off changed the greeting")
	}
	if err := Apply(prompt, pal, presets, env); err != nil {
		t.Fatal(err)
	}
	if err := RemoveGreeting(env); err != nil {
		t.Fatal(err)
	}
	if readFile(t, HookFile(env)) != hook {
		t.Error("turning the greeting off changed the prompt hook")
	}
	// the user's own fish file of the same name is never replaced
	writeFile(t, FishGreetingFile(env), "function fish_greeting\nend\n")
	st := applyGreeting(t, GreetingConfig{On: true, Preset: "sakura", Logo: LogoSakura}, env)
	if readFile(t, FishGreetingFile(env)) != "function fish_greeting\nend\n" || stateOf(st, "fish").State != ShellForeign {
		t.Error("a foreign fish file was replaced")
	}
	if err := RemoveGreeting(env); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(FishGreetingFile(env)); err != nil {
		t.Error("a foreign fish file was removed")
	}
}

func TestGreetingStateWhenOff(t *testing.T) {
	env := greetEnv(t, "bash")
	writeFile(t, filepath.Join(env.Home, ".bashrc"), "\n")
	st := GreetingState(GreetingConfig{LoginShell: "/bin/bash"}, env)
	if st.On || st.FastfetchInstalled {
		t.Errorf("%+v", st)
	}
	if s := stateOf(st, "bash"); s.State != ShellOff {
		t.Errorf("bash %+v", s)
	}
	if s := stateOf(st, "fish"); s.State != ShellAbsent {
		t.Errorf("fish %+v", s)
	}
}

// The user deleted our end marker and wrote below the start marker: the
// next apply and "off" leave the file alone and the status says so.
func TestGreetingLeavesEditedMarkersAlone(t *testing.T) {
	env := greetEnv(t)
	rc := filepath.Join(env.Home, ".bashrc")
	writeFile(t, rc, "a\n")
	cfg := GreetingConfig{On: true, Preset: "sakura", Logo: LogoSakura, LoginShell: "/bin/bash"}
	applyGreeting(t, cfg, env)
	edited := "a\n\n# >>> " + rcMarker(env) + " >>>\nmy important line\n"
	writeFile(t, rc, edited)
	st := applyGreeting(t, cfg, env)
	if s := stateOf(st, "bash"); s.State != ShellBroken {
		t.Errorf("bash %+v", s)
	}
	cfg.On = false
	st = applyGreeting(t, cfg, env)
	if readFile(t, rc) != edited {
		t.Errorf("file changed: %q", readFile(t, rc))
	}
	if s := stateOf(st, "bash"); s.State != ShellBroken {
		t.Errorf("bash after off %+v", s)
	}
	if err := RemoveGreeting(env); err == nil {
		t.Error("uninstall does not report the file it left")
	}
	if readFile(t, rc) != edited {
		t.Errorf("uninstall changed it: %q", readFile(t, rc))
	}
}

// An rc file the greeting created goes on off even after its line changed
// (another config dir).
func TestGreetingRemovesItsRCAfterTheLineChanged(t *testing.T) {
	env := greetEnv(t)
	rc := filepath.Join(env.Home, ".bashrc")
	cfg := GreetingConfig{On: true, Preset: "sakura", Logo: LogoSakura, LoginShell: "/bin/bash"}
	applyGreeting(t, cfg, env)
	env.ConfigHome = filepath.Join(env.Home, "cfg2")
	applyGreeting(t, cfg, env)
	cfg.On = false
	applyGreeting(t, cfg, env)
	if _, err := os.Stat(rc); err == nil {
		t.Errorf("created rc left: %q", readFile(t, rc))
	}
}

// fish missing: no fish file, the status says absent; directories the
// greeting created for fish go again once empty, the user's stay.
func TestGreetingFishOnlyWhereFishIs(t *testing.T) {
	env := greetEnv(t, "bash", "fastfetch")
	writeFile(t, filepath.Join(env.Home, ".bashrc"), "x\n")
	cfg := GreetingConfig{On: true, Preset: "sakura", Logo: LogoSakura, LoginShell: "/bin/bash"}
	st := applyGreeting(t, cfg, env)
	if _, err := os.Stat(FishGreetingFile(env)); err == nil {
		t.Error("fish file written although fish is not installed")
	}
	if s := stateOf(st, "fish"); s.State != ShellAbsent {
		t.Errorf("fish %+v", s)
	}
	fishDir := filepath.Join(env.ConfigHome, "fish")
	if _, err := os.Stat(fishDir); err == nil {
		t.Error("fish dir created")
	}

	env = greetEnv(t)
	fishDir = filepath.Join(env.ConfigHome, "fish")
	applyGreeting(t, cfg, env)
	if _, err := os.Stat(FishGreetingFile(env)); err != nil {
		t.Fatal(err)
	}
	cfg.On = false
	applyGreeting(t, cfg, env)
	if _, err := os.Stat(fishDir); err == nil {
		t.Error("~/.config/fish we created left after off")
	}
	// the user's own fish dir (with a file of theirs) stays
	writeFile(t, filepath.Join(fishDir, "config.fish"), "# mine\n")
	cfg.On = true
	applyGreeting(t, cfg, env)
	if err := RemoveGreeting(env); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(fishDir, "config.fish")); err != nil {
		t.Error("the user's fish dir went")
	}
	if _, err := os.Stat(filepath.Join(fishDir, "conf.d")); err == nil {
		t.Error("conf.d we created left after uninstall")
	}
	// fish uninstalled later: our file goes on the next apply
	applyGreeting(t, cfg, env)
	env.LookPath = greetEnv(t, "bash", "zsh", "fastfetch").LookPath
	applyGreeting(t, cfg, env)
	if _, err := os.Stat(FishGreetingFile(env)); err == nil {
		t.Error("fish file left after fish went")
	}
}
