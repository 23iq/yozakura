package mcp

import (
	"strconv"
	"strings"
	"unicode"
)

func (p *tomlParser) parseBasicString() (string, error) {
	p.pos++ // opening quote
	var b strings.Builder
	for {
		if p.eof() || p.peek() == '\n' {
			return "", p.errf("unterminated string")
		}
		r := p.s[p.pos]
		p.pos++
		switch r {
		case '"':
			return b.String(), nil
		case '\\':
			if err := p.escape(&b); err != nil {
				return "", err
			}
		default:
			b.WriteRune(r)
		}
	}
}

func (p *tomlParser) escape(b *strings.Builder) error {
	if p.eof() {
		return p.errf("bad escape")
	}
	r := p.s[p.pos]
	p.pos++
	switch r {
	case 'n':
		b.WriteRune('\n')
	case 't':
		b.WriteRune('\t')
	case 'r':
		b.WriteRune('\r')
	case 'b':
		b.WriteRune('\b')
	case 'f':
		b.WriteRune('\f')
	case 'e':
		b.WriteRune(0x1b)
	case '"', '\\':
		b.WriteRune(r)
	case 'u', 'U':
		n := 4
		if r == 'U' {
			n = 8
		}
		if p.pos+n > len(p.s) {
			return p.errf("bad unicode escape")
		}
		v, err := strconv.ParseUint(string(p.s[p.pos:p.pos+n]), 16, 32)
		if err != nil {
			return p.errf("bad unicode escape")
		}
		p.pos += n
		b.WriteRune(rune(v))
	default:
		return p.errf("bad escape \\%c", r)
	}
	return nil
}

func (p *tomlParser) parseLiteralString() (string, error) {
	p.pos++
	start := p.pos
	for !p.eof() && p.peek() != '\'' {
		if p.peek() == '\n' {
			return "", p.errf("unterminated literal string")
		}
		p.pos++
	}
	if p.eof() {
		return "", p.errf("unterminated literal string")
	}
	s := string(p.s[start:p.pos])
	p.pos++
	return s, nil
}

func (p *tomlParser) parseMultiline(q rune) (string, error) {
	p.pos += 3
	if p.peek() == '\r' {
		p.pos++
	}
	if p.peek() == '\n' {
		p.pos++
		p.line++
	}
	var b strings.Builder
	for {
		if p.eof() {
			return "", p.errf("unterminated multi-line string")
		}
		if p.peek() == q && p.peekAt(1) == q && p.peekAt(2) == q {
			p.pos += 3
			for p.peek() == q { // up to two extra quotes belong to the content
				b.WriteRune(q)
				p.pos++
			}
			return b.String(), nil
		}
		r := p.s[p.pos]
		p.pos++
		if r == '\n' {
			p.line++
		}
		if q == '"' && r == '\\' {
			// line-ending backslash trims following whitespace
			if c := p.peek(); c == '\n' || c == ' ' || c == '\t' || c == '\r' {
				save := p.pos
				for !p.eof() && (p.peek() == ' ' || p.peek() == '\t' || p.peek() == '\r') {
					p.pos++
				}
				if p.peek() == '\n' {
					for !p.eof() && unicode.IsSpace(p.peek()) {
						if p.peek() == '\n' {
							p.line++
						}
						p.pos++
					}
					continue
				}
				p.pos = save
			}
			if err := p.escape(&b); err != nil {
				return "", err
			}
			continue
		}
		b.WriteRune(r)
	}
}
