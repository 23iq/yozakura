package transfers

import (
	"fmt"
	"strings"
)

// vdfNode is a parsed Valve KeyValues (VDF/ACF text) block. Keys are matched
// case-insensitively, as Steam itself does.
type vdfNode struct {
	values   map[string]string
	children map[string]*vdfNode
	order    []string // child keys in file order
}

func newVdfNode() *vdfNode {
	return &vdfNode{values: map[string]string{}, children: map[string]*vdfNode{}}
}

// Str returns the string value of key ("" when missing).
func (n *vdfNode) Str(key string) string {
	if n == nil {
		return ""
	}
	return n.values[strings.ToLower(key)]
}

// Int returns the integer value of key (0 when missing or invalid).
func (n *vdfNode) Int(key string) int64 {
	var v int64
	fmt.Sscan(n.Str(key), &v)
	return v
}

// Child returns the sub-block key or nil.
func (n *vdfNode) Child(key string) *vdfNode {
	if n == nil {
		return nil
	}
	return n.children[strings.ToLower(key)]
}

// Children lists the sub-blocks in file order.
func (n *vdfNode) Children() []*vdfNode {
	if n == nil {
		return nil
	}
	out := make([]*vdfNode, 0, len(n.order))
	for _, k := range n.order {
		out = append(out, n.children[k])
	}
	return out
}

// parseVDF parses KeyValues text: quoted (or bare) keys followed by a quoted
// value or a { block }. Comments (//) and conditionals ([$WIN32]) are
// skipped. The returned root holds the top-level keys.
func parseVDF(text string) (*vdfNode, error) {
	toks, err := vdfTokens(text)
	if err != nil {
		return nil, err
	}
	root := newVdfNode()
	stack := []*vdfNode{root}
	for i := 0; i < len(toks); i++ {
		t := toks[i]
		cur := stack[len(stack)-1]
		switch {
		case t == "}" && !strings.HasPrefix(t, "\""):
			if len(stack) == 1 {
				return nil, fmt.Errorf("vdf: unbalanced }")
			}
			stack = stack[:len(stack)-1]
		case t == "{":
			return nil, fmt.Errorf("vdf: block without a key")
		default:
			key := strings.ToLower(unquote(t))
			if i+1 >= len(toks) {
				return nil, fmt.Errorf("vdf: key %q without value", key)
			}
			next := toks[i+1]
			i++
			if next == "{" {
				child := newVdfNode()
				if _, dup := cur.children[key]; !dup {
					cur.order = append(cur.order, key)
				}
				cur.children[key] = child
				stack = append(stack, child)
			} else {
				cur.values[key] = unquote(next)
			}
		}
	}
	if len(stack) != 1 {
		return nil, fmt.Errorf("vdf: unterminated block")
	}
	return root, nil
}

func unquote(t string) string {
	if len(t) >= 2 && t[0] == '"' && t[len(t)-1] == '"' {
		return t[1 : len(t)-1]
	}
	return t
}

// vdfTokens splits VDF text into tokens; quoted tokens keep their quotes so
// a quoted "{" is not mistaken for a brace.
func vdfTokens(s string) ([]string, error) {
	var toks []string
	for i := 0; i < len(s); {
		c := s[i]
		switch {
		case c == ' ' || c == '\t' || c == '\r' || c == '\n':
			i++
		case c == '/' && i+1 < len(s) && s[i+1] == '/':
			for i < len(s) && s[i] != '\n' {
				i++
			}
		case c == '[': // conditional like [$WIN32]
			for i < len(s) && s[i] != ']' {
				i++
			}
			i++
		case c == '{' || c == '}':
			toks = append(toks, string(c))
			i++
		case c == '"':
			var b strings.Builder
			b.WriteByte('"')
			i++
			for i < len(s) && s[i] != '"' {
				if s[i] == '\\' && i+1 < len(s) {
					switch s[i+1] {
					case 'n':
						b.WriteByte('\n')
					case 't':
						b.WriteByte('\t')
					default:
						b.WriteByte(s[i+1])
					}
					i += 2
					continue
				}
				b.WriteByte(s[i])
				i++
			}
			if i >= len(s) {
				return nil, fmt.Errorf("vdf: unterminated string")
			}
			b.WriteByte('"')
			i++
			toks = append(toks, b.String())
		default:
			start := i
			for i < len(s) && !strings.ContainsRune(" \t\r\n{}\"", rune(s[i])) {
				i++
			}
			toks = append(toks, s[start:i])
		}
	}
	return toks, nil
}
