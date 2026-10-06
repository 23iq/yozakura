package yozakura

import (
	"context"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"

	"yozakura/backend/pkg/mcp"
)

// Connection tools: Bluetooth devices, Wi-Fi (saved networks only, no
// passwords pass through the AI) and the default audio output.

func connectionTools(d Deps) []mcp.ToolDef {
	dev := `{"type":"object","properties":{"device":{"type":"string","description":"Paired device name (substring) or MAC address, see bluetooth_status."}},"required":["device"],"additionalProperties":false}`
	return []mcp.ToolDef{
		define("bluetooth_connect", "Connect Bluetooth device",
			`Connect a paired Bluetooth device (headphones, speaker, mouse...) by name or address; turns the adapter on first when it is off.`,
			dev, toolOpts{idempotent: true}, d.bluetoothConnect),
		define("bluetooth_disconnect", "Disconnect Bluetooth device",
			`Disconnect a connected Bluetooth device by name or address (it stays paired).`,
			dev, toolOpts{idempotent: true}, d.bluetoothDisconnect),
		define("wifi_connect", "Connect Wi-Fi",
			`Connect to a Wi-Fi network that has a saved profile (known: true in network_status with networks). New networks that need a password must be joined by the user in the network panel; never ask for a password.`,
			`{"type":"object","properties":{"ssid":{"type":"string"}},"required":["ssid"],"additionalProperties":false}`,
			toolOpts{idempotent: true}, d.wifiConnect),
		define("wifi_toggle", "Wi-Fi on/off",
			`Turn the Wi-Fi radio on or off; omit "enabled" to toggle.`,
			`{"type":"object","properties":{"enabled":{"type":"boolean"}},"additionalProperties":false}`,
			toolOpts{idempotent: true}, d.wifiToggle),
		define("audio_output_set", "Audio output",
			`List audio outputs (sinks) or switch the default one. Without "output" it lists them (name, description, default). With "output" (description substring like "headphones"/"HDMI", the sink name or its index) it makes that the default output; playing streams follow.`,
			`{"type":"object","properties":{"output":{"type":"string"}},"additionalProperties":false}`,
			toolOpts{idempotent: true}, d.audioOutputSet),
	}
}

func (d Deps) findBT(ctx context.Context, ref string) (BTDevice, error) {
	devs, err := d.btDevices(ctx)
	if err != nil {
		return BTDevice{}, err
	}
	low := strings.ToLower(strings.TrimSpace(ref))
	for _, pass := range []func(BTDevice) bool{
		func(b BTDevice) bool { return strings.EqualFold(b.Address, ref) || strings.ToLower(b.Name) == low },
		func(b BTDevice) bool { return low != "" && strings.Contains(strings.ToLower(b.Name), low) },
	} {
		for _, b := range devs {
			if pass(b) {
				return b, nil
			}
		}
	}
	names := []string{}
	for _, b := range devs {
		names = append(names, b.Name)
	}
	return BTDevice{}, fmt.Errorf("no paired device %q (paired: %s)", ref, strings.Join(names, ", "))
}

func (d Deps) bluetoothConnect(ctx context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ Device string }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	b, err := d.findBT(ctx, a.Device)
	if err != nil {
		return nil, err
	}
	if b.Connected {
		return mcp.JSONResult(map[string]any{"device": b.Name, "connected": true, "note": "already connected"}), nil
	}
	if show, _ := d.runText(ctx, nil, "bluetoothctl", "show"); strings.Contains(show, "Powered: no") {
		_, _ = d.runText(ctx, nil, "bluetoothctl", "power", "on")
	}
	out, err := d.runText(ctx, nil, "bluetoothctl", "connect", b.Address)
	if err != nil || strings.Contains(out, "Failed") {
		return nil, fmt.Errorf("could not connect %s: %s", b.Name, strings.TrimSpace(firstNonEmpty(out, errText(err))))
	}
	return mcp.JSONResult(map[string]any{"device": b.Name, "address": b.Address, "connected": true,
		"undo": undo("bluetooth_disconnect", map[string]any{"device": b.Address})}), nil
}

func (d Deps) bluetoothDisconnect(ctx context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ Device string }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	b, err := d.findBT(ctx, a.Device)
	if err != nil {
		return nil, err
	}
	if !b.Connected {
		return mcp.JSONResult(map[string]any{"device": b.Name, "connected": false, "note": "not connected"}), nil
	}
	if _, err := d.runText(ctx, nil, "bluetoothctl", "disconnect", b.Address); err != nil {
		return nil, err
	}
	return mcp.JSONResult(map[string]any{"device": b.Name, "address": b.Address, "connected": false,
		"undo": undo("bluetooth_connect", map[string]any{"device": b.Address})}), nil
}

