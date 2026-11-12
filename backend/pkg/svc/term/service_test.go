package term

import (
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/termlook"
)

type fixture struct {
	t                 *testing.T
	home, cfg, colors string
	s                 *Service
	installed         map[string]bool
}

func newFixture(t *testing.T, terminalJSON string) *fixture {
	t.Helper()
	home := t.TempDir()
	f := &fixture{t: t, home: home, installed: map[string]bool{}}
	f.cfg = filepath.Join(home, "appcfg", "config", "terminal.json")
	f.colors = filepath.Join(home, "cache", "colors.json")
	for _, p := range []string{f.cfg, f.colors} {
		if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	data, err := os.ReadFile("../../termlook/testdata/colors.json")
	if err != nil {
		t.Fatal(err)
	}
	f.write(f.colors, string(data))
	if terminalJSON != "" {
		f.write(f.cfg, terminalJSON)
	}
	f.s = New(Options{
		ConfigFile: f.cfg, ColorsFile: f.colors, PresetsDir: "../../../../assets/terminal/prompts",
		Env: termlook.Env{Home: home, ConfigHome: filepath.Join(home, ".config"), CacheHome: filepath.Join(home, ".cache"),
			AppID: brand.AppID, LookPath: func(b string) (string, bool) { return "/usr/bin/" + b, f.installed[b] }},
		Passwd: func() ([]byte, error) {
			return []byte("root:x:0:0::/root:/bin/bash\nalice:x:1000:1000::/home/alice:/usr/bin/fish\n"), nil
		},
		User:     func() string { return "alice" },
		Debounce: 20 * time.Millisecond,
	})
	return f
}

func (f *fixture) write(path, content string) {
	f.t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		f.t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		f.t.Fatal(err)
	}
}

func (f *fixture) hook() string { return termlook.HookFile(f.s.o.Env) }

func TestPresetsListsAll(t *testing.T) {
	f := newFixture(t, "")
	out, err := f.s.presets(nil)
	if err != nil {
		t.Fatal(err)
	}
	list := out.([]presetInfo)
	if len(list) != 14 {
		t.Fatalf("presets = %d", len(list))
	}
	b, _ := json.Marshal(list[0])
	for _, k := range []string{`"id"`, `"name"`, `"description"`, `"nerdFont"`, `"lines"`} {
		if !strings.Contains(string(b), k) {
			t.Errorf("missing %s in %s", k, b)
		}
	}
}

func TestApplyWritesFilesWhenEnabled(t *testing.T) {
	f := newFixture(t, `{"enabled": true, "engine": "starship", "prompt": "pure", "greeting": "none"}`)
	st, err := f.s.apply(nil)
	if err != nil {
		t.Fatal(err)
	}
	conf := filepath.Join(f.home, ".config", brand.AppID, "starship.toml")
	if b, err := os.ReadFile(conf); err != nil || !strings.Contains(string(b), "palette = ") {
		t.Fatalf("starship.toml: %v %q", err, b)
	}
	hook, err := os.ReadFile(f.hook())
	if err != nil || !strings.Contains(string(hook), "starship init fish") {
		t.Fatalf("hook: %v %q", err, hook)
	}
	if !st.(Status).HookPresent {
		t.Error("status.hookPresent false after apply")
	}
	if _, err := os.Stat(filepath.Join(f.home, ".config", "fish", "config.fish")); err == nil {
		t.Error("config.fish must never be created")
	}
}

func TestApplyDisabledRemovesHookOnly(t *testing.T) {
	f := newFixture(t, `{"enabled": false}`)
	f.write(f.hook(), "# Managed by "+brand.DisplayName+". Remove this file or turn the prompt off in Settings.\n")
	if _, err := f.s.apply(nil); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(f.hook()); !os.IsNotExist(err) {
		t.Errorf("hook still there: %v", err)
	}
}

func TestApplyNeedsPalette(t *testing.T) {
	f := newFixture(t, `{"enabled": true}`)
	_ = os.Remove(f.colors)
	if _, err := f.s.apply(nil); err == nil {
		t.Fatal("apply without colors.json must fail")
	}
}

func TestDefaultsWhenNoConfig(t *testing.T) {
	f := newFixture(t, "")
	c := f.s.config()
	if c.Enabled || c.Engine != "starship" || c.Prompt != "sakura-powerline" || c.Greeting != "none" {
		t.Errorf("defaults = %+v", c)
	}
	if _, err := f.s.apply(nil); err != nil {
		t.Errorf("apply on defaults: %v", err)
	}
	if _, err := os.Stat(f.hook()); err == nil {
		t.Error("default config (disabled) must not write the hook")
	}
}

