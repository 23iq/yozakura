//go:build ignore

// Command fetchpreview renders the greeting of every look x logo like the
// `term.fetch.preview` IPC call (real fastfetch when installed, else the
// bundled sample), for tools/render/terminal_render.py. Run from backend/:
//
//	go run ../tools/render/fetchpreview.go <colors.json> <assets/terminal/fastfetch>
//
// Prints {"_presets": [...], "<preset>|<logo>|": preview}.
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

func main() {
	if len(os.Args) != 3 {
		fmt.Fprintln(os.Stderr, "usage: fetchpreview <colors.json> <assets/terminal/fastfetch>")
		os.Exit(2)
	}
	data, err := os.ReadFile(os.Args[1])
	check(err)
	pal, err := termlook.PaletteFromColorsJSON(data)
	check(err)
	dir := os.Args[2]
	ps, err := termlook.LoadFetchPresets(dir)
	check(err)
	tmp, err := os.MkdirTemp("", "fetchpreview-")
	check(err)
	defer os.RemoveAll(tmp)
	env := termlook.Env{Home: tmp, ConfigHome: filepath.Join(tmp, "cfg"), AppID: brand.AppID,
		LookPath: func(b string) (string, bool) {
			p, err := exec.LookPath(b)
			return p, err == nil
		}}
	out := map[string]any{"_presets": ps}
	for _, p := range ps {
		for _, logo := range termlook.FetchLogos {
			if logo == termlook.LogoCustom {
				continue
			}
			cfg := termlook.GreetingConfig{On: true, Preset: p.ID, Logo: logo}
			r, err := termlook.FetchPreview(context.Background(), cfg, ps, pal, dir, env, termlook.ANSI16)
			check(err)
			lines := [][]sp{}
			for _, l := range r.Lines {
				row := []sp{}
				for _, s := range l {
					row = append(row, sp{s.Text, s.FG, s.BG, s.Bold, s.Italic, s.Underline})
				}
				lines = append(lines, row)
			}
			out[p.ID+"|"+logo+"|"] = map[string]any{"lines": lines, "exact": r.Exact, "reason": r.Reason, "imageLogo": r.ImageLogo}
		}
	}
	b, err := json.Marshal(out)
	check(err)
	fmt.Println(string(b))
}

func check(err error) {
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
