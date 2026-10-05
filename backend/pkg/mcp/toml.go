package mcp

import (
	"fmt"
	"strconv"
	"strings"
	"unicode"
)

// ParseTOML parses the subset of TOML used by tool configs: tables, array
// tables, dotted/quoted keys, strings (basic, literal, multi-line), numbers,
// booleans, arrays and inline tables. Datetimes are kept as strings.
func ParseTOML(src string) (map[string]any, error) {
	p := &tomlParser{s: []rune(src), line: 1}
	root := map[string]any{}
	cur := root
	for {
		p.skipWSNL()
		if p.eof() {
			return root, nil
		}
		switch p.peek() {
		case '#':
			p.skipComment()
		case '[':
			arrayTable := p.peekAt(1) == '['
			p.pos++
			if arrayTable {
				p.pos++
			}
			keys, err := p.parseKey()
			if err != nil {
				return nil, err
			}
			p.skipWS()
			if !p.consume(']') || (arrayTable && !p.consume(']')) {
				return nil, p.errf("expected ] after table header")
			}
			t, err := descend(root, keys, arrayTable)
			if err != nil {
				return nil, p.errf("%v", err)
			}
			cur = t
			if err := p.endOfLine(); err != nil {
				return nil, err
			}
		default:
			keys, err := p.parseKey()
			if err != nil {
				return nil, err
			}
			p.skipWS()
			if !p.consume('=') {
				return nil, p.errf("expected = after key")
			}
			p.skipWS()
			v, err := p.parseValue()
			if err != nil {
				return nil, err
			}
			if err := setKey(cur, keys, v); err != nil {
				return nil, p.errf("%v", err)
			}
			if err := p.endOfLine(); err != nil {
				return nil, err
			}
		}
	}
}

type tomlParser struct {
	s    []rune
	pos  int
	line int
}

func (p *tomlParser) eof() bool  { return p.pos >= len(p.s) }
func (p *tomlParser) peek() rune { return p.peekAt(0) }
func (p *tomlParser) peekAt(n int) rune {
	if p.pos+n >= len(p.s) {
		return 0
	}
	return p.s[p.pos+n]
}

func (p *tomlParser) consume(r rune) bool {
	if p.peek() == r && !p.eof() {
		p.pos++
		return true
	}
	return false
}

func (p *tomlParser) errf(format string, args ...any) error {
	return fmt.Errorf("toml line %d: %s", p.line, fmt.Sprintf(format, args...))
}

func (p *tomlParser) skipWS() {
	for !p.eof() && (p.peek() == ' ' || p.peek() == '\t') {
		p.pos++
	}
}

func (p *tomlParser) skipWSNL() {
	for !p.eof() {
		switch p.peek() {
		case ' ', '\t', '\r':
			p.pos++
		case '\n':
			p.line++
			p.pos++
		default:
			return
		}
	}
}

func (p *tomlParser) skipComment() {
	for !p.eof() && p.peek() != '\n' {
		p.pos++
	}
}

// skipAll skips whitespace, newlines and comments (inside arrays).
func (p *tomlParser) skipAll() {
	for {
		p.skipWSNL()
		if p.peek() == '#' {
			p.skipComment()
			continue
		}
		return
	}
}

func (p *tomlParser) endOfLine() error {
	p.skipWS()
	if p.peek() == '#' {
		p.skipComment()
	}
	p.consume('\r')
	if p.eof() || p.consume('\n') {
		p.line++
		return nil
	}
	return p.errf("unexpected %q after value", p.peek())
}

func (p *tomlParser) parseKey() ([]string, error) {
	var keys []string
	for {
		p.skipWS()
		var k string
		switch p.peek() {
		case '"':
			s, err := p.parseBasicString()
			if err != nil {
				return nil, err
			}
			k = s
		case '\'':
			s, err := p.parseLiteralString()
			if err != nil {
				return nil, err
			}
			k = s
		default:
			start := p.pos
			for !p.eof() {
				r := p.peek()
				if unicode.IsLetter(r) || unicode.IsDigit(r) || r == '_' || r == '-' {
					p.pos++
					continue
				}
				break
			}
			if start == p.pos {
				return nil, p.errf("invalid key")
			}
			k = string(p.s[start:p.pos])
		}
		keys = append(keys, k)
		p.skipWS()
		if !p.consume('.') {
			return keys, nil
		}
	}
}

