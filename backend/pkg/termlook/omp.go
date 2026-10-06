package termlook

import (
	"bytes"
	"encoding/json"
	"fmt"
	"strings"
)

const ompSchema = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/schema.json"

type ompConfig struct {
	Schema     string            `json:"$schema"`
	Version    int               `json:"version"`
	FinalSpace bool              `json:"final_space"`
	Palette    map[string]string `json:"palette"`
	Blocks     []ompBlock        `json:"blocks"`
}

type ompBlock struct {
	Type      string       `json:"type"`
	Alignment string       `json:"alignment,omitempty"`
	Newline   bool         `json:"newline,omitempty"`
	Segments  []ompSegment `json:"segments"`
}

type ompSegment struct {
	Type                string         `json:"type"`
	Style               string         `json:"style"`
	PowerlineSymbol     string         `json:"powerline_symbol,omitempty"`
	InvertPowerline     bool           `json:"invert_powerline,omitempty"`
	LeadingDiamond      string         `json:"leading_diamond,omitempty"`
	TrailingDiamond     string         `json:"trailing_diamond,omitempty"`
	Foreground          string         `json:"foreground"`
	Background          string         `json:"background,omitempty"`
	ForegroundTemplates []string       `json:"foreground_templates,omitempty"`
	Template            string         `json:"template"`
	Options             map[string]any `json:"options,omitempty"`
}

// ompKind is how a segment type maps to oh-my-posh: segment type, template
// body, an optional condition that hides it, and segment options.
type ompKind struct {
	typ, body, cond string
	opts            map[string]any
}

var ompKinds = map[string]ompKind{
	"os":         {typ: "os", body: "{{ .Icon }}"},
	"user":       {typ: "session", body: "{{ .UserName }}"},
	"host":       {typ: "session", body: "{{ .HostName }}"},
	"dir":        {typ: "path", body: "{{ .Path }}", opts: map[string]any{"style": "agnoster_short", "max_depth": 3}},
	"git_branch": {typ: "git", body: "{{ .HEAD }}", opts: map[string]any{"branch_icon": ""}},
	"git_status": {typ: "git", cond: "or .Working.Changed .Staging.Changed (gt .Ahead 0) (gt .Behind 0)",
		body: "{{ if .Working.Changed }}{{ .Working.String }}{{ end }}{{ if .Staging.Changed }} {{ .Staging.String }}{{ end }}{{ if gt .Ahead 0 }} ⇡{{ .Ahead }}{{ end }}{{ if gt .Behind 0 }} ⇣{{ .Behind }}{{ end }}",
	},
	"duration": {typ: "executiontime", body: "{{ .FormattedMs }}", opts: map[string]any{"threshold": 2000, "style": "round"}},
	"time":     {typ: "time", body: "{{ .CurrentDate | date \"15:04\" }}"},
	"status":   {typ: "status", cond: "gt .Code 0", body: "{{ .Code }}"},
	"battery":  {typ: "battery", cond: "not .Error", body: "{{ .Icon }}{{ .Percentage }}%"},
}

// RenderOMP renders an oh-my-posh (config version 4) JSON theme for the
// preset. oh-my-posh has no shell-jobs segment, so "jobs" is left out.
func RenderOMP(p Preset, pal Palette) string {
	r := ompRenderer{p: p, sep: SeparatorGlyphs[p.Separator]}
	cfg := ompConfig{Schema: ompSchema, Version: 4, FinalSpace: true, Palette: map[string]string{}}
	for _, role := range Roles {
		cfg.Palette[paletteKey(role)] = pal[role]
	}
	var left []ompSegment
	if p.Frame {
		left = append(left, ompSegment{Type: "text", Style: "plain", Foreground: "p:outline", Template: frameTop + " "})
	}
	left = append(left, r.side(p.Left, true)...)
	char := r.char()
	if p.Lines == 1 {
		left = append(left, char)
	}
	cfg.Blocks = append(cfg.Blocks, ompBlock{Type: "prompt", Alignment: "left", Segments: left})
	if right := r.side(p.Right, false); len(right) > 0 {
		if p.Lines == 1 {
			cfg.Blocks = append(cfg.Blocks, ompBlock{Type: "rprompt", Segments: right})
		} else {
			cfg.Blocks = append(cfg.Blocks, ompBlock{Type: "prompt", Alignment: "right", Segments: right})
		}
	}
	if p.Lines == 2 {
		cfg.Blocks = append(cfg.Blocks, ompBlock{Type: "prompt", Alignment: "left", Newline: true, Segments: []ompSegment{char}})
	}
	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	enc.SetEscapeHTML(false)
	enc.SetIndent("", "  ")
	if err := enc.Encode(cfg); err != nil {
		panic(err) // only plain strings, maps and slices: cannot fail
	}
	return jsonEscapePUA(buf.String())
}

