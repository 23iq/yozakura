package main

import (
	"bytes"
	"testing"
	"yozakura/backend/pkg/catalog"
	"yozakura/backend/pkg/mcp/yozakura"

	"github.com/stretchr/testify/assert"
)

// keyboardEnvWith is a keyboard env over rc for an already sandboxed test.
func keyboardEnvWith(rc *recCaller) (keyboardEnv, *recCaller) {
	return keyboardEnv{c: rc, store: func() (*catalog.Store, error) { e, err := loadConfigEnv(); return e.store, err }}, rc
}

func keyboardTestEnv(t *testing.T) (keyboardEnv, *recCaller) {
	sandbox(t)
	rc := &recCaller{results: map[string]string{
		"keyboard.catalog": `{"layouts":[{"name":"us","variants":[{"name":"intl"}]},{"name":"ru","variants":[]}]}`,
		"keyboard.active":  `{"name":"English (US)","index":0,"code":"us","short":"EN"}`,
		"keyboard.next":    `{"ok":true}`,
		"keyboard.current": `{"available":true,"layouts":[{"layout":"us","variant":""}],"switchBind":"alt_shift","options":[],"repeatRate":25,"repeatDelay":600}`,
	}}
	return keyboardEnv{c: rc, store: func() (*catalog.Store, error) { e, err := loadConfigEnv(); return e.store, err }}, rc
}

func TestKeyboardCLI(t *testing.T) {
	env, rc := keyboardTestEnv(t)
	var out, errOut bytes.Buffer
	kb := func(args ...string) int { out.Reset(); errOut.Reset(); return runKeyboard(args, env, &out, &errOut) }

	assert.Equal(t, 0, kb("list"), errOut.String())
	assert.Contains(t, out.String(), "1  us")
	assert.Contains(t, out.String(), "Switch: alt_shift")
	assert.Contains(t, out.String(), "Active: English (US)")

	assert.Equal(t, 0, kb("add", "ru"), errOut.String())
	assert.Contains(t, out.String(), "Layouts: us, ru")
	_, got, _ := run(t, cfg, "get", "keyboard.layouts", "--json")
	assert.Contains(t, got, `"layout": "ru"`)

	assert.Equal(t, 0, kb("add", "ru"))
	assert.Contains(t, out.String(), "already configured")
	assert.Equal(t, 0, kb("add", "us:intl"))
	assert.Contains(t, out.String(), "us, ru, us:intl")

	assert.Equal(t, 1, kb("add", "zz"), "unknown to the XKB catalog")
	assert.Equal(t, 1, kb("add", "us:nope"))
	assert.Equal(t, 1, kb("add", "Bad Name"))

	assert.Equal(t, 0, kb("remove", "us:intl"))
	assert.Equal(t, 0, kb("remove", "ru"))
	assert.Equal(t, 1, kb("remove", "us"), "last layout stays")
	assert.Equal(t, 1, kb("remove", "de"), "not configured")

	assert.Equal(t, 0, kb("switch-bind", "super_space"))
	_, got, _ = run(t, cfg, "get", "keyboard.switchBind")
	assert.Equal(t, "super_space\n", got)
	assert.Equal(t, 1, kb("switch-bind", "hyper"))

	assert.Equal(t, 0, kb("next"))
	assert.Equal(t, "keyboard.next", rc.calls[len(rc.calls)-1])
	assert.Equal(t, 2, kb("bogus"))
	assert.Equal(t, 2, kb("add"))
}

