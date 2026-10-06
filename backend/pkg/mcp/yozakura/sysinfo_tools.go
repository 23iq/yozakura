package yozakura

import (
	"context"
	"encoding/json"
	"math"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"

	"yozakura/backend/pkg/mcp"
)

// Read-only system information: hardware load (the daemon's
// systemmonitor), battery (/sys), disks, network (the network service)
// and Bluetooth (bluetoothctl).

func sysinfoTools(d Deps) []mcp.ToolDef {
	return []mcp.ToolDef{
		define("system_info", "System info",
			`Hardware status right now: battery (percent, charging state, time left estimate), CPU (model, load %, temperature °C), RAM (used/total GiB, %), GPUs (load, temperature), disks (/ and home: used/free/total GiB), load average and uptime. Use it for "how much battery", "is my CPU hot", "disk space" questions.`,
			noArgs, toolOpts{readOnly: true}, d.systemInfo),
		define("network_status", "Network status",
			`Network connection status: wired/Wi-Fi connected, Wi-Fi radio on/off, current network name and signal, internet connectivity; "networks": true also lists nearby Wi-Fi networks (ssid, signal, security, known = has a saved profile that wifi_connect can use).`,
			`{"type":"object","properties":{"networks":{"type":"boolean","default":false}},"additionalProperties":false}`,
			toolOpts{readOnly: true}, d.networkStatus),
		define("bluetooth_status", "Bluetooth status",
			`Bluetooth adapter state (powered) and the paired devices with their MAC address and whether each is connected. Use the name or address with bluetooth_connect / bluetooth_disconnect.`,
			noArgs, toolOpts{readOnly: true}, d.bluetoothStatus),
	}
}

func (d Deps) sysPath(parts ...string) string {
	root := d.SysRoot
	if root == "" {
		root = "/"
	}
	return filepath.Join(append([]string{root}, parts...)...)
}

func readTrim(path string) string {
	data, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(data))
}

func round1(v float64) float64 { return math.Round(v*10) / 10 }

// batteries reads /sys/class/power_supply/*/ of type Battery.
func (d Deps) batteries() []map[string]any {
	base := d.sysPath("sys", "class", "power_supply")
	entries, _ := os.ReadDir(base)
	out := []map[string]any{}
	for _, e := range entries {
		dir := filepath.Join(base, e.Name())
		if readTrim(filepath.Join(dir, "type")) != "Battery" || readTrim(filepath.Join(dir, "scope")) == "Device" {
			continue
		}
		b := map[string]any{"name": e.Name(), "status": readTrim(filepath.Join(dir, "status"))}
		if v, err := strconv.Atoi(readTrim(filepath.Join(dir, "capacity"))); err == nil {
			b["percent"] = v
		}
		// energy (µWh) / power (µW), or charge (µAh) / current (µA).
		now, rate := num(dir, "energy_now"), num(dir, "power_now")
		full := num(dir, "energy_full")
		if now == 0 {
			now, rate, full = num(dir, "charge_now"), num(dir, "current_now"), num(dir, "charge_full")
		}
		if rate > 0 {
			hours := 0.0
			switch b["status"] {
			case "Discharging":
				hours = now / rate
			case "Charging":
				hours = (full - now) / rate
			}
			if hours > 0 && hours < 48 {
				b["hoursLeft"] = round1(hours)
			}
		}
		out = append(out, b)
	}
	return out
}

func num(dir, name string) float64 {
	v, _ := strconv.ParseFloat(readTrim(filepath.Join(dir, name)), 64)
	return v
}

func diskInfo(path string) map[string]any {
	var st syscall.Statfs_t
	if err := syscall.Statfs(path, &st); err != nil {
		return nil
	}
	gib := func(blocks uint64) float64 { return round1(float64(blocks) * float64(st.Bsize) / (1 << 30)) }
	total, free := gib(st.Blocks), gib(st.Bavail)
	return map[string]any{"path": path, "totalGiB": total, "freeGiB": free, "usedGiB": round1(total - free)}
}

