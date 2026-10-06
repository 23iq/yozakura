package main

import (
	"encoding/json"
	"fmt"
	"io"
	"strconv"
	"strings"

	"yozakura/backend/pkg/binds"
	"yozakura/backend/pkg/brand"
)

const bindsUsage = `Usage: {bin} binds <command>

The bind advisor: find what a key could run, see every bind with its source
(shell-core, shell-user, compositor), check and suggest combos, and change
binds.json (the shell applies it live). The compositor's own config is only
read, never written.

Commands:
    search <words...> [--limit N] [--json]
                                     Actions, apps, launcher commands and
                                     workarounds for a request (any language)
    list [--source S] [--filter T] [--json]
                                     Every bind; S: shell-core, shell-user,
                                     compositor
    check <combo> [--json]           Is a combo free? (and who uses it)
    suggest <action|words> [--count N] [--json]
                                     Free, ergonomic combos for an action
    set <combo> <action> [key=value...] [--name N] [--replace] [--additional] [--json]
                                     Bind it; --replace unbinds shell binds on
                                     the combo; a core action is moved unless
                                     --additional
    rm <combo> [--action ID] [--json]
                                     Unbind (core binds are switched off)
    undo <token>                     Revert a set/rm (each prints its token)

Combos: "SUPER+SHIFT+S", "super + .", "SUPER" (lone Super). Examples:
    {bin} binds search переключить раскладку
    {bin} binds set SUPER+F window.fullscreen
    {bin} binds set SUPER+B apps.launch app=firefox
`

type bindsEnv struct {
	advisor func() (*binds.Advisor, error)
}

func defaultBindsEnv() bindsEnv {
	return bindsEnv{advisor: func() (*binds.Advisor, error) { return binds.New(shellSourceForCmd()) }}
}

// runBinds implements `yozakura binds ...`.
func runBinds(args []string, env bindsEnv, out, errOut io.Writer) int {
	if len(args) == 0 || args[0] == "help" || args[0] == "-h" || args[0] == "--help" {
		fmt.Fprint(out, branded(bindsUsage))
		return 0
	}
	adv, err := env.advisor()
	if err == nil {
		err = bindsCommand(adv, args, out)
	}
	if err != nil {
		fmt.Fprintf(errOut, "Error: %v\n", err)
		return 1
	}
	return 0
}

func bindsCommand(adv *binds.Advisor, args []string, out io.Writer) error {
	cmd := args[0]
	c := parseCLI(args[1:], []string{"json", "replace", "additional"}, []string{"limit", "count", "source", "filter", "name", "action"})
	asJSON := c.has("json")
	need := func(n int, usage string) error {
		if len(c.pos) < n {
			return fmt.Errorf("usage: %s binds %s", brand.AppID, usage)
		}
		return nil
	}
	switch cmd {
	case "search", "find":
		if err := need(1, "search <words...>"); err != nil {
			return err
		}
		res, err := adv.Search(strings.Join(c.pos, " "), intFlag(c, "limit", 10))
		if err != nil || asJSON {
			return printJSON(out, res, err)
		}
		printSearch(out, res)
	case "list", "ls":
		l, err := adv.List()
		if err != nil {
			return err
		}
		src, _ := c.value("source")
		text, _ := c.value("filter")
		l.Binds = binds.Filter(l.Binds, src, text)
		if asJSON {
			return printJSON(out, l, nil)
		}
		printBindList(out, l)
	case "check":
		if err := need(1, "check <combo>"); err != nil {
			return err
		}
		r, err := adv.Check(strings.Join(c.pos, " "))
		if err != nil || asJSON {
			return printJSON(out, r, err)
		}
		printCheck(out, r)
	case "suggest":
		if err := need(1, "suggest <action|words>"); err != nil {
			return err
		}
		r, err := adv.Suggest(strings.Join(c.pos, " "), intFlag(c, "count", 5))
		if err != nil || asJSON {
			return printJSON(out, r, err)
		}
		fmt.Fprintf(out, "%s (%s)\n", r.Label, r.Action.Action.ID)
		if len(r.Bound) > 0 {
			fmt.Fprintf(out, "  already on: %s\n", strings.Join(r.Bound, ", "))
		}
		for _, s := range r.Suggestions {
			fmt.Fprintf(out, "  %-18s %s\n", s.Combo, s.Reason)
		}
	case "set", "bind":
		if err := need(2, "set <combo> <action> [key=value...]"); err != nil {
			return err
		}
		req := binds.SetRequest{Combo: c.pos[0], Action: c.pos[1], Replace: c.has("replace"), Additional: c.has("additional")}
		req.Name, _ = c.value("name")
		req.Args = map[string]any{}
		for _, kv := range c.pos[2:] {
			k, v, ok := strings.Cut(kv, "=")
			if !ok {
				return fmt.Errorf("argument %q: use key=value", kv)
			}
			req.Args[k] = v
		}
		return printEdit(out, asJSON)(adv.Set(req))
	case "rm", "remove", "unbind":
		if err := need(1, "rm <combo>"); err != nil {
			return err
		}
		action, _ := c.value("action")
		return printEdit(out, asJSON)(adv.Remove(strings.Join(c.pos, " "), action))
	case "undo":
		if err := need(1, "undo <token>"); err != nil {
			return err
		}
		return printEdit(out, asJSON)(adv.Undo(c.pos[0]))
	default:
		return fmt.Errorf("unknown binds command %q (see `%s binds help`)", cmd, brand.AppID)
	}
	return nil
}

