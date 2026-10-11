// Package termrun builds the argv that opens the user's terminal running a
// command line ("Run in terminal" bind / routine action). The command is
// never spliced into a string: it travels as one positional argument of
// `sh -c '<fixed script>' sh COMMAND CWD`.
package termrun

import (
	"fmt"
	"path/filepath"
	"strings"
)

// Config is the terminal setup of the general config domain.
type Config struct {
	Terminal string // general.terminal ("kitty", "foot --server"...)
	Advanced bool   // general.terminalAdvanced
	Template string // general.terminalCommand ("$TERMINAL -e $COMMAND")
}

// Request is what to run.
type Request struct {
	Command  string
	Cwd      string // already expanded; empty keeps the caller's directory
	KeepOpen bool   // stay in an interactive shell after the command ends
}

// The only shell text ever built is one of these constants: $1 is the
// user's command line, $2 the directory.
const (
	scriptKeep  = `if [ -n "$2" ]; then cd -- "$2" || exit 1; fi; eval "$1"; exec "${SHELL:-sh}"`
	scriptOnce  = `if [ -n "$2" ]; then cd -- "$2" || exit 1; fi; eval "$1"`
	commandWord = "$COMMAND"
	termWord    = "$TERMINAL"
)

// execArgs maps a terminal binary to the words that precede the program.
// Unknown terminals take "-e".
var execArgs = map[string][]string{
	"kitty":          nil,
	"foot":           nil,
	"footclient":     nil,
	"alacritty":      {"-e"},
	"ghostty":        {"-e"},
	"konsole":        {"-e"},
	"xterm":          {"-e"},
	"urxvt":          {"-e"},
	"st":             {"-e"},
	"tilix":          {"-e"},
	"wezterm":        {"start", "--"},
	"gnome-terminal": {"--"},
	"kgx":            {"--"},
	"xfce4-terminal": {"-x"},
	"terminator":     {"-x"},
}

// ExecArgs returns the words that make a terminal run the rest of its argv.
func ExecArgs(binary string) []string {
	if a, ok := execArgs[filepath.Base(binary)]; ok {
		return a
	}
	return []string{"-e"}
}

// Script is the argv that runs the request: sh -c SCRIPT sh COMMAND CWD.
func Script(r Request) []string {
	s := scriptOnce
	if r.KeepOpen {
		s = scriptKeep
	}
	return []string{"sh", "-c", s, "sh", r.Command, r.Cwd}
}

// Argv is the full terminal command line.
func Argv(c Config, r Request) ([]string, error) {
	if strings.TrimSpace(r.Command) == "" {
		return nil, fmt.Errorf("no command to run")
	}
	bin := Fields(c.Terminal)
	if len(bin) == 0 {
		return nil, fmt.Errorf("no terminal configured (general.terminal)")
	}
	script := Script(r)
	if c.Advanced && strings.Contains(c.Template, commandWord) {
		return fromTemplate(c, bin, script), nil
	}
	argv := append([]string{}, bin...)
	argv = append(argv, ExecArgs(bin[0])...)
	return append(argv, script...), nil
}

// fromTemplate renders "$TERMINAL -e $COMMAND" as argv: a word that is
// exactly $COMMAND becomes the script words, one that merely contains it
// gets the quoted script line; $TERMINAL becomes the configured terminal.
func fromTemplate(c Config, bin, script []string) []string {
	var out []string
	for _, f := range split(c.Template) {
		w := f.text
		switch {
		case w == commandWord && !f.quoted:
			out = append(out, script...)
		case w == termWord:
			out = append(out, bin...)
		case strings.Contains(w, commandWord) || strings.Contains(w, termWord):
			w = strings.ReplaceAll(w, commandWord, Quote(script))
			out = append(out, strings.ReplaceAll(w, termWord, Quote(bin)))
		default:
			out = append(out, w)
		}
	}
	return out
}

// Quote joins words into one safely single-quoted shell line.
func Quote(words []string) string {
	q := make([]string, len(words))
	for i, w := range words {
		q[i] = "'" + strings.ReplaceAll(w, "'", `'\''`) + "'"
	}
	return strings.Join(q, " ")
}

// Fields splits a configured command line into words, honouring single and
// double quotes and backslash escapes (no expansion of any kind).
func Fields(s string) []string {
	var out []string
	for _, f := range split(s) {
		out = append(out, f.text)
	}
	return out
}

type word struct {
	text   string
	quoted bool // some part of the word was in quotes
}

func split(s string) []word {
	var out []word
	var cur strings.Builder
	var quote rune
	inWord, wasQuoted := false, false
	esc := false
	for _, r := range s {
		switch {
		case esc:
			cur.WriteRune(r)
			esc = false
		case r == '\\' && quote != '\'':
			esc, inWord = true, true
		case quote != 0:
			if r == quote {
				quote = 0
			} else {
				cur.WriteRune(r)
			}
		case r == '\'' || r == '"':
			quote, inWord, wasQuoted = r, true, true
		case r == ' ' || r == '\t' || r == '\n':
			if inWord {
				out = append(out, word{cur.String(), wasQuoted})
				cur.Reset()
				inWord, wasQuoted = false, false
			}
		default:
			cur.WriteRune(r)
			inWord = true
		}
	}
	if inWord {
		out = append(out, word{cur.String(), wasQuoted})
	}
	return out
}

// ExpandHome expands a leading ~ with home.
func ExpandHome(p, home string) string {
	p = strings.TrimSpace(p)
	switch {
	case p == "~":
		return home
	case strings.HasPrefix(p, "~/"):
		return filepath.Join(home, p[2:])
	}
	return p
}
