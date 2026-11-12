package term

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"yozakura/backend/pkg/termlook"
)

const greetingOn = `{"greeting":"fastfetch","fastfetchPreset":"sakura","fastfetchLogo":"sakura"}`

func greetFixture(t *testing.T, terminalJSON string) *fixture {
	t.Helper()
	f := newFixture(t, terminalJSON)
	f.s.o.FetchDir = "../../../../assets/terminal/fastfetch"
	f.s.o.Env.DataHome = filepath.Join(f.home, ".local", "share")
	f.installed["bash"] = true
	f.write(filepath.Join(f.home, ".bashrc"), "# mine\n")
	return f
}

// The greeting is written without the prompt; the prompt hook stays away.
func TestApplyWritesTheGreetingWithoutThePrompt(t *testing.T) {
	f := greetFixture(t, greetingOn)
	if err := f.s.Apply(); err != nil {
		t.Fatal(err)
	}
	env := f.s.o.Env
	for _, p := range []string{termlook.FetchConfigFile(env), termlook.GreetingScriptFile(env), termlook.FishGreetingFile(env)} {
		if _, err := os.Stat(p); err != nil {
			t.Errorf("%s: %v", p, err)
		}
	}
	if _, err := os.Stat(f.hook()); err == nil {
		t.Error("prompt hook written while the prompt is off")
	}
	rc, _ := os.ReadFile(filepath.Join(f.home, ".bashrc"))
	if !strings.Contains(string(rc), "greeting.sh") {
		t.Errorf(".bashrc: %s", rc)
	}
	st := f.s.currentStatus()
	if !st.Greeting.On || len(st.Greeting.Shells) != 3 {
		t.Errorf("status %+v", st.Greeting)
	}
	// off again: gone, .bashrc as it was
	f.write(f.cfg, `{"greeting":"none"}`)
	if err := f.s.Apply(); err != nil {
		t.Fatal(err)
	}
	if rc, _ := os.ReadFile(filepath.Join(f.home, ".bashrc")); string(rc) != "# mine\n" {
		t.Errorf(".bashrc after off: %q", rc)
	}
	if _, err := os.Stat(termlook.GreetingScriptFile(env)); err == nil {
		t.Error("greeting.sh left")
	}
}

// Defaults: an old terminal.json without the new keys and greeting
// fastfetch keeps plain fastfetch (the own look) as before.
func TestGreetingDefaultsKeepPlainFastfetch(t *testing.T) {
	f := greetFixture(t, `{"enabled":true,"greeting":"fastfetch"}`)
	g := f.s.greeting()
	if !g.On || g.Preset != termlook.FetchOwn || g.Logo != termlook.LogoSakura || g.LoginShell != "/usr/bin/fish" {
		t.Errorf("greeting %+v", g)
	}
}

func TestFetchPresetsAndPreview(t *testing.T) {
	f := greetFixture(t, greetingOn)
	out, err := f.s.fetchPresets(nil)
	if err != nil {
		t.Fatal(err)
	}
	if ps := out.([]termlook.FetchPreset); len(ps) != 6 || ps[0].ID != "sakura" {
		t.Errorf("presets %+v", ps)
	}
	b, _ := json.Marshal(out)
	if strings.Contains(string(b), "modules") {
		t.Error("presets leak their config")
	}
	// fastfetch missing: the sample, drawn in the palette and the given ANSI colours
	ansi := make([]string, 16)
	for i := range ansi {
		ansi[i] = "#00000" + string(rune('0'+i%10))
	}
	res, err := f.s.fetchPreview(json.RawMessage(`{"preset":"compact","logo":"distro","ansi":` + mustJSON(ansi) + `}`))
	if err != nil {
		t.Fatal(err)
	}
	pv := res.(fetchPreviewJSON)
	if pv.Exact || pv.Reason != "fastfetch_missing" || len(pv.Lines) == 0 {
		t.Errorf("preview %+v", pv)
	}
	for _, bad := range []string{`{"preset":"../x"}`, `{"preset":"nope"}`, `{"logo":"picture"}`,
		`{"ansi":["#000000"]}`, `{"ansi":` + mustJSON(append(ansi[:15:15], "red")) + `}`} {
		if _, err := f.s.fetchPreview(json.RawMessage(bad)); err == nil {
			t.Errorf("%s accepted", bad)
		}
	}
}

func mustJSON(v any) string {
	b, _ := json.Marshal(v)
	return string(b)
}

// A palette change re-renders the greeting while only the greeting is on.
func TestWatcherReappliesTheGreetingOnColorChange(t *testing.T) {
	f := greetFixture(t, greetingOn)
	if err := f.s.Start(); err != nil {
		t.Fatal(err)
	}
	defer f.s.Stop()
	conf := termlook.FetchConfigFile(f.s.o.Env)
	waitFor(t, func() bool { _, err := os.Stat(conf); return err == nil }, "initial greeting")
	before, _ := os.ReadFile(conf)
	data, _ := os.ReadFile(f.colors)
	f.write(f.colors, strings.ReplaceAll(string(data), `"primary": "#f5adff"`, `"primary": "#123456"`))
	waitFor(t, func() bool {
		a, _ := os.ReadFile(conf)
		return strings.Contains(string(a), "#123456") && string(a) != string(before)
	}, "greeting re-rendered")
}
