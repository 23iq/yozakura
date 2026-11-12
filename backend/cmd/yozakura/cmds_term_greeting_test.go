package main

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"

	"yozakura/backend/pkg/termlook"
)

func greetFake() *fakeTerm {
	f := newFakeTerm()
	f.results["term.fetch.presets"] = `[{"id":"sakura","name":"Sakura","description":"term.fetch.preset.sakura.desc","logo":true},{"id":"own","name":"","description":"term.fetch.preset.own.desc","own":true}]`
	f.results["term.apply"] = `{"greeting":{"on":true,"fastfetchInstalled":false,"shells":[{"shell":"bash","state":"on"}],"logoError":"logo_missing"}}`
	f.results["term.status"] = `{"greeting":{"on":true,"fastfetchInstalled":true,"shells":[{"shell":"fish","state":"on"},{"shell":"bash","state":"foreign","file":"/h/.bashrc"},{"shell":"zsh","state":"absent"}]}}`
	f.results["term.fetch.allow"] = f.results["term.status"]
	f.results["term.fetch.preview"] = `{"lines":[[{"text":"user","fg":"#ff0000"}]],"exact":true}`
	return f
}

func TestTermGreetingOnOffAndLook(t *testing.T) {
	f := greetFake()
	code, out, errOut := termRun(t, f, "greeting", "on")
	assert.Equal(t, 0, code, errOut)
	// no fastfetch config of the user's (status): the sakura look, like Settings
	assert.Equal(t, [][2]any{{"terminal.fastfetchPreset", "sakura"}, {"terminal.greeting", "fastfetch"}}, f.sets)
	assert.Equal(t, "term.apply", f.calls[len(f.calls)-1])
	assert.Contains(t, f.calls, "term.fetch.allow", "switched on by the user: every shell")
	assert.Contains(t, out, "extras install fastfetch")
	assert.Contains(t, out, "cannot be read")

	// a look chosen already, or a config of the user's: kept
	f = greetFake()
	f.sets = [][2]any{{"terminal.fastfetchPreset", "boxed"}}
	code, _, errOut = termRun(t, f, "greeting", "on")
	assert.Equal(t, 0, code, errOut)
	assert.Equal(t, [][2]any{{"terminal.fastfetchPreset", "boxed"}, {"terminal.greeting", "fastfetch"}}, f.sets)
	f = greetFake()
	f.results["term.fetch.allow"] = `{"greeting":{"on":false,"ownConfig":true,"shells":[]}}`
	f.sets = [][2]any{{"terminal.fastfetchPreset", "own"}}
	code, _, errOut = termRun(t, f, "greeting", "on")
	assert.Equal(t, 0, code, errOut)
	assert.Equal(t, [][2]any{{"terminal.fastfetchPreset", "own"}, {"terminal.greeting", "fastfetch"}}, f.sets)

	f = greetFake()
	code, _, _ = termRun(t, f, "greeting", "off")
	assert.Equal(t, 0, code)
	assert.Equal(t, [][2]any{{"terminal.greeting", "none"}}, f.sets)
	assert.NotContains(t, f.calls, "term.fetch.allow")

	f = greetFake()
	code, _, errOut = termRun(t, f, "greeting", "preset", "sakura")
	assert.Equal(t, 0, code, errOut)
	assert.Equal(t, [][2]any{{"terminal.fastfetchPreset", "sakura"}}, f.sets)
	code, _, errOut = termRun(t, f, "greeting", "preset", "nope")
	assert.Equal(t, 1, code)
	assert.Contains(t, errOut, "presets: sakura, own")
	code, _, _ = termRun(t, f, "greeting", "preset", "../x")
	assert.Equal(t, 1, code)
}

func TestTermGreetingLogo(t *testing.T) {
	f := greetFake()
	code, _, errOut := termRun(t, f, "greeting", "logo", "distro")
	assert.Equal(t, 0, code, errOut)
	assert.Equal(t, [][2]any{{"terminal.fastfetchLogo", "distro"}}, f.sets)

	dir := t.TempDir()
	art := filepath.Join(dir, "art.txt")
	assert.NoError(t, os.WriteFile(art, []byte("$1<>\n"), 0o644))
	f = greetFake()
	code, out, errOut := termRun(t, f, "greeting", "logo", art)
	assert.Equal(t, 0, code, errOut)
	assert.Equal(t, [][2]any{{"terminal.fastfetchLogoPath", art}, {"terminal.fastfetchLogo", "custom"}}, f.sets)
	assert.Contains(t, out, "greeting logo set to "+art)

	f = greetFake()
	code, _, errOut = termRun(t, f, "greeting", "logo", filepath.Join(dir, "missing.png"))
	assert.Equal(t, 1, code)
	assert.Contains(t, errOut, "cannot be read")
	assert.Empty(t, f.sets)
	code, _, errOut = termRun(t, f, "greeting", "logo", "custom")
	assert.Equal(t, 1, code)
	assert.Contains(t, errOut, "logo <file>")
}

