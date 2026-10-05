package main

import "strings"

// cliArgs splits a command line into positionals and known flags. Only the
// flags a command declares are flags; anything else (e.g. "-1") stays a
// positional, and "--" ends flag parsing.
type cliArgs struct {
	pos    []string
	bools  map[string]bool
	values map[string]string
}

// parseCLI parses args; bools/valued list flag names without dashes
// ("json", "force"), each accepted as -name or --name (--name=value too).
func parseCLI(args []string, bools []string, valued []string) cliArgs {
	isBool := map[string]bool{}
	for _, b := range bools {
		isBool[b] = true
	}
	isValued := map[string]bool{}
	for _, v := range valued {
		isValued[v] = true
	}
	out := cliArgs{bools: map[string]bool{}, values: map[string]string{}}
	for i := 0; i < len(args); i++ {
		a := args[i]
		if a == "--" {
			out.pos = append(out.pos, args[i+1:]...)
			break
		}
		name := strings.TrimLeft(a, "-")
		if !strings.HasPrefix(a, "-") || name == "" {
			out.pos = append(out.pos, a)
			continue
		}
		value, hasValue := "", false
		if eq := strings.IndexByte(name, '='); eq >= 0 {
			name, value, hasValue = name[:eq], name[eq+1:], true
		}
		switch {
		case isBool[name] && !hasValue:
			out.bools[name] = true
		case isValued[name] && hasValue:
			out.values[name] = value
		case isValued[name] && i+1 < len(args):
			out.values[name] = args[i+1]
			i++
		default:
			out.pos = append(out.pos, a)
		}
	}
	return out
}

func (c cliArgs) has(name string) bool { return c.bools[name] }

func (c cliArgs) value(name string) (string, bool) {
	v, ok := c.values[name]
	return v, ok
}
