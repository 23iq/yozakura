package yozakura

import (
	"context"
	"encoding/json"
	"fmt"
	"regexp"
	"strconv"
	"strings"

	"yozakura/backend/pkg/mcp"
)

func (d Deps) mediaControl(ctx context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ Action, Player string }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	switch a.Action {
	case "play", "pause", "play-pause", "next", "previous", "stop":
	default:
		return nil, fmt.Errorf("action must be play, pause, play-pause, next, previous or stop")
	}
	cmd := []string{}
	if a.Player != "" {
		cmd = append(cmd, "--player", a.Player)
	}
	cmd = append(cmd, a.Action)
	if _, err := d.runText(ctx, nil, "playerctl", cmd...); err != nil {
		return nil, err
	}
	return mcp.TextResult("media " + a.Action), nil
}

// MediaPlayer is one row of media_status.
type MediaPlayer struct {
	Player string `json:"player"`
	Status string `json:"status"`
	Artist string `json:"artist"`
	Title  string `json:"title"`
	Album  string `json:"album"`
}

// ParsePlayerctl decodes the tab-separated format used by media_status.
func ParsePlayerctl(out string) []MediaPlayer {
	players := []MediaPlayer{}
	for _, line := range strings.Split(out, "\n") {
		if strings.TrimSpace(line) == "" {
			continue
		}
		f := strings.Split(line, "\t")
		for len(f) < 5 {
			f = append(f, "")
		}
		players = append(players, MediaPlayer{Player: f[0], Status: f[1], Artist: f[2], Title: f[3], Album: f[4]})
	}
	return players
}

func (d Deps) mediaStatus(ctx context.Context, _ json.RawMessage) (*mcp.CallToolResult, error) {
	out, err := d.runText(ctx, nil, "playerctl", "-a", "metadata", "--format", "{{playerName}}\t{{status}}\t{{artist}}\t{{title}}\t{{album}}")
	if err != nil && out == "" {
		if strings.Contains(err.Error(), "No players found") {
			return mcp.JSONResult(map[string]any{"players": []any{}}), nil
		}
		return nil, err
	}
	return mcp.JSONResult(map[string]any{"players": ParsePlayerctl(out)}), nil
}

var volRe = regexp.MustCompile(`Volume:\s*([0-9.]+)(\s*\[MUTED\])?`)

// ParseWpctlVolume decodes `wpctl get-volume` output.
func ParseWpctlVolume(out string) (percent int, muted bool, err error) {
	m := volRe.FindStringSubmatch(out)
	if m == nil {
		return 0, false, fmt.Errorf("unexpected wpctl output: %q", out)
	}
	f, _ := strconv.ParseFloat(m[1], 64)
	return int(f*100 + 0.5), m[2] != "", nil
}

func target(source bool) string {
	if source {
		return "@DEFAULT_AUDIO_SOURCE@"
	}
	return "@DEFAULT_AUDIO_SINK@"
}

func (d Deps) volumeGet(ctx context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ Source bool }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	out, err := d.runText(ctx, nil, "wpctl", "get-volume", target(a.Source))
	if err != nil {
		return nil, err
	}
	p, muted, err := ParseWpctlVolume(out)
	if err != nil {
		return nil, err
	}
	return mcp.JSONResult(map[string]any{"percent": p, "muted": muted}), nil
}

func (d Deps) volumeSet(ctx context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct {
		Percent *float64
		Delta   *float64
		Mute    json.RawMessage
		Source  bool
	}
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	t := target(a.Source)
	did := false
	if a.Percent != nil {
		v := clamp(*a.Percent, 0, 150)
		if _, err := d.runText(ctx, nil, "wpctl", "set-volume", "-l", "1.5", t, fmt.Sprintf("%.2f", v/100)); err != nil {
			return nil, err
		}
		did = true
	} else if a.Delta != nil {
		v := clamp(*a.Delta, -100, 100)
		sign := "+"
		if v < 0 {
			sign, v = "-", -v
		}
		if _, err := d.runText(ctx, nil, "wpctl", "set-volume", "-l", "1.5", t, fmt.Sprintf("%.0f%%%s", v, sign)); err != nil {
			return nil, err
		}
		did = true
	}
	if len(a.Mute) > 0 && string(a.Mute) != "null" {
		arg := ""
		switch strings.Trim(string(a.Mute), `"`) {
		case "true", "1":
			arg = "1"
		case "false", "0":
			arg = "0"
		case "toggle":
			arg = "toggle"
		default:
			return nil, fmt.Errorf("mute must be true, false or \"toggle\"")
		}
		if _, err := d.runText(ctx, nil, "wpctl", "set-mute", t, arg); err != nil {
			return nil, err
		}
		did = true
	}
	if !did {
		return nil, fmt.Errorf("give percent, delta or mute")
	}
	return d.volumeGet(ctx, json.RawMessage(fmt.Sprintf(`{"source":%v}`, a.Source)))
}

func clamp(v, lo, hi float64) float64 {
	if v < lo {
		return lo
	}
	if v > hi {
		return hi
	}
	return v
}
