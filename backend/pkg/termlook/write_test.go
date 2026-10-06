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
			"if status is-interactive\n    if type -q starship\n        set -gx STARSHIP_CONFIG '/c/s.toml'\n        starship init fish | source\n    end\nend\nset -g fish_greeting\n"},
		{"starship fastfetch", Config{Engine: EngineStarship, Greeting: "fastfetch"},
			"if status is-interactive\n    if type -q starship\n        set -gx STARSHIP_CONFIG '/c/s.toml'\n        starship init fish | source\n    end\nend\nfunction fish_greeting\n    fastfetch\nend\n"},
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