func TestTermGreetingShowListPreview(t *testing.T) {
	f := greetFake()
	f.sets = [][2]any{{"terminal.fastfetchPreset", "sakura"}, {"terminal.fastfetchLogo", "distro"}}
	code, out, _ := termRun(t, f, "greeting")
	assert.Equal(t, 0, code)
	assert.Contains(t, out, "greeting: on (fastfetch)")
	assert.Contains(t, out, "look: sakura")
	assert.Contains(t, out, "logo: distro")
	assert.Contains(t, out, "bash: your /h/.bashrc runs a fetch tool itself")
	code, out, _ = termRun(t, f, "greeting", "--json")
	assert.Equal(t, 0, code)
	assert.Contains(t, out, `"preset": "sakura"`)

	code, out, _ = termRun(t, f, "greeting", "presets")
	assert.Equal(t, 0, code)
	assert.Contains(t, out, "your own fastfetch config")

	code, out, _ = termRun(t, f, "greeting", "preview", "sakura", "--logo", "none")
	assert.Equal(t, 0, code)
	assert.Equal(t, map[string]any{"preset": "sakura", "logo": "none"}, f.params)
	assert.Contains(t, out, "\x1b[38;2;255;0;0muser")

	code, _, errOut := termRun(t, f, "greeting", "bogus")
	assert.Equal(t, 2, code)
	assert.Contains(t, errOut, "term greeting preset")
	code, out, _ = termRun(t, f, "greeting", "help")
	assert.Equal(t, 0, code)
	assert.Contains(t, out, "fastfetch when a terminal opens")
}

// goodbye takes the greeting out of ~/.bashrc and fish.
func TestGoodbyeRemovesTheGreeting(t *testing.T) {
	home := t.TempDir()
	env := termlook.Env{Home: home, ConfigHome: filepath.Join(home, ".config"), AppID: "yozakura",
		DataHome: filepath.Join(home, ".local", "share"),
		LookPath: func(b string) (string, bool) { return "/usr/bin/" + b, b == "bash" || b == "fish" }}
	bashrc := filepath.Join(home, ".bashrc")
	assert.NoError(t, os.WriteFile(bashrc, []byte("# mine\n"), 0o644))
	ps, err := termlook.LoadFetchPresets("../../../assets/terminal/fastfetch")
	assert.NoError(t, err)
	_, err = termlook.ApplyGreeting(termlook.GreetingConfig{On: true, Preset: "sakura", Logo: "sakura"}, nil, ps,
		termlook.SakuraLogoFile("../../../assets/terminal/fastfetch"), env)
	assert.NoError(t, err)
	removed, err := removeGreeting(env)
	assert.NoError(t, err)
	assert.Len(t, removed, 2)
	data, _ := os.ReadFile(bashrc)
	assert.Equal(t, "# mine\n", string(data))
	removed, err = removeGreeting(env)
	assert.NoError(t, err)
	assert.Empty(t, removed)
}

// On from before the update: the status says how to let it into bash too.
func TestTermGreetingShowsHeldShells(t *testing.T) {
	f := greetFake()
	f.results["term.status"] = `{"greeting":{"on":true,"fastfetchInstalled":true,"shells":[{"shell":"fish","state":"on"},{"shell":"bash","state":"held","file":"/h/.bashrc"}]}}`
	code, out, errOut := termRun(t, f, "greeting")
	assert.Equal(t, 0, code, errOut)
	assert.Contains(t, out, "bash: off (on from before the update, fish only")
	assert.Contains(t, out, "term greeting on` adds the line to /h/.bashrc")
}

func TestTermGreetingShowsEditedMarkers(t *testing.T) {
	f := greetFake()
	f.results["term.status"] = `{"greeting":{"on":true,"fastfetchInstalled":true,"shells":[{"shell":"bash","state":"broken","file":"/h/.bashrc"}]}}`
	code, out, errOut := termRun(t, f, "greeting")
	assert.Equal(t, 0, code, errOut)
	assert.Contains(t, out, "bash: the greeting's marker lines in /h/.bashrc were edited")
}
