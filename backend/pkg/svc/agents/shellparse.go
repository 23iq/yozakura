package agents

import (
	"path/filepath"
	"regexp"
	"strings"
	"unicode"
)

// cmdSegment is one simple command of a list/pipeline: its argv and the
// operator that follows it ("" for the last one).
type cmdSegment struct {
	argv []string
	op   string
}

// parseScript splits a shell command into simple commands. It understands a
// deliberately small subset of POSIX sh: blank-separated words, single and
// double quotes, backslash escapes and the operators ; && || |. Anything
// else (expansions, redirections, globs, subshells, background jobs,
// comments, newlines, env prefixes are just words) makes it fail, so a
// successful parse means argv is exactly what the shell would execute.
// A `bash -c 'script'` / `sh -lc "script"` wrapper is unwrapped once.
func parseScript(cmd string) ([]cmdSegment, bool) {
	segs, ok := tokenize(cmd)
	if !ok {
		return nil, false
	}
	if inner, wrapped := shellWrapped(segs); wrapped {
		return tokenize(inner)
	}
	return segs, true
}

// shellWrapped reports `sh -c SCRIPT` (exactly that, nothing after it).
func shellWrapped(segs []cmdSegment) (string, bool) {
	if len(segs) != 1 || len(segs[0].argv) != 3 {
		return "", false
	}
	a := segs[0].argv
	switch programName(a[0]) {
	case "bash", "sh", "zsh":
	default:
		return "", false
	}
	if a[1] != "-c" && a[1] != "-lc" {
		return "", false
	}
	return a[2], true
}

// plainChar is a character that is literal when unquoted.
func plainChar(r rune) bool {
	if r < 0x80 {
		return r >= 'a' && r <= 'z' || r >= 'A' && r <= 'Z' || r >= '0' && r <= '9' || strings.ContainsRune("-_./=:,+%@^~", r)
	}
	return unicode.IsLetter(r) || unicode.IsDigit(r)
}

func tokenize(s string) ([]cmdSegment, bool) {
	rs := []rune(s)
	var (
		segs []cmdSegment
		argv []string
		word strings.Builder
		in   bool // a word is in progress (possibly empty: '')
	)
	endWord := func() {
		if in {
			argv = append(argv, word.String())
			word.Reset()
			in = false
		}
	}
	endSeg := func(op string) bool {
		endWord()
		if len(argv) == 0 {
			return false
		}
		segs = append(segs, cmdSegment{argv: argv, op: op})
		argv = nil
		return true
	}
	for i := 0; i < len(rs); i++ {
		r := rs[i]
		switch {
		case r == ' ' || r == '\t':
			endWord()
		case r == '\'':
			j := i + 1
			for j < len(rs) && rs[j] != '\'' {
				j++
			}
			if j >= len(rs) {
				return nil, false
			}
			word.WriteString(string(rs[i+1 : j]))
			in = true
			i = j
		case r == '"':
			j := i + 1
			for ; j < len(rs) && rs[j] != '"'; j++ {
				switch rs[j] {
				case '$', '`':
					return nil, false
				case '\\':
					if j+1 >= len(rs) {
						return nil, false
					}
					switch rs[j+1] {
					case '\\', '"':
						j++
						word.WriteRune(rs[j])
					case '$', '`', '\n':
						return nil, false
					default:
						word.WriteRune('\\')
					}
				default:
					word.WriteRune(rs[j])
				}
			}
			if j >= len(rs) {
				return nil, false
			}
			in = true
			i = j
		case r == '\\':
			if i+1 >= len(rs) || !unicode.IsPrint(rs[i+1]) {
				return nil, false
			}
			i++
			word.WriteRune(rs[i])
			in = true
		case r == ';':
			if !endSeg(";") {
				return nil, false
			}
		case r == '|':
			op := "|"
			if i+1 < len(rs) && rs[i+1] == '|' {
				op = "||"
				i++
			} else if i+1 < len(rs) && rs[i+1] == '&' {
				return nil, false
			}
			if !endSeg(op) {
				return nil, false
			}
		case r == '&':
			// A single & backgrounds a job: never accepted.
			if i+1 >= len(rs) || rs[i+1] != '&' {
				return nil, false
			}
			i++
			if !endSeg("&&") {
				return nil, false
			}
		case plainChar(r):
			word.WriteRune(r)
			in = true
		default:
			return nil, false
		}
	}
	endWord()
	if len(argv) == 0 {
		// Empty input or a trailing operator.
		return nil, false
	}
	segs = append(segs, cmdSegment{argv: argv})
	return segs, true
}

// programName returns the command name of argv[0] when it is a plain PATH
// lookup or a system binary; "" for relative paths (./x, bin/x) or other
// absolute paths, which could be anything.
func programName(arg0 string) string {
	if !strings.Contains(arg0, "/") {
		return arg0
	}
	dir, base := filepath.Split(arg0)
	switch dir {
	case "/bin/", "/usr/bin/", "/run/current-system/sw/bin/":
		return base
	}
	if nixStoreBin.MatchString(dir) {
		return base
	}
	return ""
}

// ProgramName is programName for other policy code (tasks): the bare name
// of a command run from PATH, a system bin dir or the Nix store; "" else.
func ProgramName(arg0 string) string { return programName(arg0) }

// nixStoreBin matches the bin dir of a Nix store package
// (/nix/store/<hash>-bash-5.3/bin/): immutable and root-owned like /usr/bin.
var nixStoreBin = regexp.MustCompile(`^/nix/store/[0-9a-z]{32}-[^/]+/bin/$`)
