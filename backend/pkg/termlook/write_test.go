package termlook

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestFishHookGolden(t *testing.T) {
	cases := []struct {
		name string
		cfg  Config
		want string
	}{
		{"starship none", Config{Engine: EngineStarship, Greeting: "none"},
			"if status is-interactive\n    if type -q starship\n        starship init fish | source\n        if functions -q fish_prompt\n            functions -e __yozakura_starship_prompt\n            functions -c fish_prompt __yozakura_starship_prompt\n            function fish_prompt\n                STARSHIP_CONFIG='/c/s.toml' __yozakura_starship_prompt\n            end\n        end\n        if functions -q fish_right_prompt\n            functions -e __yozakura_starship_right_prompt\n            functions -c fish_right_prompt __yozakura_starship_right_prompt\n            function fish_right_prompt\n                STARSHIP_CONFIG='/c/s.toml' __yozakura_starship_right_prompt\n            end\n        end\n    end\nend\nset -g fish_greeting\n"},
		{"starship fastfetch", Config{Engine: EngineStarship, Greeting: "fastfetch"},
			"if status is-interactive\n    if type -q starship\n        starship init fish | source\n        if functions -q fish_prompt\n            functions -e __yozakura_starship_prompt\n            functions -c fish_prompt __yozakura_starship_prompt\n            function fish_prompt\n                STARSHIP_CONFIG='/c/s.toml' __yozakura_starship_prompt\n            end\n        end\n        if functions -q fish_right_prompt\n            functions -e __yozakura_starship_right_prompt\n            functions -c fish_right_prompt __yozakura_starship_right_prompt\n            function fish_right_prompt\n                STARSHIP_CONFIG='/c/s.toml' __yozakura_starship_right_prompt\n            end\n        end\n    end\nend\nfunction fish_greeting\n    fastfetch\nend\n"},
		{"omp none", Config{Engine: EngineOMP, Greeting: "none"},
			"if status is-interactive\n    if type -q oh-my-posh\n        oh-my-posh init fish --config '/c/s.toml' | source\n    end\nend\nset -g fish_greeting\n"},
		{"omp fastfetch", Config{Engine: EngineOMP, Greeting: "fastfetch"},
			"if status is-interactive\n    if type -q oh-my-posh\n        oh-my-posh init fish --config '/c/s.toml' | source\n    end\nend\nfunction fish_greeting\n    fastfetch\nend\n"},
	}
	for _, c := range cases {
		got := FishHook(c.cfg, "/c/s.toml")
		got = got[strings.Index(got, "if status"):]
		if got != c.want {
			t.Errorf("%s:\n got %q\nwant %q", c.name, got, c.want)
		}
	}
}

func TestFishQuote(t *testing.T) {
	if got := fishQuote(`/h/it's\x`); got != `'/h/it\'s\\x'` {
		t.Errorf("fishQuote = %s", got)
	}
	hook := FishHook(Config{Engine: EngineStarship}, `/tmp/o'brien/$(rm -rf ~)/s.toml`)
	if !strings.Contains(hook, `'/tmp/o\'brien/$(rm -rf ~)/s.toml'`) {
		t.Errorf("hook not quoted: %s", hook)
	}
	if fish, err := exec.LookPath("fish"); err == nil {
		f := filepath.Join(t.TempDir(), "x.fish")
		if err := os.WriteFile(f, []byte(hook), 0o644); err != nil {
			t.Fatal(err)
		}
		if out, err := exec.Command(fish, "-n", f).CombinedOutput(); err != nil {
			t.Errorf("fish -n: %v: %s", err, out)
		}
	}
}

func testEnv(t *testing.T) Env {
	t.Helper()
	home := t.TempDir()
	return Env{Home: home, ConfigHome: filepath.Join(home, ".config"), AppID: "yozakura"}
}

func TestApplyWritesAndRemovesHook(t *testing.T) {
	env := testEnv(t)
	pal := fixturePalette(t)
	ps := loadAll(t)
	cfg := Config{Enabled: true, Engine: EngineStarship, Prompt: "sakura-powerline", Greeting: "none"}
	if err := Apply(cfg, pal, ps, env); err != nil {
		t.Fatal(err)
	}
	conf := filepath.Join(env.ConfigHome, "yozakura", "starship.toml")
	got, err := os.ReadFile(conf)
	if err != nil || !strings.Contains(string(got), "[palettes.yozakura]") {
		t.Fatalf("starship.toml: %v %q", err, got)
	}
	hook, err := os.ReadFile(filepath.Join(env.ConfigHome, "fish", "conf.d", "yozakura.fish"))
	if err != nil || !strings.Contains(string(hook), "'"+conf+"'") {
		t.Fatalf("hook: %v %q", err, hook)
	}
	if fish, err := exec.LookPath("fish"); err == nil {
		if out, err := exec.Command(fish, "-n", HookFile(env)).CombinedOutput(); err != nil {
			t.Errorf("fish -n: %v: %s", err, out)
		}
	}
	cfg.Engine = EngineOMP
	if err := Apply(cfg, pal, ps, env); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(env.ConfigHome, "yozakura", "prompt.omp.json")); err != nil {
		t.Error(err)
	}
	cfg.Enabled = false
	if err := Apply(cfg, pal, ps, env); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(HookFile(env)); !os.IsNotExist(err) {
		t.Errorf("hook should be removed, stat err = %v", err)
	}
	if err := Apply(cfg, pal, ps, env); err != nil {
		t.Errorf("removing an absent hook must not fail: %v", err)
	}
}

