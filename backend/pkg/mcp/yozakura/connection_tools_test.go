package yozakura

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestBluetoothConnectDisconnect(t *testing.T) {
	d, r, _ := newDeps(t)
	r.out["bluetoothctl show"] = "Controller X\n\tPowered: no\n"
	r.out["bluetoothctl devices Paired"] = "Device AA:BB Sony WH-1000XM4\nDevice CC:DD MX Master\n"
	r.out["bluetoothctl devices Connected"] = "Device CC:DD MX Master\n"
	r.out["bluetoothctl connect"] = "Connection successful"

	m := structured(t, callTool(t, d, "bluetooth_connect", `{"device":"sony"}`))
	assert.Equal(t, []string{"connect", "AA:BB"}, r.last().Args)
	assert.Equal(t, map[string]any{"tool": "bluetooth_disconnect", "args": map[string]any{"device": "AA:BB"}}, m["undo"])
	powered := false
	for _, c := range r.calls {
		if c.Name == "bluetoothctl" && len(c.Args) == 2 && c.Args[0] == "power" {
			powered = true
		}
	}
	assert.True(t, powered, "powers the adapter on first")

	m = structured(t, callTool(t, d, "bluetooth_connect", `{"device":"mx master"}`))
	assert.Equal(t, "already connected", m["note"])

	m = structured(t, callTool(t, d, "bluetooth_disconnect", `{"device":"CC:DD"}`))
	assert.Equal(t, []string{"disconnect", "CC:DD"}, r.last().Args)
	assert.Equal(t, "bluetooth_connect", m["undo"].(map[string]any)["tool"])

	res := callTool(t, d, "bluetooth_connect", `{"device":"car"}`)
	assert.True(t, res.IsError)
	assert.Contains(t, res.Content[0].Text, "MX Master")

	r.out["bluetoothctl connect"] = "Failed to connect: org.bluez.Error"
	assert.True(t, callTool(t, d, "bluetooth_connect", `{"device":"sony"}`).IsError)
}

func TestWifiTools(t *testing.T) {
	d, r, ipc := newDeps(t)
	ipc.result["network.status"] = `{"wifi":true,"wifi_enabled":true,"network_name":"home"}`
	r.out["nmcli -t -f NAME,TYPE connection show"] = "home:802-11-wireless\nwork:802-11-wireless\n"

	res := callTool(t, d, "wifi_connect", `{"ssid":"cafe"}`)
	assert.True(t, res.IsError)
	assert.Contains(t, res.Content[0].Text, "no saved profile")

	m := structured(t, callTool(t, d, "wifi_connect", `{"ssid":"work"}`))
	assert.Equal(t, []string{"connection", "up", "id", "work"}, r.last().Args)
	assert.Equal(t, map[string]any{"tool": "wifi_connect", "args": map[string]any{"ssid": "home"}}, m["undo"])

	m = structured(t, callTool(t, d, "wifi_toggle", `{}`))
	assert.Equal(t, false, m["wifi"])
	last := ipc.calls[len(ipc.calls)-1]
	assert.Equal(t, "network.enable", last.Method)
	assert.Equal(t, map[string]any{"enabled": false}, last.Params)
	assert.Equal(t, map[string]any{"tool": "wifi_toggle", "args": map[string]any{"enabled": true}}, m["undo"])

	m = structured(t, callTool(t, d, "wifi_toggle", `{"enabled":true}`))
	assert.Nil(t, m["undo"], "no change, nothing to undo")
}

func TestAudioOutputSet(t *testing.T) {
	d, r, _ := newDeps(t)
	r.out["pactl -f json list sinks"] = `[{"index":34,"name":"alsa_output.hdmi","description":"HDMI Monitor"},{"index":40,"name":"bluez_output.sony","description":"Sony Headphones"}]`
	r.out["pactl get-default-sink"] = "alsa_output.hdmi\n"
	m := structured(t, callTool(t, d, "audio_output_set", `{}`))
	outs := m["outputs"].([]any)
	assert.Equal(t, true, outs[0].(map[string]any)["default"])

	m = structured(t, callTool(t, d, "audio_output_set", `{"output":"headphones"}`))
	assert.Equal(t, []string{"set-default-sink", "bluez_output.sony"}, r.last().Args)
	assert.Equal(t, map[string]any{"tool": "audio_output_set", "args": map[string]any{"output": "alsa_output.hdmi"}}, m["undo"])

	structured(t, callTool(t, d, "audio_output_set", `{"output":"40"}`))
	assert.Equal(t, "bluez_output.sony", r.last().Args[1])
	assert.True(t, callTool(t, d, "audio_output_set", `{"output":"toaster"}`).IsError)
}
