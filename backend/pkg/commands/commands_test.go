package commands

import (
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"

	"yozakura/backend/pkg/catalog"
)

const repoRoot = "../../.."

const fixture = `{
  "version": 1,
  "commands": [
    {"id": "dnd", "title": "t.dnd", "description": "t.dnd.desc", "run": {"ui": "dnd-toggle"}},
    {"id": "bar", "title": "t.bar", "run": {"toggle": "bar"}},
    {"id": "preset", "title": "t.preset", "arg": {"kind": "preset", "required": true}, "run": {"cli": ["preset", "apply", "{arg}"]}},
    {"id": "wallpaper", "title": "t.wall", "arg": {"kind": "enum", "values": ["random", "next"], "default": "random"}, "run": {"ui": "wallpaper-{arg}"}},
    {"id": "glass", "title": "t.glass", "arg": {"kind": "number", "min": 0, "max": 1, "required": true}, "run": {"config": "theme.glass.amount"}},
    {"id": "theme", "title": "t.theme", "arg": {"kind": "enum", "values": ["light", "dark"], "required": true}, "run": {"config": "theme.lightMode", "map": {"light": true, "dark": false}}}
  ]
}`

func load(t *testing.T) *Registry {
	r, err := Parse([]byte(fixture))
	if !assert.NoError(t, err) {
		t.FailNow()
	}
	return r
}

func TestParseValidates(t *testing.T) {
	for name, bad := range map[string]string{
		"dup":       `{"commands":[{"id":"a","title":"x","run":{"ui":"a"}},{"id":"a","title":"x","run":{"ui":"b"}}]}`,
		"two runs":  `{"commands":[{"id":"a","title":"x","run":{"ui":"a","cli":["b"]}}]}`,
		"no run":    `{"commands":[{"id":"a","title":"x","run":{}}]}`,
		"no title":  `{"commands":[{"id":"a","run":{"ui":"a"}}]}`,
		"bad kind":  `{"commands":[{"id":"a","title":"x","arg":{"kind":"color"},"run":{"ui":"a"}}]}`,
		"enum def":  `{"commands":[{"id":"a","title":"x","arg":{"kind":"enum","values":["x"],"default":"y"},"run":{"ui":"a"}}]}`,
		"cfg noarg": `{"commands":[{"id":"a","title":"x","run":{"config":"theme.roundness"}}]}`,
		"map key":   `{"commands":[{"id":"a","title":"x","arg":{"kind":"enum","values":["x"]},"run":{"config":"k","map":{"y":1}}}]}`,
		"space id":  `{"commands":[{"id":"a b","title":"x","run":{"ui":"a"}}]}`,
	} {
		_, err := Parse([]byte(bad))
		assert.Error(t, err, name)
	}
}

func TestPlans(t *testing.T) {
	r := load(t)
	cases := []struct {
		id, arg string
		want    Plan
		err     string
	}{
		{"dnd", "", Plan{Kind: KindUI, Value: "dnd-toggle"}, ""},
		{"DND", "", Plan{Kind: KindUI, Value: "dnd-toggle"}, ""},
		{"dnd", "x", Plan{}, "takes no argument"},
		{"bar", "", Plan{Kind: KindToggle, Value: "bar"}, ""},
		{"preset", "Neon Tokyo", Plan{Kind: KindCLI, Args: []string{"preset", "apply", "Neon Tokyo"}}, ""},
		{"preset", "", Plan{}, "usage: preset <preset name>"},
		{"wallpaper", "", Plan{Kind: KindUI, Value: "wallpaper-random"}, ""},
		{"wallpaper", "NEXT", Plan{Kind: KindUI, Value: "wallpaper-next"}, ""},
		{"wallpaper", "up", Plan{}, "not one of random, next"},
		{"glass", "0,6", Plan{Kind: KindConfig, Key: "theme.glass.amount", ConfigValue: "0.6"}, ""},
		{"glass", "2", Plan{}, "out of range 0..1"},
		{"glass", "lots", Plan{}, "not a number"},
		{"theme", "light", Plan{Kind: KindConfig, Key: "theme.lightMode", ConfigValue: true}, ""},
	}
	for _, c := range cases {
		cmd, ok := r.Find(c.id)
		if !assert.True(t, ok, c.id) {
			t.FailNow()
		}
		p, err := cmd.Plan(c.arg)
		if c.err != "" {
			assert.ErrorContains(t, err, c.err, c.id+" "+c.arg)
			continue
		}
		assert.NoError(t, err)
		assert.Equal(t, c.want, p, c.id+" "+c.arg)
	}
	_, err := r.Run(Executor{}, "nope", "")
	assert.ErrorContains(t, err, "unknown command")
}