func TestApplyRejectsBadInput(t *testing.T) {
	env := testEnv(t)
	pal := fixturePalette(t)
	ps := loadAll(t)
	for _, cfg := range []Config{
		{Enabled: true, Engine: "bash", Prompt: "zen"},
		{Enabled: true, Engine: EngineStarship, Prompt: "nope"},
		{Enabled: true, Engine: EngineStarship, Prompt: "zen", Greeting: "rm"},
	} {
		if err := Apply(cfg, pal, ps, env); err == nil {
			t.Errorf("Apply(%+v) should fail", cfg)
		}
	}
	if _, err := os.Stat(HookFile(env)); !os.IsNotExist(err) {
		t.Error("hook must not exist after failed Apply")
	}
}

func TestFishHookRejectsControlChars(t *testing.T) {
	if FishHook(Config{Engine: EngineStarship}, "/a\nb") != "" {
		t.Error("newline path must yield no hook")
	}
}

func TestFishHookSilentWithoutEngine(t *testing.T) {
	fish, err := exec.LookPath("fish")
	if err != nil {
		t.Skip("fish not installed")
	}
	dir := t.TempDir()
	for _, eng := range []string{EngineStarship, EngineOMP} {
		f := filepath.Join(dir, eng+".fish")
		if err := os.WriteFile(f, []byte(FishHook(Config{Engine: eng, Greeting: "none"}, "/c/x.toml")), 0o644); err != nil {
			t.Fatal(err)
		}
		cmd := exec.Command(fish, "--no-config", "-i", "-c", "source "+f)
		cmd.Env = []string{"PATH=" + t.TempDir(), "HOME=" + dir}
		cmd.Path = fish
		var out, errb strings.Builder
		cmd.Stdout, cmd.Stderr = &out, &errb
		if err := cmd.Run(); err != nil {
			t.Fatalf("%s: %v: %s", eng, err, errb.String())
		}
		if out.String() != "" || errb.String() != "" {
			t.Errorf("%s: output %q stderr %q", eng, out.String(), errb.String())
		}
	}
}

// The prompt sees our starship config, the session does not: no exported
// STARSHIP_CONFIG, and the last command's status reaches starship.
func TestFishHookStarshipConfigOnlyForThePrompt(t *testing.T) {
	fish, err := exec.LookPath("fish")
	if err != nil {
		t.Skip("fish not installed")
	}
	dir := t.TempDir()
	bin := filepath.Join(dir, "bin")
	if err := os.MkdirAll(bin, 0o755); err != nil {
		t.Fatal(err)
	}
	// a fake starship: init defines fish_prompt the way starship does
	// (reading $status first), prompt prints what it got
	fake := "#!/bin/sh\ncase \"$1\" in\ninit) printf '%s\\n' 'function fish_prompt' '    set -l s $status' '    starship prompt --status=$s' 'end' ;;\nprompt) echo \"cfg=$STARSHIP_CONFIG $2\" ;;\nesac\n"
	if err := os.WriteFile(filepath.Join(bin, "starship"), []byte(fake), 0o755); err != nil {
		t.Fatal(err)
	}
	hook := filepath.Join(dir, "hook.fish")
	if err := os.WriteFile(hook, []byte(FishHook(Config{Engine: EngineStarship, Greeting: "none"}, "/c/s.toml")), 0o644); err != nil {
		t.Fatal(err)
	}
	cmd := exec.Command(fish, "--no-config", "-i", "-c", "source "+hook+"; false; fish_prompt; echo \"global=[$STARSHIP_CONFIG]\"; sh -c 'echo child=[$STARSHIP_CONFIG]'")
	cmd.Env = []string{"PATH=" + bin + ":/usr/bin:/bin", "HOME=" + dir}
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("%v: %s", err, out)
	}
	for _, want := range []string{"cfg=/c/s.toml --status=1", "global=[]", "child=[]"} {
		if !strings.Contains(string(out), want) {
			t.Errorf("missing %q in:\n%s", want, out)
		}
	}
}

// A conf.d file of that name the user wrote (no "Managed by" header) is
// neither overwritten nor removed.
func TestApplyLeavesForeignHookFile(t *testing.T) {
	env := testEnv(t)
	pal := fixturePalette(t)
	ps := loadAll(t)
	mine := "# my own setup\nset -g foo bar\n"
	if err := os.MkdirAll(filepath.Dir(HookFile(env)), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(HookFile(env), []byte(mine), 0o644); err != nil {
		t.Fatal(err)
	}
	cfg := Config{Enabled: true, Engine: EngineStarship, Prompt: "sakura-powerline", Greeting: "none"}
	if err := Apply(cfg, pal, ps, env); err == nil {
		t.Fatal("writing over the user's file must fail")
	}
	cfg.Enabled = false
	if err := Apply(cfg, pal, ps, env); err != nil {
		t.Fatal(err)
	}
	if got, _ := os.ReadFile(HookFile(env)); string(got) != mine {
		t.Fatalf("the user's file changed: %q", got)
	}
}