func TestStatusForeignInitAndShell(t *testing.T) {
	f := newFixture(t, "")
	f.installed["fish"], f.installed["oh-my-posh"] = true, true
	f.write(filepath.Join(f.home, ".config", "fish", "config.fish"),
		"# starship init fish | source\nset -x A 1\nif status is-interactive\n    starship init fish | source\nend\n")
	st := f.s.currentStatus()
	if !st.ForeignPromptInit || !strings.HasSuffix(st.ForeignFile, "config.fish") {
		t.Errorf("foreign = %v %q", st.ForeignPromptInit, st.ForeignFile)
	}
	if !st.FishInstalled || !st.FishIsLoginShell {
		t.Errorf("fish = %v login %v", st.FishInstalled, st.FishIsLoginShell)
	}
	if st.EngineInstalled["starship"] || !st.EngineInstalled["ohmyposh"] {
		t.Errorf("engines = %v", st.EngineInstalled)
	}
	if st.HookPath != f.hook() {
		t.Errorf("hookPath = %q", st.HookPath)
	}
}

func TestStatusIgnoresCommentsAndOwnHook(t *testing.T) {
	f := newFixture(t, `{"enabled": true}`)
	f.write(filepath.Join(f.home, ".config", "fish", "config.fish"), "# oh-my-posh init fish | source\n")
	if _, err := f.s.apply(nil); err != nil {
		t.Fatal(err)
	}
	if st := f.s.currentStatus(); st.ForeignPromptInit {
		t.Errorf("our own hook and comments are not foreign: %+v", st)
	}
}

func TestLoginShellOther(t *testing.T) {
	f := newFixture(t, "")
	f.s.o.User = func() string { return "root" }
	if st := f.s.currentStatus(); st.FishIsLoginShell || st.LoginShell != "/bin/bash" {
		t.Errorf("root uses bash: %+v", st)
	}
	f.s.o.User = func() string { return "alice" }
	if st := f.s.currentStatus(); !st.FishIsLoginShell || st.LoginShell != "/usr/bin/fish" {
		t.Errorf("alice uses fish: %+v", st)
	}
	f.s.o.User = func() string { return "nobody" }
	if st := f.s.currentStatus(); st.FishIsLoginShell || st.LoginShell != "" {
		t.Errorf("no passwd entry: %+v", st)
	}
}

func TestTerminalShellOnlyAfterAChsh(t *testing.T) {
	f := newFixture(t, "")
	f.s.o.Executable = func(p string) bool { return p != "/gone/zsh" }
	passwd := "alice:x:1000:1000::/home/alice:/usr/bin/fish\n"
	f.s.o.Passwd = func() ([]byte, error) { return []byte(passwd), nil }
	if st := f.s.currentStatus(); st.TerminalShell != "" {
		t.Errorf("unchanged since start: %+v", st)
	}
	passwd = "alice:x:1000:1000::/home/alice:/bin/zsh\n"
	if st := f.s.currentStatus(); st.TerminalShell != "/bin/zsh" {
		t.Errorf("chsh this session: %+v", st)
	}
	passwd = "alice:x:1000:1000::/home/alice:/gone/zsh\n"
	if st := f.s.currentStatus(); st.TerminalShell != "" {
		t.Errorf("missing shell: %+v", st)
	}
}

func TestLoginFilesBeyondTheSkeleton(t *testing.T) {
	f := newFixture(t, "")
	skel := t.TempDir()
	f.s.o.Skel = skel
	f.write(filepath.Join(skel, ".bash_profile"), "#\n# ~/.bash_profile\n#\n\n[[ -f ~/.bashrc ]] && . ~/.bashrc\n")
	if st := f.s.currentStatus(); st.LoginFiles != nil {
		t.Errorf("no login files: %v", st.LoginFiles)
	}
	// The skeleton copy (comments and spacing aside) and comment-only files.
	f.write(filepath.Join(f.home, ".bash_profile"), "# ~/.bash_profile\n\n  [[ -f ~/.bashrc ]] && . ~/.bashrc  \n")
	f.write(filepath.Join(f.home, ".profile"), "# nothing here\n\n")
	if st := f.s.currentStatus(); st.LoginFiles != nil {
		t.Errorf("skeleton content counted as the user's: %v", st.LoginFiles)
	}
	// A user line: starting the compositor from the console, an export.
	f.write(filepath.Join(f.home, ".bash_profile"), "[[ -f ~/.bashrc ]] && . ~/.bashrc\n[ \"$(tty)\" = /dev/tty1 ] && exec niri-session\n")
	f.write(filepath.Join(f.home, ".profile"), "export EDITOR=nvim\n")
	st := f.s.currentStatus()
	if !reflect.DeepEqual(st.LoginFiles, []string{"~/.bash_profile", "~/.profile"}) {
		t.Errorf("user content: %v", st.LoginFiles)
	}
}

