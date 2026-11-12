package termlook

import (
	"os"
	"strings"
	"unicode/utf8"
)

// A custom text logo is printed in every new terminal: escape sequences in
// it could set the title, write the clipboard (OSC 52), move the cursor or
// send device strings. Only colours survive: the greeting prints a copy
// of the logo (its own file) with SGR sequences (ESC [ digits ; : m) kept
// and every other escape, C0 control (but newline and tab) and C1 control
// removed. The copy is also what fastfetch reads, so the file is read
// once, when it is applied.

// SanitizeLogo returns s with only SGR colour sequences left.
func SanitizeLogo(s string) string {
	rs := []rune(s)
	var b strings.Builder
	for i := 0; i < len(rs); {
		r := rs[i]
		switch {
		case r == 0x1b:
			i = escapeEnd(rs, i, &b)
		case r == 0x9b: // CSI (C1)
			i = csiEnd(rs, i+1, nil, 0)
		case r == 0x90 || r == 0x98 || r == 0x9d || r == 0x9e || r == 0x9f: // DCS SOS OSC PM APC
			i = stringEnd(rs, i+1)
		case r == '\n' || r == '\t':
			b.WriteRune(r)
			i++
		case r < 0x20 || r == 0x7f || (r >= 0x80 && r <= 0x9f) || r == utf8.RuneError:
			i++
		default:
			b.WriteRune(r)
			i++
		}
	}
	return b.String()
}

// escapeEnd skips the sequence starting with ESC at rs[i] (writing it to b
// when it is SGR) and returns the index after it.
func escapeEnd(rs []rune, i int, b *strings.Builder) int {
	if i+1 >= len(rs) {
		return len(rs) // a lone ESC at the end
	}
	switch next := rs[i+1]; {
	case next == '[':
		return csiEnd(rs, i+2, b, i)
	case next == ']' || next == 'P' || next == 'X' || next == '^' || next == '_':
		return stringEnd(rs, i+2)
	case next >= 0x20 && next <= 0x2f: // intermediates, then a final byte
		j := i + 1
		for j < len(rs) && rs[j] >= 0x20 && rs[j] <= 0x2f {
			j++
		}
		if j < len(rs) && rs[j] >= 0x30 && rs[j] <= 0x7e {
			j++
		}
		return j
	case next >= 0x30 && next <= 0x7e: // ESC c, ESC 7, ...
		return i + 2
	}
	return i + 1 // ESC before a control or text: the ESC goes
}

// csiEnd skips CSI parameters from rs[j] and the final byte; an SGR
// sequence (start: the ESC) is copied to b.
func csiEnd(rs []rune, j int, b *strings.Builder, start int) int {
	p := j
	for p < len(rs) && rs[p] >= 0x20 && rs[p] <= 0x3f {
		p++
	}
	if p >= len(rs) || rs[p] < 0x40 || rs[p] > 0x7e {
		return p // unterminated: what follows is text again
	}
	if b != nil && rs[p] == 'm' && strings.Trim(string(rs[j:p]), "0123456789;:") == "" {
		b.WriteString(string(rs[start : p+1]))
	}
	return p + 1
}

// stringEnd skips a control string (OSC, DCS, ...) up to its terminator:
// BEL, ST (ESC \) or C1 ST; unterminated, to the end.
func stringEnd(rs []rune, j int) int {
	for k := j; k < len(rs); k++ {
		switch {
		case rs[k] == 0x07 || rs[k] == 0x9c:
			return k + 1
		case rs[k] == 0x1b && k+1 < len(rs) && rs[k+1] == '\\':
			return k + 2
		}
	}
	return len(rs)
}

// copyCustomLogo writes the sanitised text logo at src to dst and returns
// the fastfetch logo of it: "file-raw" when colour sequences are left,
// else "file" ($1..$5 colour markers).
func copyCustomLogo(src, dst string) (FetchLogo, error) {
	f, err := os.Open(src)
	if err != nil {
		return FetchLogo{}, ErrLogoMissing
	}
	defer f.Close()
	data, err := readCapped(f, MaxTextLogo)
	if err != nil {
		return FetchLogo{}, err
	}
	if !utf8.Valid(data) {
		return FetchLogo{}, ErrLogoFormat
	}
	text := SanitizeLogo(string(data))
	if strings.TrimSpace(text) == "" {
		return FetchLogo{}, ErrLogoFormat
	}
	if err := writeAtomic(dst, []byte(text)); err != nil {
		return FetchLogo{}, err
	}
	kind := "file"
	if strings.ContainsRune(text, 0x1b) {
		kind = "file-raw"
	}
	return FetchLogo{Kind: kind, Source: dst}, nil
}