func TestExecutor(t *testing.T) {
	r := load(t)
	var calls []string
	e := Executor{
		Call: func(m string, p any) error {
			calls = append(calls, m+":"+p.(map[string]any)["command"].(string))
			return nil
		},
		Exec: func(a []string) (string, error) {
			calls = append(calls, "exec:"+strings.Join(a, " "))
			return "ok", nil
		},
		SetConfig: func(k string, v any) (string, error) {
			calls = append(calls, "set:"+k)
			return "", nil
		},
	}
	for _, c := range [][2]string{{"dnd", ""}, {"bar", ""}, {"preset", "Sumi-e"}, {"glass", "0.5"}} {
		_, err := r.Run(e, c[0], c[1])
		assert.NoError(t, err)
	}
	assert.Equal(t, []string{"ui.run:dnd-toggle", "ui.toggle:bar", "exec:preset apply Sumi-e", "set:theme.glass.amount"}, calls)
}

func TestConfigSetter(t *testing.T) {
	cat, err := catalog.Load(repoRoot)
	if !assert.NoError(t, err) {
		t.FailNow()
	}
	dir := t.TempDir()
	store := &catalog.Store{Cat: cat, File: func(d string) string { return filepath.Join(dir, d+".json") }}
	set := ConfigSetter(store)
	out, err := set("theme.roundness", "12")
	if !assert.NoError(t, err) {
		t.FailNow()
	}
	assert.Contains(t, out, "theme.roundness")
	v, _, _ := store.Get("theme.roundness")
	assert.EqualValues(t, 12, v)
	_, err = set("theme.lightMode", true)
	if !assert.NoError(t, err) {
		t.FailNow()
	}
	_, err = set("theme.roundness", "99")
	assert.Error(t, err)
}

func TestUsageAndViews(t *testing.T) {
	r := load(t)
	g, _ := r.Find("glass")
	assert.Equal(t, "glass <0..1>", g.Usage())
	w, _ := r.Find("wallpaper")
	assert.Equal(t, "wallpaper [random|next]", w.Usage())
	r.Localize(map[string]string{"t.dnd": "Do not disturb", "t.dnd.desc": "Silence popups"})
	v := r.Views()[0]
	assert.Equal(t, "Do not disturb", v.Title)
	assert.Equal(t, "Silence popups", v.Description)
	assert.Equal(t, "", r.Views()[1].Description)
}

// shellCases parses the case labels of a function in GlobalShortcuts.qml.
func shellCases(t *testing.T, fn string) map[string]bool {
	data, err := os.ReadFile(filepath.Join(repoRoot, "modules", "services", "GlobalShortcuts.qml"))
	if !assert.NoError(t, err) {
		t.FailNow()
	}
	src := string(data)
	start := strings.Index(src, "function "+fn+"(")
	if !assert.GreaterOrEqual(t, start, 0, fn) {
		t.FailNow()
	}
	body := src[start:]
	if end := strings.Index(body[1:], "\n    function "); end > 0 {
		body = body[:end+1]
	}
	if end := strings.Index(body, "property IpcHandler"); end > 0 {
		body = body[:end]
	}
	out := map[string]bool{}
	for _, m := range regexp.MustCompile(`case "([^"]+)"`).FindAllStringSubmatch(body, -1) {
		out[m[1]] = true
	}
	return out
}

// The real registry: valid, translated, every config key in the catalog,
// every UI command handled by the shell.
func TestRealRegistry(t *testing.T) {
	r, err := Load(repoRoot)
	if !assert.NoError(t, err) {
		t.FailNow()
	}
	assert.NotEmpty(t, r.Commands)
	cat, err := catalog.Load(repoRoot)
	if !assert.NoError(t, err) {
		t.FailNow()
	}
	for _, c := range r.Commands {
		assert.NotEqual(t, c.Title, c.Label, "%s: title %s has no English translation", c.ID, c.Title)
		if c.Run.Config != "" {
			_, err := cat.Lookup(c.Run.Config)
			assert.NoError(t, err, c.ID)
		}
	}
	run, toggle := r.UICommands()
	runCases, toggleCases := shellCases(t, "run"), shellCases(t, "toggle")
	var missing []string
	for _, c := range run {
		if !runCases[c] {
			missing = append(missing, "run "+c)
		}
	}
	for _, c := range toggle {
		if !toggleCases[c] {
			missing = append(missing, "toggle "+c)
		}
	}
	sort.Strings(missing)
	assert.Empty(t, missing, "commands.json sends UI commands GlobalShortcuts.qml does not handle")
}