// Until the first change the compositor's own settings are shown; the first
// change copies them in (us,ru + 111/175 survive) and sets keyboard.managed.
func TestKeyboardCLITakesOverCompositorSettings(t *testing.T) {
	env, rc := keyboardTestEnv(t)
	rc.results["keyboard.current"] = `{"available":true,"layouts":[{"layout":"us","variant":""},{"layout":"ru","variant":""}],"switchBind":"alt_shift","options":["caps:escape"],"repeatRate":111,"repeatDelay":175}`
	var out, errOut bytes.Buffer
	kb := func(args ...string) int { out.Reset(); errOut.Reset(); return runKeyboard(args, env, &out, &errOut) }

	assert.Equal(t, 0, kb("list"), errOut.String())
	assert.Contains(t, out.String(), "2  ru", "unmanaged: list shows the compositor's layouts")
	assert.Contains(t, out.String(), "your compositor config")
	_, got, _ := run(t, cfg, "get", "keyboard.managed")
	assert.Equal(t, "false\n", got, "listing changes nothing")

	assert.Equal(t, 0, kb("add", "us:intl"), errOut.String())
	assert.Contains(t, out.String(), "Layouts: us, ru, us:intl")
	_, got, _ = run(t, cfg, "get", "keyboard.managed")
	assert.Equal(t, "true\n", got)
	_, got, _ = run(t, cfg, "get", "keyboard.repeatRate")
	assert.Equal(t, "111\n", got)
	_, got, _ = run(t, cfg, "get", "keyboard.repeatDelay")
	assert.Equal(t, "175\n", got)
	_, got, _ = run(t, cfg, "get", "keyboard.options", "--json")
	assert.Contains(t, got, "caps:escape")

	// managed now: the compositor is not asked again
	before := len(rc.calls)
	assert.Equal(t, 0, kb("remove", "us:intl"))
	for _, c := range rc.calls[before:] {
		assert.NotEqual(t, "keyboard.current", c)
	}
	assert.Contains(t, out.String(), "Layouts: us, ru")
}

// Without the compositor's current settings nothing is written: the defaults
// must never replace the user's own layouts.
func TestKeyboardCLIFailsClosedWhenUnreadable(t *testing.T) {
	env, rc := keyboardTestEnv(t)
	delete(rc.results, "keyboard.current")
	var out, errOut bytes.Buffer
	assert.Equal(t, 1, runKeyboard([]string{"switch-bind", "caps"}, env, &out, &errOut))
	assert.Contains(t, errOut.String(), "is the shell running")
	_, got, _ := run(t, cfg, "get", "keyboard.switchBind")
	assert.Equal(t, "alt_shift\n", got)
	_, got, _ = run(t, cfg, "get", "keyboard.managed")
	assert.Equal(t, "false\n", got)

	// unreadable compositor settings: replacing them needs --replace
	rc.results["keyboard.current"] = `{"available":false,"layouts":[],"switchBind":"none","options":[]}`
	errOut.Reset()
	assert.Equal(t, 1, runKeyboard([]string{"switch-bind", "caps"}, env, &out, &errOut))
	assert.Contains(t, errOut.String(), "--replace")
	_, got, _ = run(t, cfg, "get", "keyboard.managed")
	assert.Equal(t, "false\n", got)
	assert.Equal(t, 0, runKeyboard([]string{"switch-bind", "caps", "--replace"}, env, &out, &errOut), errOut.String())
	_, got, _ = run(t, cfg, "get", "keyboard.layouts", "--json")
	assert.Contains(t, got, `"layout": "us"`)
	_, got, _ = run(t, cfg, "get", "keyboard.managed")
	assert.Equal(t, "true\n", got)
}

// `config set keyboard.*` takes the compositor's settings over first (one
// atomic write), after validating the value; showIndicator never does.
func TestConfigSetKeyboardTakesOver(t *testing.T) {
	_, rc := keyboardTestEnv(t)
	rc.results["keyboard.current"] = `{"available":true,"layouts":[{"layout":"us","variant":""},{"layout":"ru","variant":""}],"switchBind":"alt_shift","options":[],"repeatRate":111,"repeatDelay":175}`
	old := keyboardDaemon
	keyboardDaemon = func() yozakura.Caller { return rc }
	t.Cleanup(func() { keyboardDaemon = old })
	get := func(key string) string { _, got, _ := run(t, cfg, "get", key); return got }

	code, _, _ := run(t, cfg, "set", "keyboard.showIndicator", "false")
	assert.Equal(t, 0, code)
	assert.Equal(t, "false\n", get("keyboard.managed"), "showIndicator stays unmanaged")

	code, _, _ = run(t, cfg, "set", "keyboard.repeatRate", "500")
	assert.Equal(t, 1, code, "out of range")
	assert.Equal(t, "false\n", get("keyboard.managed"), "a failing set never takes over")

	code, _, errS := run(t, cfg, "set", "keyboard.repeatRate", "50")
	assert.Equal(t, 0, code, errS)
	assert.Equal(t, "true\n", get("keyboard.managed"))
	assert.Equal(t, "50\n", get("keyboard.repeatRate"))
	assert.Equal(t, "175\n", get("keyboard.repeatDelay"), "the compositor's other values are copied in")
	_, got, _ := run(t, cfg, "get", "keyboard.layouts", "--json")
	assert.Contains(t, got, `"layout": "ru"`)

	// a later edit (UI, CLI) keeps 50: the compositor is not read again
	env, _ := keyboardEnvWith(rc)
	var out, errOut bytes.Buffer
	assert.Equal(t, 0, runKeyboard([]string{"add", "us:intl"}, env, &out, &errOut), errOut.String())
	assert.Equal(t, "50\n", get("keyboard.repeatRate"))
}

