package yozakura

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
)

func sysFixture(t *testing.T, d *Deps) {
	root := t.TempDir()
	d.SysRoot = root
	bat := filepath.Join(root, "sys", "class", "power_supply", "BAT0")
	mouse := filepath.Join(root, "sys", "class", "power_supply", "hid-mouse")
	for dir, files := range map[string]map[string]string{
		bat:   {"type": "Battery", "status": "Discharging", "capacity": "64", "energy_now": "30000000", "power_now": "10000000"},
		mouse: {"type": "Battery", "scope": "Device", "capacity": "90"},
	} {
		assert.NoError(t, os.MkdirAll(dir, 0o755))
		for name, v := range files {
			assert.NoError(t, os.WriteFile(filepath.Join(dir, name), []byte(v+"\n"), 0o644))
		}
	}
	assert.NoError(t, os.MkdirAll(filepath.Join(root, "proc"), 0o755))
	assert.NoError(t, os.WriteFile(filepath.Join(root, "proc", "loadavg"), []byte("0.50 0.40 0.30 1/200 999\n"), 0o644))
	assert.NoError(t, os.WriteFile(filepath.Join(root, "proc", "uptime"), []byte("7200.5 100.0\n"), 0o644))
}

func TestSystemInfo(t *testing.T) {
	d, _, ipc := newDeps(t)
	sysFixture(t, &d)
	ipc.result["systemmonitor.getState"] = `{"cpu":{"usage":12.34,"temp":55},"ram":{"usage":50,"total":16777216,"available":8388608},"gpu":{"detected":true,"usages":[3],"temps":[40]}}`
	ipc.result["systemmonitor.getStatic"] = `{"cpu_model":"Ryzen","gpu_names":["AMD GPU 0"]}`
	m := structured(t, callTool(t, d, "system_info", `{}`))
	bats := m["battery"].([]any)
	assert.Len(t, bats, 1, "device batteries (mice) are left out")
	assert.Equal(t, float64(64), bats[0].(map[string]any)["percent"])
	assert.Equal(t, 3.0, bats[0].(map[string]any)["hoursLeft"])
	cpu := m["cpu"].(map[string]any)
	assert.Equal(t, 12.3, cpu["loadPercent"])
	assert.Equal(t, "Ryzen", cpu["model"])
	assert.Equal(t, 16.0, m["ram"].(map[string]any)["totalGiB"])
	assert.Equal(t, 8.0, m["ram"].(map[string]any)["usedGiB"])
	assert.Equal(t, []any{"AMD GPU 0"}, m["gpu"].(map[string]any)["names"])
	assert.Equal(t, 2.0, m["uptimeHours"])
	assert.NotEmpty(t, m["disks"])

	ipc.down = true
	m = structured(t, callTool(t, d, "system_info", `{}`))
	assert.Contains(t, m["monitorError"], "no such file")
}

func TestNetworkStatus(t *testing.T) {
	d, r, ipc := newDeps(t)
	ipc.result["network.status"] = `{"wifi":true,"wifi_enabled":true,"network_name":"home","strength":70}`
	ipc.result["network.networks"] = `[{"ssid":"home","strength":70,"bssid":"aa"},{"ssid":"cafe","strength":30}]`
	r.out["nmcli -t -f NAME,TYPE connection show"] = "home:802-11-wireless\nWired:802-3-ethernet\n"
	m := structured(t, callTool(t, d, "network_status", `{}`))
	assert.Equal(t, "home", m["status"].(map[string]any)["network_name"])
	assert.Nil(t, m["networks"])
	m = structured(t, callTool(t, d, "network_status", `{"networks":true}`))
	nets := m["networks"].([]any)
	assert.Equal(t, true, nets[0].(map[string]any)["known"])
	assert.Equal(t, false, nets[1].(map[string]any)["known"])
	assert.Nil(t, nets[0].(map[string]any)["bssid"])
}

func TestBluetoothStatus(t *testing.T) {
	d, r, _ := newDeps(t)
	r.out["bluetoothctl show"] = "Controller D0:57 (public)\n\tPowered: yes\n"
	r.out["bluetoothctl devices Paired"] = "Device AA:BB Sony WH-1000XM4\nDevice CC:DD MX Master\n"
	r.out["bluetoothctl devices Connected"] = "Device CC:DD MX Master\n"
	m := structured(t, callTool(t, d, "bluetooth_status", `{}`))
	assert.Equal(t, true, m["powered"])
	devs := m["devices"].([]any)
	assert.Equal(t, map[string]any{"address": "AA:BB", "name": "Sony WH-1000XM4", "connected": false}, devs[0])
	assert.Equal(t, true, devs[1].(map[string]any)["connected"])
}