func TestPreviewApproximateAndValidation(t *testing.T) {
	f := newFixture(t, "")
	out, err := f.s.preview(json.RawMessage(`{"engine":"starship","prompt":"zen","width":80}`))
	if err != nil {
		t.Fatal(err)
	}
	p := out.(previewJSON)
	if p.Exact || p.Reason != "engine_missing" || len(p.Left) == 0 {
		t.Errorf("preview = %+v", p)
	}
	for _, bad := range []string{`{"prompt":"../x"}`, `{"prompt":"nope"}`, `{"engine":"zsh"}`} {
		if _, err := f.s.preview(json.RawMessage(bad)); err == nil {
			t.Errorf("preview %s must fail", bad)
		}
	}
}

func TestWatcherReappliesOnColorChange(t *testing.T) {
	f := newFixture(t, `{"enabled": true, "prompt": "zen"}`)
	if err := f.s.Start(); err != nil {
		t.Fatal(err)
	}
	defer f.s.Stop()
	conf := filepath.Join(f.home, ".config", brand.AppID, "starship.toml")
	waitFor(t, func() bool { _, err := os.Stat(conf); return err == nil }, "initial apply")
	before, _ := os.ReadFile(conf)

	b, _ := os.ReadFile(f.colors)
	changed := strings.Replace(string(b), `"primary": "#`, `"primary": "#010203", "_x": "#`, 1)
	if changed == string(b) {
		t.Fatal("fixture colors.json has no primary key to change")
	}
	tmp := f.colors + ".tmp"
	f.write(tmp, changed)
	if err := os.Rename(tmp, f.colors); err != nil {
		t.Fatal(err)
	}
	waitFor(t, func() bool { a, _ := os.ReadFile(conf); return string(a) != string(before) }, "re-render after colors.json change")
}

func TestWatcherIdleWhenDisabled(t *testing.T) {
	f := newFixture(t, `{"enabled": false}`)
	if err := f.s.Start(); err != nil {
		t.Fatal(err)
	}
	defer f.s.Stop()
	f.write(f.colors, mustRead(t, f.colors)+" ")
	time.Sleep(150 * time.Millisecond)
	if _, err := os.Stat(f.hook()); err == nil {
		t.Error("disabled prompt must not write anything")
	}
	// enabling through terminal.json writes the files
	f.write(f.cfg, `{"enabled": true, "prompt": "zen"}`)
	waitFor(t, func() bool { _, err := os.Stat(f.hook()); return err == nil }, "apply after terminal.json enabled")
}

func mustRead(t *testing.T, p string) string {
	t.Helper()
	b, err := os.ReadFile(p)
	if err != nil {
		t.Fatal(err)
	}
	return string(b)
}

func waitFor(t *testing.T, cond func() bool, what string) {
	t.Helper()
	for i := 0; i < 100; i++ {
		if cond() {
			return
		}
		time.Sleep(20 * time.Millisecond)
	}
	t.Fatalf("timed out: %s", what)
}

func TestWatcherFollowsColorsFileInMissingDir(t *testing.T) {
	f := newFixture(t, `{"enabled": true, "prompt": "zen"}`)
	data := mustRead(t, f.colors)
	cacheDir := filepath.Dir(f.colors)
	if err := os.RemoveAll(cacheDir); err != nil {
		t.Fatal(err)
	}
	if err := f.s.Start(); err != nil {
		t.Fatal(err)
	}
	defer f.s.Stop()
	f.write(f.colors, data) // the directory appears after Start
	conf := filepath.Join(f.home, ".config", brand.AppID, "starship.toml")
	waitFor(t, func() bool { _, err := os.Stat(conf); return err == nil }, "apply once colors.json shows up")
}

// The user's config.fish starts starship itself: our hook is not
// installed (an existing one is removed) and the status says why.
func TestForeignInitSkipsHook(t *testing.T) {
	f := newFixture(t, `{"enabled": true}`)
	if _, err := f.s.apply(nil); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(f.hook()); err != nil {
		t.Fatal("hook not written without a foreign init")
	}
	f.write(filepath.Join(f.home, ".config", "fish", "config.fish"), "starship init fish | source\n")
	res, err := f.s.apply(nil)
	if err != nil {
		t.Fatal(err)
	}
	st := res.(Status)
	if !st.HookSkipped || st.HookPresent {
		t.Fatalf("status = %+v", st)
	}
	if _, err := os.Stat(f.hook()); !os.IsNotExist(err) {
		t.Fatal("our hook stays next to the user's own init")
	}
}