func firstNonEmpty(a, b string) string {
	if strings.TrimSpace(a) != "" {
		return a
	}
	return b
}

func errText(err error) string {
	if err == nil {
		return ""
	}
	return err.Error()
}

// wifiState reads network.status (radio, current network).
func (d Deps) wifiState() (enabled bool, current string, err error) {
	raw, err := d.call("network.status", nil)
	if err != nil {
		return false, "", err
	}
	var st struct {
		WifiEnabled bool   `json:"wifi_enabled"`
		Wifi        bool   `json:"wifi"`
		NetworkName string `json:"network_name"`
	}
	if err := json.Unmarshal(raw, &st); err != nil {
		return false, "", err
	}
	if st.Wifi {
		current = st.NetworkName
	}
	return st.WifiEnabled, current, nil
}

func (d Deps) wifiConnect(ctx context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ SSID string }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	ssid := strings.TrimSpace(a.SSID)
	known := d.knownWifi(ctx)
	if !known[ssid] {
		return nil, fmt.Errorf("%q has no saved profile; the user has to join it once from the network panel", ssid)
	}
	_, previous, _ := d.wifiState()
	if previous == ssid {
		return mcp.JSONResult(map[string]any{"ssid": ssid, "connected": true, "note": "already connected"}), nil
	}
	if _, err := d.runText(ctx, nil, "nmcli", "connection", "up", "id", ssid); err != nil {
		return nil, err
	}
	out := map[string]any{"ssid": ssid, "connected": true}
	if previous != "" && known[previous] {
		out["undo"] = undo("wifi_connect", map[string]any{"ssid": previous})
	}
	return mcp.JSONResult(out), nil
}

func (d Deps) wifiToggle(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ Enabled *bool }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	was, _, err := d.wifiState()
	if err != nil {
		return nil, err
	}
	want := !was
	if a.Enabled != nil {
		want = *a.Enabled
	}
	if _, err := d.call("network.enable", map[string]any{"enabled": want}); err != nil {
		return nil, err
	}
	out := map[string]any{"wifi": want}
	if want != was {
		out["undo"] = undo("wifi_toggle", map[string]any{"enabled": was})
	}
	return mcp.JSONResult(out), nil
}

// Sink is one audio output.
type Sink struct {
	Index       int    `json:"index"`
	Name        string `json:"name"`
	Description string `json:"description"`
	Default     bool   `json:"default"`
}

func (d Deps) sinks(ctx context.Context) ([]Sink, error) {
	out, err := d.runText(ctx, nil, "pactl", "-f", "json", "list", "sinks")
	if err != nil {
		return nil, err
	}
	var list []Sink
	if err := json.Unmarshal([]byte(out), &list); err != nil {
		return nil, fmt.Errorf("pactl: %v", err)
	}
	def, _ := d.runText(ctx, nil, "pactl", "get-default-sink")
	for i := range list {
		list[i].Default = list[i].Name == strings.TrimSpace(def)
	}
	return list, nil
}

func (d Deps) audioOutputSet(ctx context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ Output string }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	list, err := d.sinks(ctx)
	if err != nil {
		return nil, err
	}
	ref := strings.TrimSpace(a.Output)
	if ref == "" {
		return mcp.JSONResult(map[string]any{"outputs": list}), nil
	}
	low := strings.ToLower(ref)
	pick := -1
	for i, s := range list {
		if s.Name == ref || strconv.Itoa(s.Index) == ref || strings.EqualFold(s.Description, ref) {
			pick = i
			break
		}
	}
	if pick < 0 {
		for i, s := range list {
			if strings.Contains(strings.ToLower(s.Description), low) || strings.Contains(strings.ToLower(s.Name), low) {
				pick = i
				break
			}
		}
	}
	if pick < 0 {
		return nil, fmt.Errorf("no audio output matches %q; call audio_output_set without output to list them", ref)
	}
	previous := ""
	for _, s := range list {
		if s.Default {
			previous = s.Name
		}
	}
	target := list[pick]
	if _, err := d.runText(ctx, nil, "pactl", "set-default-sink", target.Name); err != nil {
		return nil, err
	}
	out := map[string]any{"output": target.Description, "name": target.Name}
	if previous != "" && previous != target.Name {
		out["undo"] = undo("audio_output_set", map[string]any{"output": previous})
	}
	return mcp.JSONResult(out), nil
}
