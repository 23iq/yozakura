package termlook

import (
	"reflect"
	"testing"
)

func TestParseANSI(t *testing.T) {
	cases := []struct {
		name string
		in   string
		want [][]Span
	}{
		{"truecolor", "\x1b[38;2;245;173;255;48;2;1;2;3mhi\x1b[0m!",
			[][]Span{{{Text: "hi", FG: "#f5adff", BG: "#010203"}, {Text: "!"}}}},
		{"256", "\x1b[38;5;196ma\x1b[48;5;232mb\x1b[38;5;5mc\x1b[38;5;21md",
			[][]Span{{{Text: "a", FG: "#ff0000"}, {Text: "b", FG: "#ff0000", BG: "#080808"},
				{Text: "c", FG: ANSI16[5], BG: "#080808"}, {Text: "d", FG: "#0000ff", BG: "#080808"}}}},
		{"16 colors", "\x1b[31mr\x1b[92mg\x1b[44mb\x1b[39;49mn",
			[][]Span{{{Text: "r", FG: ANSI16[1]}, {Text: "g", FG: ANSI16[10]},
				{Text: "b", FG: ANSI16[10], BG: ANSI16[4]}, {Text: "n"}}}},
		{"attrs", "\x1b[1;3;4mx\x1b[22;23;24my",
			[][]Span{{{Text: "x", Bold: true, Italic: true, Underline: true}, {Text: "y"}}}},
		{"empty reset", "\x1b[1ma\x1b[mb", [][]Span{{{Text: "a", Bold: true}, {Text: "b"}}}},
		{"osc8 hyperlink", "\x1b]8;;https://x.y\x07link\x1b]8;;\x07 \x1b]8;;u\x1b\\z\x1b]8;;\x1b\\",
			[][]Span{{{Text: "link z"}}}},
		{"non-sgr csi", "\x1b[J\x1b[2Ka\x1b[3;4Hb\x1b[?25l", [][]Span{{{Text: "ab"}}}},
		{"markers", "%{\x1b[1m%}a%{\x1b[0m%}\\[\\]b", [][]Span{{{Text: "a", Bold: true}, {Text: "b"}}}},
		{"lines", "a\r\n\x1b[1mb\nc", [][]Span{{{Text: "a"}}, {{Text: "b", Bold: true}}, {{Text: "c", Bold: true}}}},
		{"truncated", "a\x1b[38;2;1", [][]Span{{{Text: "a"}}}},
		{"nerd glyph", "\x1b[1m\U0000e0b0\x1b[0m", [][]Span{{{Text: "\U0000e0b0", Bold: true}}}},
	}
	for _, c := range cases {
		if got := ParseANSI(c.in); !reflect.DeepEqual(got, c.want) {
			t.Errorf("%s:\n got %#v\nwant %#v", c.name, got, c.want)
		}
	}
}

func TestParseANSIWithTable(t *testing.T) {
	var tbl [16]string
	tbl[1] = "#abcdef"
	got := ParseANSIWith("\x1b[31mx", tbl)
	if got[0][0].FG != "#abcdef" {
		t.Errorf("table not used: %#v", got)
	}
}
