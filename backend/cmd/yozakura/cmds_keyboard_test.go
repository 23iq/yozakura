package main

import (
	"bytes"
	"testing"
	"yozakura/backend/pkg/catalog"

	"github.com/stretchr/testify/assert"
)

func keyboardTestEnv(t *testing.T) (keyboardEnv, *recCaller) {
	sandbox(t)
	rc := &recCaller{results: map[string]string{
		"keyboard.catalog": `{"layouts":[{"name":"us","variants":[{"name":"intl"}]},{"name":"ru","variants":[]}]}`,
		"keyboard.active":  `{"name":"English (US)","index":0,"code":"us","short":"EN"}`,
		"keyboard.next":    `{"ok":true}`,
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
