//go:build ignore

// Command termpreview renders every prompt preset like the `term.preview`
// IPC call (exact when the engine is installed), for
// tools/render/terminal_render.py. Run from backend/:
//
//	go run ../tools/render/termpreview.go <colors.json> <presetsDir> <engine> [missing]
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/termlook"
)

type sp struct {
	Text      string `json:"text"`
	FG        string `json:"fg,omitempty"`
	BG        string `json:"bg,omitempty"`
	Bold      bool   `json:"bold,omitempty"`
	Italic    bool   `json:"italic,omitempty"`
	Underline bool   `json:"underline,omitempty"`
}

func conv(in []termlook.Span) []sp {
	out := []sp{}
	for _, s := range in {
		out = append(out, sp{s.Text, s.FG, s.BG, s.Bold, s.Italic, s.Underline})
	}
	return out
}

// main prints {"_presets": [...], "<id>": preview} as JSON; "missing"
// hides the engines (approximate previews).
func main() {
	home, _ := os.UserHomeDir()
	missing := len(os.Args) > 4
	tmp, _ := os.MkdirTemp("", "dump")
	defer os.RemoveAll(tmp)
	env := termlook.Env{Home: home, ConfigHome: filepath.Join(tmp, "cfg"), CacheHome: filepath.Join(tmp, "cache"), AppID: brand.AppID,
		LookPath: func(b string) (string, bool) {
			if missing && b != "git" {
				return "", false
			}
			p, err := exec.LookPath(b)
			return p, err == nil
		}}
	data, err := os.ReadFile(os.Args[1])
	if err != nil {
		panic(err)
	}
	pal, err := termlook.PaletteFromColorsJSON(data)
	if err != nil {
		panic(err)
	}
	ps, err := termlook.LoadPresets(os.Args[2])
	if err != nil {
		panic(err)
	}
	out := map[string]any{}
	var list []map[string]any
	for _, p := range ps {
		list = append(list, map[string]any{"id": p.ID, "name": p.Name, "description": p.Description, "nerdFont": p.NerdFont, "lines": p.Lines})
		cfg := termlook.Config{Engine: os.Args[3], Prompt: p.ID, Greeting: "none"}
		r, err := termlook.Preview(context.Background(), cfg, p, pal, env, 90)
		if err != nil {
			panic(err)
		}
		left := [][]sp{}
		for _, l := range r.Left {
			left = append(left, conv(l))
		}
		out[p.ID] = map[string]any{"left": left, "right": conv(r.Right), "exact": r.Exact, "engine": r.Engine, "reason": r.Reason}
	}
	out["_presets"] = list
	b, _ := json.Marshal(out)
	fmt.Println(string(b))
}
