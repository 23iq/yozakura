//go:build linux

package systemmonitor

import "testing"

func TestParseNvidiaSmi(t *testing.T) {
	cases := []struct {
		in    string
		usage float64
		temp  int
	}{
		{"12, 45\n", 12, 45},
		{"3, 34.80\n", 3, 35},
		{"0, 43.49", 0, 43},
		{"7, [N/A]", 7, -1},
		{"", 0, -1},
	}
	for _, c := range cases {
		u, tmp := parseNvidiaSmi(c.in)
		if u != c.usage || tmp != c.temp {
			t.Errorf("parseNvidiaSmi(%q) = %v, %d; want %v, %d", c.in, u, tmp, c.usage, c.temp)
		}
	}
}
