package yozakura

import (
	"encoding/base64"
	"fmt"
	"os"
	"path/filepath"
	"testing"

	"yozakura/backend/pkg/brand"

	"github.com/stretchr/testify/assert"
)

func TestBrightnessTools(t *testing.T) {
	d, r, _ := newDeps(t)
	assert.True(t, callTool(t, d, "brightness_get", `{}`).IsError, "needs the daemon")
	r.bins[brand.Daemon] = true
	r.out[brand.Daemon+" brightness list"] = `[{"name":"backlight-amdgpu_bl1","kind":"brightnessctl","brightness":0.4},{"name":"ddc-5","kind":"ddcutil","bus":"5"}]`
	m := structured(t, callTool(t, d, "brightness_get", `{}`))
	ds := m["displays"].([]any)
	assert.Equal(t, float64(40), ds[0].(map[string]any)["percent"])
	assert.Nil(t, ds[1].(map[string]any)["percent"])

	m = structured(t, callTool(t, d, "brightness_set", `{"delta":-15,"monitor":"backlight-amdgpu_bl1"}`))
	assert.Equal(t, []string{"brightness", "set", "backlight-amdgpu_bl1", "0.25"}, r.last().Args)
	assert.Equal(t, map[string]any{"tool": "brightness_set", "args": map[string]any{"percent": float64(40), "monitor": "backlight-amdgpu_bl1"}}, m["undo"])

	m = structured(t, callTool(t, d, "brightness_set", `{"percent":100}`))
	assert.Equal(t, "1.00", r.last().Args[3])
	assert.NotNil(t, m["undo"], "only the known level is restored")

	assert.True(t, callTool(t, d, "brightness_set", `{}`).IsError)
	assert.True(t, callTool(t, d, "brightness_set", `{"percent":50,"monitor":"nope"}`).IsError)

	r.out[brand.Daemon+" brightness set"] = "Error: no monitors available"
	assert.True(t, callTool(t, d, "brightness_set", `{"percent":50}`).IsError)
}

func TestNightlightAndCaffeine(t *testing.T) {
	d, _, ipc := newDeps(t)
	ipc.result["nightlight.get"] = `{"active":false,"temp":4500}`
	ipc.result["nightlight.set"] = `{"active":true,"temp":3500}`
	m := structured(t, callTool(t, d, "nightlight_set", `{"temperature":3500}`))
	last := ipc.calls[len(ipc.calls)-1]
	assert.Equal(t, map[string]any{"enabled": true, "temp": 3500}, last.Params)
	assert.Equal(t, map[string]any{"tool": "nightlight_set", "args": map[string]any{"enabled": false, "temperature": float64(4500)}}, m["undo"])

	ipc.result["caffeine.get"] = `{"inhibit":false}`
	m = structured(t, callTool(t, d, "caffeine_set", `{}`))
	assert.Equal(t, map[string]any{"inhibit": true}, ipc.calls[len(ipc.calls)-1].Params)
	assert.Equal(t, map[string]any{"tool": "caffeine_set", "args": map[string]any{"enabled": false}}, m["undo"])
	m = structured(t, callTool(t, d, "caffeine_set", `{"enabled":false}`))
	assert.Nil(t, m["undo"])
}

func TestFocusTools(t *testing.T) {
	d, _, ipc := newDeps(t)
	m := structured(t, callTool(t, d, "focus_start", `{"minutes":25}`))
	assert.Equal(t, ipcCall{"ui.run", map[string]any{"command": "focus:25"}}, ipc.calls[0])
	assert.Equal(t, "focus_stop", m["undo"].(map[string]any)["tool"])
	structured(t, callTool(t, d, "focus_start", `{}`))
	assert.Equal(t, "focus:0", ipc.calls[1].Params.(map[string]any)["command"])
	res := callTool(t, d, "focus_stop", `{}`)
	assert.False(t, res.IsError)
	assert.Equal(t, "focus-stop", ipc.calls[2].Params.(map[string]any)["command"])

	ipc.result["focus.get"] = `{"active":true,"known":true,"startedAt":1791280000000,"endsAt":1791281500000,"leftMs":600000,"minutesLeft":10,"timerId":"t9"}`
	m = structured(t, callTool(t, d, "focus_status", `{}`))
	assert.Equal(t, true, m["active"])
	assert.Equal(t, float64(10), m["minutesLeft"])
	assert.Equal(t, msToISO(1791281500000), m["endsAt"])
	assert.Nil(t, m["note"])
	ipc.result["focus.get"] = `{"active":false,"known":false}`
	m = structured(t, callTool(t, d, "focus_status", `{}`))
	assert.Equal(t, false, m["active"])
	assert.NotNil(t, m["note"])
	assert.Contains(t, ReadOnlyToolNames(), "focus_status")
}

func TestScreenLookReturnsImage(t *testing.T) {
	d, r, _ := newDeps(t)
	// The fake grim writes nothing: put the expected file in place.
	path := filepath.Join(d.StateDir, fmt.Sprintf("screen-look-%d.jpg", d.now().UnixNano()))
	assert.NoError(t, os.MkdirAll(d.StateDir, 0o700))
	assert.NoError(t, os.WriteFile(path, []byte("JPEGDATA"), 0o600))
	res := callTool(t, d, "screen_look", `{"scale":2}`)
	assert.False(t, res.IsError)
	assert.Len(t, res.Content, 2)
	assert.Equal(t, "image", res.Content[1].Type)
	assert.Equal(t, "image/jpeg", res.Content[1].MimeType)
	assert.Equal(t, base64.StdEncoding.EncodeToString([]byte("JPEGDATA")), res.Content[1].Data)
	assert.Equal(t, []string{"-t", "jpeg", "-q", "75", "-s", "1.00", path}, r.last().Args)
	_, err := os.Stat(path)
	assert.True(t, os.IsNotExist(err), "the capture is not kept")

	assert.True(t, callTool(t, d, "screen_look", `{}`).IsError, "missing capture is an error")
}
