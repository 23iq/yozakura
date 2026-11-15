package convert

import (
	"strconv"
	"strings"
)

// CSS can fetch (url(), image-set(), @import ...) and hides that behind
// escapes: u\72l( and \75rl( are url(. cssLoads decodes the escapes and
// drops whitespace and comments before it looks.

// cssLoaders mark CSS that fetches something.
var cssLoaders = []string{"url(", "image-set(", "image(", "@import", "expression(", "src:", "cross-fade(",
	"element(", "behavior:", "-moz-binding"}

// cssLoads reports whether css (a style attribute or sheet) loads a
// resource.
func cssLoads(css string) bool {
	low := strings.ToLower(cssPlain(css))
	for _, l := range cssLoaders {
		if strings.Contains(low, l) {
			return true
		}
	}
	return false
}

// cssPlain is css with its escapes decoded and its whitespace and comments
// removed.
func cssPlain(css string) string {
	var b strings.Builder
	for i := 0; i < len(css); i++ {
		c := css[i]
		switch {
		case c == '/' && i+1 < len(css) && css[i+1] == '*':
			end := strings.Index(css[i+2:], "*/")
			if end < 0 {
				return b.String()
			}
			i += end + 3
		case c == '\\' && i+1 < len(css):
			j := i + 1
			for j < len(css) && j-i <= 6 && isHex(css[j]) {
				j++
			}
			if j > i+1 {
				if r, err := strconv.ParseUint(css[i+1:j], 16, 32); err == nil {
					b.WriteRune(rune(r))
				}
				// one whitespace ends a hex escape
				if j < len(css) && (css[j] == ' ' || css[j] == '\t' || css[j] == '\n') {
					j++
				}
				i = j - 1
			} else {
				b.WriteByte(css[i+1])
				i++
			}
		case c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\f':
		default:
			b.WriteByte(c)
		}
	}
	return b.String()
}

func isHex(c byte) bool {
	return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
}