func intFlag(c cliArgs, name string, def int) int {
	if v, ok := c.value(name); ok {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			return n
		}
	}
	return def
}

func printJSON(out io.Writer, v any, err error) error {
	if err != nil {
		return err
	}
	data, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return err
	}
	fmt.Fprintln(out, string(data))
	return nil
}

func printSearch(out io.Writer, res []binds.Result) {
	if len(res) == 0 {
		fmt.Fprintln(out, "Nothing found. Generic options:")
		for _, h := range binds.FallbackHints() {
			fmt.Fprintln(out, "  "+h)
		}
		return
	}
	for _, r := range res {
		args, _ := json.Marshal(r.Action.Args)
		line := fmt.Sprintf("%-10s %-34s %s %s", r.Kind, r.Label, r.Action.ID, args)
		if len(r.Bound) > 0 {
			line += "  [" + strings.Join(r.Bound, ", ") + "]"
		}
		fmt.Fprintln(out, line)
		if r.Note != "" {
			fmt.Fprintln(out, "           "+r.Note)
		}
	}
}

func printBindList(out io.Writer, l *binds.Listing) {
	for _, b := range l.Binds {
		state := ""
		if !b.Enabled {
			state = " (off)"
		}
		if b.Submap != "" {
			state += " [submap " + b.Submap + "]"
		}
		fmt.Fprintf(out, "%-11s %-22s %s%s\n", b.Source, b.Combo, b.Label, state)
	}
	if l.CompositorError != "" {
		fmt.Fprintf(out, "(compositor binds unavailable: %s)\n", l.CompositorError)
	}
}

func printCheck(out io.Writer, r *binds.CheckResult) {
	switch {
	case r.Free:
		fmt.Fprintf(out, "%s is free\n", r.Combo)
	case len(r.Conflicts) == 0:
		fmt.Fprintf(out, "%s is unused but reserved: %s\n", r.Combo, r.Reserved)
	default:
		fmt.Fprintf(out, "%s is taken:\n", r.Combo)
		for _, b := range r.Conflicts {
			fmt.Fprintf(out, "  %-11s %s\n", b.Source, b.Label)
		}
		if r.Reserved != "" {
			fmt.Fprintf(out, "  (also reserved: %s)\n", r.Reserved)
		}
	}
	if r.CompositorError != "" {
		fmt.Fprintf(out, "(compositor binds unavailable: %s)\n", r.CompositorError)
	}
}

func printEdit(out io.Writer, asJSON bool) func(*binds.EditResult, error) error {
	return func(r *binds.EditResult, err error) error {
		if err != nil || asJSON {
			return printJSON(out, r, err)
		}
		for _, ch := range r.Changes {
			fmt.Fprintln(out, ch)
		}
		if r.Undo != nil {
			fmt.Fprintf(out, "Undo: %s\n", r.Undo.CLI)
		}
		return nil
	}
}
