package yozakura

import (
	"os"
	"path/filepath"
	"testing"

	"yozakura/backend/pkg/brand"

	"github.com/stretchr/testify/assert"
)

func appsFixture(t *testing.T, d *Deps) {
	dir := t.TempDir()
	d.AppDirs = []string{dir}
	write := func(id, body string) {
		assert.NoError(t, os.WriteFile(filepath.Join(dir, id+".desktop"), []byte("[Desktop Entry]\n"+body), 0o644))
	}
	write("firefox", "Name=Firefox\nExec=firefox %u\nIcon=firefox\n")
	write("org.telegram.desktop", "Name=Telegram Desktop\nExec=telegram-desktop -- %u\nStartupWMClass=TelegramDesktop\n")
	write("org.gnome.Nautilus", "Name=Files\nExec=nautilus --new-window %U\n")
}

func TestAppsFind(t *testing.T) {
	d, _, _ := newDeps(t)
	appsFixture(t, &d)
	m := structured(t, callTool(t, d, "apps_find", `{"query":"tele"}`))
	apps := m["apps"].([]any)
	assert.Equal(t, "org.telegram.desktop", apps[0].(map[string]any)["id"])
	assert.Equal(t, "telegram-desktop --", apps[0].(map[string]any)["command"])
	m = structured(t, callTool(t, d, "apps_find", `{"query":"files"}`))
	assert.Equal(t, "org.gnome.Nautilus", m["apps"].([]any)[0].(map[string]any)["id"])
	m = structured(t, callTool(t, d, "apps_find", `{"query":"zzz"}`))
	assert.Len(t, m["apps"], 0)
}

func TestAppLaunch(t *testing.T) {
	d, r, _ := newDeps(t)
	appsFixture(t, &d)
	m := structured(t, callTool(t, d, "app_launch", `{"app":"Telegram"}`))
	assert.Equal(t, "org.telegram.desktop", m["launched"])
	assert.Equal(t, []string{"launch", "org.telegram.desktop"}, r.last().Args)

	assert.True(t, callTool(t, d, "app_launch", `{"app":"firefox","workspace":3}`).IsError, "needs the daemon")
	r.bins[brand.Daemon] = true
	structured(t, callTool(t, d, "app_launch", `{"app":"firefox","workspace":3}`))
	assert.Equal(t, call{brand.Daemon, []string{"system", "execute-in", "3 silent", "firefox"}, ""}, r.last())
	structured(t, callTool(t, d, "app_launch", `{"app":"firefox","workspace":"special:web"}`))
	assert.Equal(t, "special:web", r.last().Args[2])

	assert.True(t, callTool(t, d, "app_launch", `{"app":"nothing-like-it"}`).IsError)
}

func TestAppClose(t *testing.T) {
	d, r, _ := newDeps(t)
	appsFixture(t, &d)
	r.bins[brand.Daemon] = true
	r.out[brand.Daemon+" window list"] = `[{"id":"0x1","app_id":"firefox","title":"Docs","is_focused":true},{"id":"0x2","app_id":"TelegramDesktop","title":"Chat"}]`
	assert.True(t, callTool(t, d, "app_close", `{}`).IsError, "never closes without a target")
	m := structured(t, callTool(t, d, "app_close", `{"app":"telegram"}`))
	assert.Equal(t, "0x2", m["closed"])
	assert.Equal(t, []string{"window", "close", "0x2"}, r.last().Args)
	assert.Equal(t, map[string]any{"tool": "app_launch", "args": map[string]any{"app": "org.telegram.desktop"}}, m["undo"])
}
