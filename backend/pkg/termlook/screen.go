package termlook

import (
	"strconv"
	"strings"
)

// RenderScreen draws terminal output on a small virtual screen and returns
// its lines as styled spans. Unlike ParseANSI it follows the cursor moves
// fastfetch uses to align columns (CHA "\e[<n>G", CUF/CUB, CUU/CUD, CUP)
// and carriage returns; other sequences are dropped, colours come from
// table. Cells never written are blanks of the default style. The screen is
// a fixed box (screenRows x screenCols): the input may be a logo or config
// of the user's, so cursor moves are capped and writes outside are dropped.
func RenderScreen(s string, table [16]string) [][]Span {
	sc := &screen{p: ansiParser{table: table, lines: [][]Span{nil}}}
	rs := []rune(s)
	for i := 0; i < len(rs); {
		switch r := rs[i]; {
		case r == 0x1b && i+1 < len(rs) && rs[i+1] == '[':
			i = sc.csi(rs, i+2)
		case r == 0x1b:
			i = sc.p.escape(rs, i)
		case r == '\n':
			sc.row = min(sc.row+1, screenRows)
			sc.col = 0
			i++
		case r == '\r':
			sc.col = 0
			i++
		case r < 0x20 || r == 0x7f:
			i++ // BEL, BS, tabs: fastfetch does not use them
		default:
			sc.put(r)
			i++
		}
	}
	return sc.lines()
}

// The box of the virtual screen and the largest CSI parameter honoured.
const (
	screenRows = 300
	screenCols = 512
	maxCSIArg  = 9999
)

type cell struct {
	r     rune
	style Span
	set   bool
}

type screen struct {
	p        ansiParser
	grid     [][]cell
	row, col int
}

func (sc *screen) put(r rune) {
	if sc.row >= screenRows || sc.col >= screenCols {
		sc.col = min(sc.col+1, screenCols)
		return
	}
	for len(sc.grid) <= sc.row {
		sc.grid = append(sc.grid, nil)
	}
	line := sc.grid[sc.row]
	for len(line) <= sc.col {
		line = append(line, cell{})
	}
	st := sc.p.cur
	st.Text = ""
	line[sc.col] = cell{r: r, style: st, set: true}
	sc.grid[sc.row] = line
	sc.col++
}

// csi consumes a CSI sequence whose parameters start at rs[i].
func (sc *screen) csi(rs []rune, i int) int {
	j := i
	for j < len(rs) && (rs[j] < 0x40 || rs[j] > 0x7e) {
		j++
	}
	if j >= len(rs) {
		return len(rs)
	}
	params := string(rs[i:j])
	n := func(k int) int {
		parts := splitParams(params)
		if k < len(parts) {
			if v, err := strconv.Atoi(parts[k]); err == nil && v > 0 {
				return min(v, maxCSIArg)
			}
			if len(parts[k]) > 4 && strings.Trim(parts[k], "0123456789") == "" {
				return maxCSIArg // too large for an int
			}
		}
		return 1
	}
	switch rs[j] {
	case 'm':
		sc.p.sgr(params)
	case 'G':
		sc.col = n(0) - 1
	case 'C':
		sc.col += n(0)
	case 'D':
		sc.col = max(0, sc.col-n(0))
	case 'A':
		sc.row = max(0, sc.row-n(0))
	case 'B':
		sc.row += n(0)
	case 'H', 'f':
		sc.row, sc.col = n(0)-1, n(1)-1
	}
	sc.row, sc.col = min(sc.row, screenRows), min(sc.col, screenCols)
	if rs[j] == 'K' && sc.row < len(sc.grid) && sc.col < len(sc.grid[sc.row]) {
		sc.grid[sc.row] = sc.grid[sc.row][:sc.col]
	}
	return j + 1
}

func splitParams(s string) []string {
	var out []string
	start := 0
	for i := 0; i <= len(s); i++ {
		if i == len(s) || s[i] == ';' {
			out = append(out, s[start:i])
			start = i + 1
		}
	}
	return out
}

func sameStyle(a, b Span) bool {
	return a.FG == b.FG && a.BG == b.BG && a.Bold == b.Bold && a.Italic == b.Italic && a.Underline == b.Underline
}

// lines merges each row's cells into spans; trailing empty rows go.
func (sc *screen) lines() [][]Span {
	out := make([][]Span, 0, len(sc.grid))
	for _, row := range sc.grid {
		var spans []Span
		for _, c := range row {
			st, r := c.style, c.r
			if !c.set {
				st, r = Span{}, ' '
			}
			if n := len(spans); n > 0 && sameStyle(spans[n-1], st) {
				spans[n-1].Text += string(r)
				continue
			}
			st.Text = string(r)
			spans = append(spans, st)
		}
		out = append(out, spans)
	}
	for len(out) > 0 && len(out[len(out)-1]) == 0 {
		out = out[:len(out)-1]
	}
	return out
}
