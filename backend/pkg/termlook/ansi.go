package termlook

import (
	"fmt"
	"strconv"
	"strings"
)

// Span is a run of text with one style. Colors are "#rrggbb" or "".
type Span struct {
	Text                    string
	FG, BG                  string
	Bold, Italic, Underline bool
}

// ANSI16 is the default 16-color table (xterm-like) used when a prompt uses
// the terminal's own palette colors.
var ANSI16 = [16]string{
	"#000000", "#cd0000", "#00cd00", "#cdcd00", "#0000ee", "#cd00cd", "#00cdcd", "#e5e5e5",
	"#7f7f7f", "#ff0000", "#00ff00", "#ffff00", "#5c5cff", "#ff00ff", "#00ffff", "#ffffff",
}

// ParseANSI splits engine output into lines of styled spans using ANSI16.
func ParseANSI(s string) [][]Span { return ParseANSIWith(s, ANSI16) }

// ParseANSIWith is ParseANSI with an explicit 16-color table. Only SGR is
// interpreted; OSC (hyperlinks, titles), other CSI sequences and the zero
// width markers of shell prompts (%{ %} and \[ \]) are dropped.
func ParseANSIWith(s string, table [16]string) [][]Span {
	p := &ansiParser{table: table, lines: [][]Span{nil}}
	rs := []rune(s)
	for i := 0; i < len(rs); {
		switch r := rs[i]; {
		case r == 0x1b:
			i = p.escape(rs, i)
		case r == '\n':
			p.lines = append(p.lines, nil)
			i++
		case r == '\r':
			i++
		case (r == '%' || r == '\\') && i+1 < len(rs) && isMarker(r, rs[i+1]):
			i += 2
		default:
			p.text(r)
			i++
		}
	}
	return p.lines
}

func isMarker(a, b rune) bool {
	return (a == '%' && (b == '{' || b == '}')) || (a == '\\' && (b == '[' || b == ']'))
}

type ansiParser struct {
	table [16]string
	cur   Span
	lines [][]Span
}

func (p *ansiParser) text(r rune) {
	l := len(p.lines) - 1
	if n := len(p.lines[l]); n > 0 {
		last := &p.lines[l][n-1]
		if last.FG == p.cur.FG && last.BG == p.cur.BG && last.Bold == p.cur.Bold &&
			last.Italic == p.cur.Italic && last.Underline == p.cur.Underline {
			last.Text += string(r)
			return
		}
	}
	sp := p.cur
	sp.Text = string(r)
	p.lines[l] = append(p.lines[l], sp)
}

// escape consumes one escape sequence starting at rs[i] and returns the
// index after it.
func (p *ansiParser) escape(rs []rune, i int) int {
	if i+1 >= len(rs) {
		return i + 1
	}
	switch rs[i+1] {
	case '[':
		j := i + 2
		for j < len(rs) && (rs[j] < 0x40 || rs[j] > 0x7e) {
			j++
		}
		if j >= len(rs) {
			return len(rs)
		}
		if rs[j] == 'm' {
			p.sgr(string(rs[i+2 : j]))
		}
		return j + 1
	case ']', 'P', '_', '^', 'X':
		for j := i + 2; j < len(rs); j++ {
			if rs[j] == 0x07 {
				return j + 1
			}
			if rs[j] == 0x1b && j+1 < len(rs) && rs[j+1] == '\\' {
				return j + 2
			}
		}
		return len(rs)
	}
	return i + 2
}

func (p *ansiParser) sgr(params string) {
	if params == "" {
		p.cur = Span{}
		return
	}
	parts := strings.Split(strings.ReplaceAll(params, ":", ";"), ";")
	nums := make([]int, len(parts))
	for k, s := range parts {
		nums[k], _ = strconv.Atoi(s)
	}
	for k := 0; k < len(nums); k++ {
		n := nums[k]
		switch {
		case n == 0:
			p.cur = Span{}
		case n == 1:
			p.cur.Bold = true
		case n == 3:
			p.cur.Italic = true
		case n == 4:
			p.cur.Underline = true
		case n == 22:
			p.cur.Bold = false
		case n == 23:
			p.cur.Italic = false
		case n == 24:
			p.cur.Underline = false
		case n == 39:
			p.cur.FG = ""
		case n == 49:
			p.cur.BG = ""
		case n >= 30 && n <= 37:
			p.cur.FG = p.table[n-30]
		case n >= 90 && n <= 97:
			p.cur.FG = p.table[n-90+8]
		case n >= 40 && n <= 47:
			p.cur.BG = p.table[n-40]
		case n >= 100 && n <= 107:
			p.cur.BG = p.table[n-100+8]
		case n == 38 || n == 48:
			col, used := p.extended(nums[k+1:])
			k += used
			if col != "" {
				if n == 38 {
					p.cur.FG = col
				} else {
					p.cur.BG = col
				}
			}
		}
	}
}

// extended parses the arguments after 38/48 and returns the color and the
// number of arguments consumed.
func (p *ansiParser) extended(a []int) (string, int) {
	switch {
	case len(a) >= 2 && a[0] == 5:
		return p.xterm256(a[1]), 2
	case len(a) >= 4 && a[0] == 2:
		return fmt.Sprintf("#%02x%02x%02x", clamp(a[1]), clamp(a[2]), clamp(a[3])), 4
	}
	return "", len(a)
}

func clamp(v int) int { return min(max(v, 0), 255) }

func (p *ansiParser) xterm256(n int) string {
	switch {
	case n < 0 || n > 255:
		return ""
	case n < 16:
		return p.table[n]
	case n < 232:
		n -= 16
		lv := [6]int{0, 95, 135, 175, 215, 255}
		return fmt.Sprintf("#%02x%02x%02x", lv[n/36], lv[(n/6)%6], lv[n%6])
	}
	g := 8 + 10*(n-232)
	return fmt.Sprintf("#%02x%02x%02x", g, g, g)
}