func (p *tomlParser) parseValue() (any, error) {
	switch r := p.peek(); {
	case r == '"':
		if p.peekAt(1) == '"' && p.peekAt(2) == '"' {
			return p.parseMultiline('"')
		}
		return p.parseBasicString()
	case r == '\'':
		if p.peekAt(1) == '\'' && p.peekAt(2) == '\'' {
			return p.parseMultiline('\'')
		}
		return p.parseLiteralString()
	case r == '[':
		return p.parseArray()
	case r == '{':
		return p.parseInlineTable()
	default:
		start := p.pos
		for !p.eof() {
			c := p.peek()
			if c == ',' || c == ']' || c == '}' || c == '\n' || c == '#' || c == '\r' {
				break
			}
			p.pos++
		}
		tok := strings.TrimSpace(string(p.s[start:p.pos]))
		return scalar(tok)
	}
}

func scalar(tok string) (any, error) {
	switch tok {
	case "true":
		return true, nil
	case "false":
		return false, nil
	case "inf", "+inf", "-inf", "nan", "+nan", "-nan":
		return tok, nil
	case "":
		return nil, fmt.Errorf("missing value")
	}
	clean := strings.ReplaceAll(tok, "_", "")
	if i, err := strconv.ParseInt(clean, 0, 64); err == nil {
		return i, nil
	}
	if f, err := strconv.ParseFloat(clean, 64); err == nil {
		return f, nil
	}
	if len(tok) >= 10 && tok[4] == '-' {
		return tok, nil // datetime
	}
	return nil, fmt.Errorf("invalid value %q", tok)
}

func (p *tomlParser) parseArray() ([]any, error) {
	p.pos++
	out := []any{}
	for {
		p.skipAll()
		if p.consume(']') {
			return out, nil
		}
		v, err := p.parseValue()
		if err != nil {
			return nil, err
		}
		out = append(out, v)
		p.skipAll()
		if p.consume(',') {
			continue
		}
		p.skipAll()
		if p.consume(']') {
			return out, nil
		}
		return nil, p.errf("expected , or ] in array")
	}
}

func (p *tomlParser) parseInlineTable() (map[string]any, error) {
	p.pos++
	out := map[string]any{}
	p.skipAll()
	if p.consume('}') {
		return out, nil
	}
	for {
		p.skipAll()
		keys, err := p.parseKey()
		if err != nil {
			return nil, err
		}
		p.skipWS()
		if !p.consume('=') {
			return nil, p.errf("expected = in inline table")
		}
		p.skipWS()
		v, err := p.parseValue()
		if err != nil {
			return nil, err
		}
		if err := setKey(out, keys, v); err != nil {
			return nil, p.errf("%v", err)
		}
		p.skipAll()
		if p.consume(',') {
			p.skipAll()
			if p.consume('}') { // tolerate trailing comma (TOML 1.1)
				return out, nil
			}
			continue
		}
		if p.consume('}') {
			return out, nil
		}
		return nil, p.errf("expected , or } in inline table")
	}
}

func descend(root map[string]any, keys []string, arrayTable bool) (map[string]any, error) {
	t := root
	for i, k := range keys {
		last := i == len(keys)-1
		v, ok := t[k]
		if last && arrayTable {
			arr, _ := v.([]any)
			if ok && arr == nil {
				return nil, fmt.Errorf("key %s is not an array of tables", k)
			}
			nt := map[string]any{}
			t[k] = append(arr, nt)
			return nt, nil
		}
		if !ok {
			nt := map[string]any{}
			t[k] = nt
			t = nt
			continue
		}
		switch x := v.(type) {
		case map[string]any:
			t = x
		case []any:
			if len(x) == 0 {
				return nil, fmt.Errorf("key %s is an empty array", k)
			}
			m, ok := x[len(x)-1].(map[string]any)
			if !ok {
				return nil, fmt.Errorf("key %s is not a table", k)
			}
			t = m
		default:
			return nil, fmt.Errorf("key %s is not a table", k)
		}
	}
	return t, nil
}

func setKey(t map[string]any, keys []string, v any) error {
	parent, err := descend(t, keys[:len(keys)-1], false)
	if err != nil {
		return err
	}
	k := keys[len(keys)-1]
	if _, exists := parent[k]; exists {
		return fmt.Errorf("duplicate key %s", strings.Join(keys, "."))
	}
	parent[k] = v
	return nil
}
