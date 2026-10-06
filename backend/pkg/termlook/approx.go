package termlook

// sampleText is what each segment type shows in the approximate preview.
var sampleText = map[string]string{
	"user": "you", "host": "yozakura", "dir": "~/projects/yozakura", "git_branch": "main",
	"git_status": "!1", "langs": "22.4", "duration": "3s", "time": "21:37",
	"status": "1", "jobs": "1", "battery": "85%",
}

// archIcon is the os icon of the sample machine.
const archIcon = "\U0000F303"

// RenderApprox draws the preset from its description without running an
// engine: same colors, glyphs and layout, sample texts.
func RenderApprox(p Preset, pal Palette) (left [][]Span, right []Span) {
	sep := SeparatorGlyphs[p.Separator]
	var first []Span
	switch p.Layout {
	case "text":
		first = approxText(p, p.Left, pal)
	case "pills":
		first = approxPills(p, p.Left, pal, sep)
	default:
		first = approxBar(p, p.Left, pal, sep, true)
	}
	char := Span{Text: p.Char.Symbol, FG: pal[p.Char.Color], Bold: true}
	space := Span{Text: " "}
	frame := func(s string) []Span { return []Span{{Text: s, FG: pal["outline"]}} }
	if p.Lines == 2 {
		top, bottom := first, []Span{char, space}
		if p.Frame {
			top = append(frame(frameTop+" "), first...)
			bottom = append(frame(frameBottom), bottom...)
		}
		left = [][]Span{top, bottom}
	} else {
		left = [][]Span{append(append(first, space), char, space)}
	}
	switch p.Layout {
	case "text":
		right = approxText(p, p.Right, pal)
	case "pills":
		right = approxPills(p, p.Right, pal, sep)
	default:
		right = approxBar(p, p.Right, pal, sep, false)
	}
	return left, right
}

func segLabel(p Preset, s Segment) string {
	icon := segmentIcon(p, s)
	text := sampleText[s.Type]
	switch s.Type {
	case "os":
		if p.NerdFont && s.Icon == "" {
			icon = archIcon
		}
		text = ""
	case "langs":
		if s.Icon == "" && p.NerdFont {
			icon = langs[0].icon
		}
	}
	text = s.Prefix + text + s.Suffix
	if icon != "" && text != "" {
		return icon + " " + text
	}
	return icon + text
}

func segSpan(p Preset, s Segment, pal Palette, pad bool) Span {
	l := segLabel(p, s)
	if pad {
		l = " " + l + " "
	}
	return Span{Text: l, FG: pal[s.FG], BG: pal[s.BG], Bold: s.Style == "bold", Italic: s.Style == "italic"}
}

func approxText(p Preset, segs []Segment, pal Palette) []Span {
	var out []Span
	for i, s := range segs {
		sp := segSpan(p, s, pal, false)
		if i > 0 {
			out = append(out, Span{Text: " "})
		}
		out = append(out, sp)
	}
	return out
}

func approxPills(p Preset, segs []Segment, pal Palette, sep [2]string) []Span {
	var out []Span
	for i, s := range segs {
		if i > 0 {
			out = append(out, Span{Text: " "})
		}
		bg := pal[s.BG]
		if sep[1] != "" {
			out = append(out, Span{Text: sep[1], FG: bg})
		}
		out = append(out, segSpan(p, s, pal, p.Separator == "none"))
		if sep[0] != "" {
			out = append(out, Span{Text: sep[0], FG: bg})
		}
	}
	return out
}

// approxBar draws one connected bar. On the left the separators point right
// and the bar ends with a closing separator; on the right they mirror.
func approxBar(p Preset, segs []Segment, pal Palette, sep [2]string, left bool) []Span {
	var out []Span
	for i, s := range segs {
		bg := pal[s.BG]
		switch {
		case left && i > 0 && sep[0] != "":
			out = append(out, Span{Text: sep[0], FG: pal[segs[i-1].BG], BG: bg})
		case !left && sep[1] != "":
			prev := ""
			if i > 0 {
				prev = pal[segs[i-1].BG]
			}
			out = append(out, Span{Text: sep[1], FG: bg, BG: prev})
		}
		out = append(out, segSpan(p, s, pal, true))
	}
	if left && len(segs) > 0 && sep[0] != "" {
		out = append(out, Span{Text: sep[0], FG: pal[segs[len(segs)-1].BG]})
	}
	return out
}
