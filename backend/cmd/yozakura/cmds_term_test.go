package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"

	"yozakura/backend/pkg/termlook"
)

type fakeTerm struct {
	results map[string]string
	calls   []string
	params  map[string]any
	sets    [][2]any
	setErr  error
}

func (f *fakeTerm) Call(method string, params any) (json.RawMessage, error) {
	f.calls = append(f.calls, method)
	if m, ok := params.(map[string]any); ok {
		f.params = m
	}
	if r, ok := f.results[method]; ok {
		return json.RawMessage(r), nil
	}
	return nil, errors.New("down")
}

func (f *fakeTerm) SetConfig(key string, v any) error {
	f.sets = append(f.sets, [2]any{key, v})
	return f.setErr
}

func newFakeTerm() *fakeTerm {
	return &fakeTerm{results: map[string]string{
		"term.presets": `[{"id":"zen","name":"Zen","description":"term.prompt.zen.desc","nerdFont":true,"lines":1},{"id":"pure","name":"Pure","nerdFont":true,"lines":2}]`,
		"term.apply":   `{"enabled":true,"engine":"starship","engineInstalled":{"starship":false,"ohmyposh":false},"fishInstalled":true,"fishIsLoginShell":false,"foreignPromptInit":true}`,
		"term.preview": `{"left":[[{"text":"~","fg":"#ff0000","bold":true}]],"right":[{"text":"4s","bg":"#000010"}],"exact":false,"engine":"starship","reason":"engine_missing"}`,
		"term.status":  `{"enabled":true,"fishInstalled":true,"fishIsLoginShell":false,"engineInstalled":{"starship":true},"foreignPromptInit":true,"foreignFile":"/h/config.fish"}`,
	}}
}

func termRun(t *testing.T, f *fakeTerm, args ...string) (int, string, string) {
	t.Helper()
	var out, errOut bytes.Buffer
	code := runTerm(args, f, &out, &errOut)
	return code, out.String(), errOut.String()
}

func TestTermList(t *testing.T) {
	f := newFakeTerm()
	code, out, _ := termRun(t, f)
	assert.Equal(t, 0, code)
	assert.Contains(t, out, "zen")
	assert.Contains(t, out, "Pure")
	code, out, _ = termRun(t, f, "list", "--json")
	assert.Equal(t, 0, code)
	assert.Contains(t, out, `"id": "zen"`)
}

func TestTermSetWritesConfigThenApplies(t *testing.T) {
	f := newFakeTerm()
	code, out, errOut := termRun(t, f, "set", "zen", "--engine", "ohmyposh")
	assert.Equal(t, 0, code, errOut)
	assert.Equal(t, [][2]any{{"terminal.engine", "ohmyposh"}, {"terminal.prompt", "zen"}, {"terminal.enabled", true}}, f.sets)
	assert.Equal(t, "term.apply", f.calls[len(f.calls)-1])
	assert.Contains(t, out, "prompt set to zen")
	assert.Contains(t, out, "extras install starship")
	assert.Contains(t, out, "not your login shell")
	assert.Contains(t, out, "config.fish also sets a prompt")
}

func TestTermSetValidates(t *testing.T) {
	f := newFakeTerm()
	for _, args := range [][]string{{"set", "nope"}, {"set", "../x"}, {"set", "Zen"}, {"set"}, {"set", "zen", "--engine", "zsh"}, {"bogus"}} {
		code, _, errOut := termRun(t, f, args...)
		assert.NotEqual(t, 0, code, args)
		assert.NotEmpty(t, errOut, args)
	}
	assert.Empty(t, f.sets, "nothing is written for invalid input")
}

func TestTermOff(t *testing.T) {
	f := newFakeTerm()
	f.results["term.apply"] = `{"enabled":false}`
	code, out, _ := termRun(t, f, "off")
	assert.Equal(t, 0, code)
	assert.Equal(t, [][2]any{{"terminal.enabled", false}}, f.sets)
	assert.Contains(t, out, "prompt off")
}

func TestTermPreviewDrawsAnsi(t *testing.T) {
	f := newFakeTerm()
	code, out, _ := termRun(t, f, "preview", "zen", "--engine", "starship", "--width", "100")
	assert.Equal(t, 0, code)
	assert.Equal(t, map[string]any{"prompt": "zen", "width": 100, "engine": "starship"}, f.params)
	assert.Contains(t, out, "\x1b[1;38;2;255;0;0m~\x1b[0m")
	assert.Contains(t, out, "right: \x1b[48;2;0;0;16m4s")
	assert.Contains(t, out, "approximate preview: engine_missing")
	code, _, _ = termRun(t, f, "preview", "zen", "--width", "x")
	assert.Equal(t, 2, code)
}

func TestTermStatusAndDaemonDown(t *testing.T) {
	f := newFakeTerm()
	_, out, _ := termRun(t, f, "status")
	assert.Contains(t, out, "starship installed: true")
	assert.Contains(t, out, "/h/config.fish also sets a prompt")
	code, _, errOut := termRun(t, &fakeTerm{results: map[string]string{}}, "list")
	assert.Equal(t, 1, code)
	assert.Contains(t, errOut, "Error")
}

func TestTermCompletionKnowsTerm(t *testing.T) {
	for _, sh := range []string{"bash", "zsh", "fish"} {
		s, err := completionScript(sh)
		assert.NoError(t, err)
		assert.Contains(t, s, "preview", sh)
		assert.True(t, strings.Contains(s, "term"), sh)
	}
}

func TestGoodbyeRemovesTermHook(t *testing.T) {
	home := t.TempDir()
	env := termlook.Env{ConfigHome: home, AppID: "yozakura"}
	hook := termlook.HookFile(env)
	assert.NoError(t, os.MkdirAll(filepath.Dir(hook), 0o755))
	assert.NoError(t, os.WriteFile(hook, []byte("x"), 0o644))
	conf := filepath.Join(home, "fish", "config.fish")
	assert.NoError(t, os.WriteFile(conf, []byte("user config"), 0o644))
	var out bytes.Buffer
	removeTermHook(&out, env)
	_, err := os.Stat(hook)
	assert.True(t, os.IsNotExist(err))
	assert.FileExists(t, conf, "config.fish is never touched")
	assert.Empty(t, out.String())
	removeTermHook(&out, env) // idempotent
	assert.Empty(t, out.String())
}