func TestConfigToggleManagedTakesOver(t *testing.T) {
	_, rc := keyboardTestEnv(t)
	rc.results["keyboard.current"] = `{"available":true,"layouts":[{"layout":"de","variant":""}],"switchBind":"caps","options":[],"repeatRate":30,"repeatDelay":300}`
	old := keyboardDaemon
	keyboardDaemon = func() yozakura.Caller { return rc }
	t.Cleanup(func() { keyboardDaemon = old })
	code, _, errS := run(t, cfg, "toggle", "keyboard.managed")
	assert.Equal(t, 0, code, errS)
	_, got, _ := run(t, cfg, "get", "keyboard.switchBind")
	assert.Equal(t, "caps\n", got)
	_, got, _ = run(t, cfg, "get", "keyboard.repeatDelay")
	assert.Equal(t, "300\n", got)
}

// --add/--remove and [i] on keyboard arrays apply to the compositor's
// values (us,ru), not the stale defaults; a failing write takes nothing over.
func TestConfigSetKeyboardArraysUseCompositorValues(t *testing.T) {
	_, rc := keyboardTestEnv(t)
	rc.results["keyboard.current"] = `{"available":true,"layouts":[{"layout":"us","variant":""},{"layout":"ru","variant":""}],"switchBind":"alt_shift","options":["caps:escape"],"repeatRate":111,"repeatDelay":175}`
	old := keyboardDaemon
	keyboardDaemon = func() yozakura.Caller { return rc }
	t.Cleanup(func() { keyboardDaemon = old })
	layouts := func() string { _, got, _ := run(t, cfg, "get", "keyboard.layouts", "--json"); return got }
	managed := func() string { _, got, _ := run(t, cfg, "get", "keyboard.managed"); return got }

	code, _, _ := run(t, cfg, "set", "keyboard.layouts[5]", `{"layout":"de","variant":""}`)
	assert.Equal(t, 1, code, "index out of range on us,ru")
	assert.Equal(t, "false\n", managed(), "a failing indexed write takes nothing over")

	code, _, errS := run(t, cfg, "set", "keyboard.layouts", "--add", `{"layout":"de","variant":""}`)
	assert.Equal(t, 0, code, errS)
	got := layouts()
	assert.Contains(t, got, `"layout": "ru"`, "us,ru + de, not us,de")
	assert.Contains(t, got, `"layout": "de"`)
	assert.Equal(t, "true\n", managed())
	_, opts, _ := run(t, cfg, "get", "keyboard.options", "--json")
	assert.Contains(t, opts, "caps:escape")
}

func TestConfigSetKeyboardRemoveAndIndexAfterTakeover(t *testing.T) {
	_, rc := keyboardTestEnv(t)
	rc.results["keyboard.current"] = `{"available":true,"layouts":[{"layout":"us","variant":""},{"layout":"ru","variant":""}],"switchBind":"alt_shift","options":["caps:escape"],"repeatRate":111,"repeatDelay":175}`
	old := keyboardDaemon
	keyboardDaemon = func() yozakura.Caller { return rc }
	t.Cleanup(func() { keyboardDaemon = old })

	// ru is not in the stale defaults, but is in the compositor's options/layouts
	code, _, errS := run(t, cfg, "set", "keyboard.options", "--remove", "caps:escape")
	assert.Equal(t, 0, code, errS)
	_, got, _ := run(t, cfg, "get", "keyboard.layouts", "--json")
	assert.Contains(t, got, `"layout": "ru"`)

	_, rc2 := keyboardTestEnv(t)
	rc2.results["keyboard.current"] = rc.results["keyboard.current"]
	keyboardDaemon = func() yozakura.Caller { return rc2 }
	// index 2 appends to us,ru (out of range on the one-layout defaults)
	code, _, errS = run(t, cfg, "set", "keyboard.layouts[2]", `{"layout":"de","variant":""}`)
	assert.Equal(t, 0, code, errS)
	_, got, _ = run(t, cfg, "get", "keyboard.layouts", "--json")
	assert.Contains(t, got, `"layout": "ru"`)
	assert.Contains(t, got, `"layout": "de"`)
}