type ompRenderer struct {
	p   Preset
	sep [2]string
}

func (r ompRenderer) side(segs []Segment, left bool) []ompSegment {
	var out []ompSegment
	for _, s := range segs {
		switch s.Type {
		case "jobs":
			continue
		case "langs":
			for _, l := range langs {
				icon := ""
				if r.p.NerdFont {
					icon = l.icon
				}
				out = append(out, r.segment(s, ompKind{typ: l.omp, body: "{{ .Full }}"}, icon, len(out) == 0, left))
			}
		default:
			out = append(out, r.segment(s, ompKinds[s.Type], segmentIcon(r.p, s), len(out) == 0, left))
		}
	}
	return out
}

func (r ompRenderer) segment(s Segment, k ompKind, icon string, first, left bool) ompSegment {
	body := k.body
	if icon != "" {
		body = icon + " " + body
	}
	fg := "p:" + paletteKey(s.FG)
	if s.Suffix != "" && r.p.Layout != "text" {
		body += s.Suffix
	}
	switch s.Style {
	case "bold":
		body = "<b>" + body + "</b>"
	case "italic":
		body = "<i>" + body + "</i>"
	}
	seg := ompSegment{Type: k.typ, Foreground: fg, Options: k.opts}
	switch r.p.Layout {
	case "text":
		seg.Style = "plain"
		pre := ""
		if r.p.Separator != "none" && !first {
			pre = "<p:outline>" + r.sep[0] + " </>"
		}
		if s.Prefix != "" {
			pre += "<p:outline>" + s.Prefix + "</>"
		}
		body = pre + body
		if s.Suffix != "" {
			body += "<p:outline>" + s.Suffix + "</>"
		}
		if left {
			body += " "
		} else {
			body = " " + body
		}
	case "pills":
		seg.Style = "diamond"
		seg.Background = "p:" + paletteKey(s.BG)
		seg.LeadingDiamond, seg.TrailingDiamond = r.sep[1], r.sep[0]
		if left {
			seg.TrailingDiamond += " "
		} else {
			seg.LeadingDiamond = " " + seg.LeadingDiamond
		}
		body = s.Prefix + body
	default: // powerline
		seg.Style = "powerline"
		seg.Background = "p:" + paletteKey(s.BG)
		seg.PowerlineSymbol = r.sep[0]
		if !left {
			seg.PowerlineSymbol, seg.InvertPowerline = r.sep[1], true
		} else if first {
			// A powerline first segment gets a leading symbol; a diamond
			// starts flush (or with a rounded cap).
			seg.Style, seg.PowerlineSymbol = "diamond", ""
			if r.p.Separator == "rounded" {
				seg.LeadingDiamond = r.sep[1]
			}
		}
		body = " " + s.Prefix + body + " "
	}
	if k.cond != "" {
		body = "{{ if " + k.cond + " }}" + body + "{{ end }}"
	}
	seg.Template = body
	return seg
}

// char is the final prompt character, red after a failed command.
func (r ompRenderer) char() ompSegment {
	tmpl := r.p.Char.Symbol
	if r.p.Char.Error != r.p.Char.Symbol {
		tmpl = "{{ if gt .Code 0 }}" + r.p.Char.Error + "{{ else }}" + r.p.Char.Symbol + "{{ end }}"
	}
	if r.p.Frame {
		tmpl = "<p:outline>" + frameBottom + "</>" + tmpl
	}
	return ompSegment{
		Type: "text", Style: "plain", Foreground: "p:" + paletteKey(r.p.Char.Color),
		ForegroundTemplates: []string{"{{ if gt .Code 0 }}p:error{{ end }}"},
		Template:            "<b>" + tmpl + "</b>",
	}
}

// jsonEscapePUA rewrites Private-Use glyphs in encoded JSON as \u escapes
// (surrogate pairs above U+FFFF); they only occur inside strings.
func jsonEscapePUA(s string) string {
	var b strings.Builder
	for _, r := range s {
		switch {
		case isPUA(r) && r > 0xFFFF:
			v := r - 0x10000
			fmt.Fprintf(&b, "\\u%04x\\u%04x", 0xD800+(v>>10), 0xDC00+(v&0x3FF))
		case isPUA(r):
			fmt.Fprintf(&b, "\\u%04x", r)
		default:
			b.WriteRune(r)
		}
	}
	return b.String()
}
