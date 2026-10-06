package niri

import (
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"yozakura/backend/pkg/yozd/ipc"
)

// niri has no IPC request for its xkb settings: CurrentKeyboard reads them
// from the config (best effort: $NIRI_CONFIG or <config>/niri/config.kdl,
// following `include` lines in place; later values win, like niri's own
// merge). Without a configured layout the settings are unknown and it
// answers ErrNotSupported.
func (n *Niri) CurrentKeyboard() (ipc.KeyboardSettings, error) {
	return ReadKeyboard(configPath())
}

func configPath() string {
	if p := os.Getenv("NIRI_CONFIG"); p != "" {
		return p
	}
	return filepath.Join(ipc.ConfigHome(), "niri", "config.kdl")
}

// ReadKeyboard reads the keyboard settings of a niri config and its includes.
func ReadKeyboard(path string) (ipc.KeyboardSettings, error) {
	var k niriKeyboard
	k.read(path, map[string]bool{})
	if k.layout == "" {
		return ipc.KeyboardSettings{}, ipc.ErrNotSupported
	}
	split := func(s string) []string {
		if s == "" {
			return nil
		}
		return strings.Split(s, ",")
	}
	return ipc.KeyboardSettings{
		Layouts: split(k.layout), Variants: split(k.variant), Options: split(k.options), Model: k.model,
		RepeatRate: k.rate, RepeatDelay: k.delay,
	}.Normalize(), nil
}

type niriKeyboard struct {
	layout, variant, options, model string
	rate, delay                     int
}

func (k *niriKeyboard) read(path string, seen map[string]bool) {
	if seen[path] || len(seen) > 16 {
		return
	}
	seen[path] = true
	data, err := os.ReadFile(path)
	if err != nil {
		return
	}
	walkKDL(string(data), func(blocks []string, name string, args []string) {
		if len(blocks) == 0 && name == "include" && len(args) > 0 {
			k.read(ipc.ExpandPath(args[0], filepath.Dir(path)), seen)
			return
		}
		arg := ""
		if len(args) > 0 {
			arg = args[0]
		}
		switch strings.Join(blocks, "/") {
		case "input/keyboard/xkb":
			switch name {
			case "layout":
				k.layout = arg
			case "variant":
				k.variant = arg
			case "options":
				k.options = arg
			case "model":
				k.model = arg
			}
		case "input/keyboard":
			n, err := strconv.Atoi(arg)
			if err != nil {
				return
			}
			switch name {
			case "repeat-rate":
				k.rate = n
			case "repeat-delay":
				k.delay = n
			}
		}
	})
}

// walkKDL calls fn for every node of KDL source with the names of its
// enclosing blocks: strings are unquoted, `//` and `/* */` comments and
// `/-` slashdashed nodes (with their blocks) are skipped. Enough for the
// flat settings niri keeps in its config, not a full KDL parser.
func walkKDL(src string, fn func(blocks []string, name string, args []string)) {
	var blocks []string
	var words []string
	skipDepth := -1 // block depth of a slashdashed node being skipped
	slashdash := false
	emit := func(open bool) {
		if len(words) > 0 {
			name, args := words[0], words[1:]
			skip := slashdash || skipDepth >= 0
			if open {
				if skip && skipDepth < 0 {
					skipDepth = len(blocks)
				}
				blocks = append(blocks, name)
			} else if !skip {
				fn(blocks, name, args)
			}
		} else if open {
			blocks = append(blocks, "")
		}
		words, slashdash = nil, false
	}
	for i := 0; i < len(src); i++ {
		c := src[i]
		switch {
		case c == '"':
			j := i + 1
			var b strings.Builder
			for ; j < len(src) && src[j] != '"'; j++ {
				if src[j] == '\\' && j+1 < len(src) {
					j++
				}
				b.WriteByte(src[j])
			}
			words = append(words, b.String())
			i = j
		case c == '/' && i+1 < len(src) && src[i+1] == '/':
			for i < len(src) && src[i] != '\n' {
				i++
			}
			i--
		case c == '/' && i+1 < len(src) && src[i+1] == '*':
			end := strings.Index(src[i+2:], "*/")
			if end < 0 {
				return
			}
			i += end + 3
		case c == '/' && i+1 < len(src) && src[i+1] == '-':
			slashdash = true
			i++
		case c == '{':
			emit(true)
		case c == '}':
			emit(false)
			if len(blocks) > 0 {
				blocks = blocks[:len(blocks)-1]
			}
			if skipDepth >= 0 && len(blocks) <= skipDepth {
				skipDepth = -1
			}
		case c == '\n' || c == ';':
			emit(false)
		case c == ' ' || c == '\t' || c == '\r':
		default:
			j := i
			for j < len(src) && !strings.ContainsRune(" \t\r\n;{}\"", rune(src[j])) {
				j++
			}
			words = append(words, src[i:j])
			i = j - 1
		}
	}
	emit(false)
}

var _ ipc.KeyboardReader = (*Niri)(nil)