func (d Deps) systemInfo(_ context.Context, _ json.RawMessage) (*mcp.CallToolResult, error) {
	out := map[string]any{"battery": d.batteries()}
	if raw, err := d.call("systemmonitor.getState", nil); err == nil {
		var s struct {
			CPU struct {
				Usage float64
				Temp  int
			}
			RAM struct {
				Usage            float64
				Total, Available int64
			}
			GPU struct {
				Detected bool
				Usages   []float64
				Temps    []int
			}
		}
		if json.Unmarshal(raw, &s) == nil {
			out["cpu"] = map[string]any{"loadPercent": round1(s.CPU.Usage), "tempC": s.CPU.Temp}
			kib := func(v int64) float64 { return round1(float64(v) / (1 << 20)) }
			out["ram"] = map[string]any{"usedPercent": round1(s.RAM.Usage), "totalGiB": kib(s.RAM.Total),
				"usedGiB": kib(s.RAM.Total - s.RAM.Available)}
			if s.GPU.Detected {
				out["gpu"] = map[string]any{"loadPercent": s.GPU.Usages, "tempC": s.GPU.Temps}
			}
		}
	} else {
		out["monitorError"] = err.Error()
	}
	if raw, err := d.call("systemmonitor.getStatic", nil); err == nil {
		var st struct {
			CPUModel string   `json:"cpu_model"`
			GPUNames []string `json:"gpu_names"`
		}
		if json.Unmarshal(raw, &st) == nil {
			if cpu, ok := out["cpu"].(map[string]any); ok {
				cpu["model"] = st.CPUModel
			}
			if gpu, ok := out["gpu"].(map[string]any); ok {
				gpu["names"] = st.GPUNames
			}
		}
	}
	disks := []map[string]any{}
	seen := map[string]bool{}
	home, _ := os.UserHomeDir()
	for _, p := range []string{d.sysPath(), home} {
		if p == "" || seen[p] {
			continue
		}
		seen[p] = true
		if di := diskInfo(p); di != nil {
			disks = append(disks, di)
		}
	}
	out["disks"] = disks
	if f := strings.Fields(readTrim(d.sysPath("proc", "loadavg"))); len(f) >= 3 {
		out["loadAverage"] = f[:3]
	}
	if f := strings.Fields(readTrim(d.sysPath("proc", "uptime"))); len(f) > 0 {
		if secs, err := strconv.ParseFloat(f[0], 64); err == nil {
			out["uptimeHours"] = round1(secs / 3600)
		}
	}
	return mcp.JSONResult(out), nil
}

// knownWifi lists the saved Wi-Fi profiles (nmcli connection names).
func (d Deps) knownWifi(ctx context.Context) map[string]bool {
	known := map[string]bool{}
	out, err := d.runText(ctx, nil, "nmcli", "-t", "-f", "NAME,TYPE", "connection", "show")
	if err != nil {
		return known
	}
	for _, line := range strings.Split(out, "\n") {
		i := strings.LastIndex(line, ":")
		if i > 0 && line[i+1:] == "802-11-wireless" {
			known[strings.ReplaceAll(line[:i], `\:`, ":")] = true
		}
	}
	return known
}

func (d Deps) networkStatus(ctx context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ Networks bool }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	raw, err := d.call("network.status", nil)
	if err != nil {
		return nil, err
	}
	var st map[string]any
	if err := json.Unmarshal(raw, &st); err != nil {
		return nil, err
	}
	out := map[string]any{"status": st}
	if a.Networks {
		known := d.knownWifi(ctx)
		raw, err := d.call("network.networks", nil)
		if err == nil {
			var nets []map[string]any
			_ = json.Unmarshal(raw, &nets)
			for _, n := range nets {
				ssid, _ := n["ssid"].(string)
				n["known"] = known[ssid]
				delete(n, "bssid")
			}
			if nets == nil {
				nets = []map[string]any{}
			}
			out["networks"] = nets
		}
	}
	return mcp.JSONResult(out), nil
}

// BTDevice is one paired Bluetooth device.
type BTDevice struct {
	Address   string `json:"address"`
	Name      string `json:"name"`
	Connected bool   `json:"connected"`
}

// ParseBTDevices decodes `bluetoothctl devices [Filter]` ("Device MAC Name").
func ParseBTDevices(out string) []BTDevice {
	devs := []BTDevice{}
	for _, line := range strings.Split(out, "\n") {
		f := strings.SplitN(strings.TrimSpace(line), " ", 3)
		if len(f) < 2 || f[0] != "Device" {
			continue
		}
		dev := BTDevice{Address: f[1], Name: f[1]}
		if len(f) == 3 {
			dev.Name = f[2]
		}
		devs = append(devs, dev)
	}
	return devs
}

func (d Deps) btDevices(ctx context.Context) ([]BTDevice, error) {
	out, err := d.runText(ctx, nil, "bluetoothctl", "devices", "Paired")
	if err != nil {
		return nil, err
	}
	devs := ParseBTDevices(out)
	conn, _ := d.runText(ctx, nil, "bluetoothctl", "devices", "Connected")
	on := map[string]bool{}
	for _, c := range ParseBTDevices(conn) {
		on[c.Address] = true
	}
	for i := range devs {
		devs[i].Connected = on[devs[i].Address]
	}
	return devs, nil
}

func (d Deps) bluetoothStatus(ctx context.Context, _ json.RawMessage) (*mcp.CallToolResult, error) {
	show, err := d.runText(ctx, nil, "bluetoothctl", "show")
	if err != nil {
		return nil, err
	}
	powered := strings.Contains(show, "Powered: yes")
	devs, err := d.btDevices(ctx)
	if err != nil {
		return nil, err
	}
	return mcp.JSONResult(map[string]any{"available": strings.Contains(show, "Controller"), "powered": powered, "devices": devs}), nil
}
