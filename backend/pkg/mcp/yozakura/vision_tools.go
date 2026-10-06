package yozakura

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strconv"

	"yozakura/backend/pkg/mcp"
)

// maxLookBytes caps the image sent to the model.
const maxLookBytes = 3 << 20

func visionTools(d Deps) []mcp.ToolDef {
	return []mcp.ToolDef{
		define("screen_look", "Look at the screen",
			`Take a screenshot and return it as an image you can see (needs a vision-capable model): use it to answer questions about what is on screen ("what does this error say", "which window is that"). "target": screen (all outputs, or "output" e.g. "DP-1"), window (the focused window only). "scale" shrinks it (0.25-1, default 0.5) to save tokens; use 1 to read small text. Nothing is saved to disk.`,
			`{"type":"object","properties":{"target":{"type":"string","enum":["screen","window"],"default":"screen"},"output":{"type":"string"},"scale":{"type":"number","minimum":0.25,"maximum":1,"default":0.5}},"additionalProperties":false}`,
			toolOpts{readOnly: true}, d.screenLook),
	}
}

func (d Deps) screenLook(ctx context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct {
		Target, Output string
		Scale          float64
	}
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	if a.Scale <= 0 {
		a.Scale = 0.5
	}
	a.Scale = max(0.25, min(1, a.Scale))
	dir := d.StateDir
	if dir == "" {
		dir = os.TempDir()
	}
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return nil, err
	}
	path := filepath.Join(dir, fmt.Sprintf("screen-look-%d.jpg", d.now().UnixNano()))
	defer os.Remove(path)
	grim := []string{"-t", "jpeg", "-q", "75", "-s", strconv.FormatFloat(a.Scale, 'f', 2, 64)}
	what := "screen"
	switch a.Target {
	case "", "screen":
		if a.Output != "" {
			grim = append(grim, "-o", a.Output)
			what = a.Output
		}
	case "window":
		w, err := d.resolveWindow(ctx, "", "", "")
		if err != nil {
			return nil, fmt.Errorf("no focused window: %v", err)
		}
		grim = append(grim, "-g", fmt.Sprintf("%d,%d %dx%d", w.X, w.Y, w.Width, w.Height))
		what = "window " + w.App + " — " + w.Title
	default:
		return nil, fmt.Errorf("target must be screen or window")
	}
	if _, err := d.runText(ctx, nil, "grim", append(grim, path)...); err != nil {
		return nil, err
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("screenshot failed: %v", err)
	}
	if len(data) > maxLookBytes {
		return nil, fmt.Errorf("screenshot too large (%d KB); use a smaller scale", len(data)>>10)
	}
	return &mcp.CallToolResult{Content: []mcp.Content{
		{Type: "text", Text: fmt.Sprintf("Screenshot of the %s (scale %.2f).", what, a.Scale)},
		{Type: "image", Data: base64.StdEncoding.EncodeToString(data), MimeType: "image/jpeg"},
	}}, nil
}
