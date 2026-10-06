package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"strings"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/catalog"
	"yozakura/backend/pkg/mcp/yozakura"
	"yozakura/backend/pkg/paths"
)

const configUsage = `Usage: {bin} config <command> [args]

Read and change the shell configuration. Keys are <domain>.<dotted.path>
(e.g. bar.position, theme.roundness, bar.layout.left); array items can be
addressed as key.N or key[N]. Changes are validated against the settings
catalog and written to the live config file, which the running shell
hot-applies.

Commands:
    list [domain|key] [--json]          Domains, or the keys under a domain/key with current values
    get <key> [--json]                  Current value (strings print bare)
    set <key> <value> [flags]           Validate and write a value; prints old -> new
        --json                          Parse <value> as JSON whatever the type
        --add <item> / --remove <item>  Add/remove one item of an array
        --force                         Skip enum/range checks (type is still checked)
        --dry-run                       Validate and show the change without writing
    toggle <key>                        Flip a boolean
    describe <key> [--json]             Title, description, type, default, current, allowed values
    reset <key|domain> [--yes]          Back to the default (a whole domain needs --yes)
    search <text...> [--json] [-n N]    Find settings by words (key, title, description, keywords)
    schema [domain]                     Print the JSON Schema (2020-12) of the catalog or a domain
    path [domain]                       Config directory, or the file of a domain

Values: booleans true/false/on/off, numbers, strings verbatim, arrays as JSON
or a comma list (a,b,c), objects as JSON (merged member by member).
`

type configEnv struct {
	cat   *catalog.Catalog
	store *catalog.Store
	src   string
}

func loadConfigEnv() (*configEnv, error) {
	src := paths.FindShellSource()
	cat, err := catalog.Load(src)
	if err != nil {
		return nil, err
	}
	return &configEnv{cat: cat, store: &catalog.Store{Cat: cat, File: paths.New().Config}, src: src}, nil
}

// runConfig implements `yozakura config ...`; out/errOut are injectable for tests.
// keyboardDaemon reaches the running backend for the keyboard takeover of
// `config set keyboard.*` (yozakura.PrepareConfigSet); replaced in tests.
var keyboardDaemon = func() yozakura.Caller { return newClient() }

func runConfig(args []string, out, errOut io.Writer) int {
	if len(args) == 0 || args[0] == "help" || args[0] == "-h" || args[0] == "--help" {
		fmt.Fprint(out, branded(configUsage))
		return 0
	}
	env, err := loadConfigEnv()
	if err != nil {
		fmt.Fprintf(errOut, "Error: %v\n", err)
		return 1
	}
	cmd, rest := args[0], args[1:]
	switch cmd {
	case "list", "ls":
		err = env.list(rest, out)
	case "get":
		err = env.get(rest, out)
	case "set":
		err = env.set(rest, out)
	case "toggle":
		err = env.toggle(rest, out)
	case "describe", "desc", "info":
		err = env.describe(rest, out)
	case "reset":
		err = env.reset(rest, out)
	case "search", "find":
		err = env.search(rest, out)
	case "schema":
		err = env.schema(rest, out)
	case "path":
		err = env.path(rest, out)
	case "__keys", "__values", "__domains":
		env.complete(cmd, rest, out)
	default:
		err = fmt.Errorf("unknown config command %q (see `%s config help`)", cmd, brand.AppID)
	}
	if err != nil {
		fmt.Fprintf(errOut, "Error: %v\n", err)
		return 1
	}
	return 0
}

func writeJSON(w io.Writer, v any) error {
	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	enc.SetEscapeHTML(false)
	enc.SetIndent("", "  ")
	if err := enc.Encode(v); err != nil {
		return err
	}
	_, err := w.Write(buf.Bytes())
	return err
}

func shown(e *catalog.Entry, v any) string {
	if e.Secret {
		if s, _ := v.(string); s != "" {
			return `"********"`
		}
	}
	return catalog.Compact(v)
}

func (c *configEnv) list(args []string, out io.Writer) error {
	a := parseCLI(args, []string{"json"}, nil)
	if len(a.pos) == 0 {
		if a.has("json") {
			return writeJSON(out, c.cat.Domains())
		}
		for _, d := range c.cat.Domains() {
			fmt.Fprintf(out, "%-12s %4d keys  %s\n", d.Name, d.Keys, d.Description)
		}
		fmt.Fprintf(out, "\n`%s config list <domain>` lists the keys of a domain.\n", brand.AppID)
		return nil
	}
	prefix := catalog.NormalizeKey(a.pos[0])
	if !c.cat.HasDomain(prefix) {
		if _, err := c.cat.Lookup(prefix); err != nil {
			return err
		}
	}
	type row struct {
		Key      string `json:"key"`
		Type     string `json:"type"`
		Value    any    `json:"value"`
		Default  any    `json:"default"`
		Modified bool   `json:"modified"`
		Title    string `json:"title,omitempty"`
	}
	var rows []row
	width := 0
	for _, e := range c.cat.Keys(prefix, true) {
		v, _, err := c.store.Get(e.Key)
		if err != nil {
			return err
		}
		rows = append(rows, row{e.Key, e.Type, v, e.Default, catalog.Compact(v) != catalog.Compact(e.Default), e.Title})
		width = max(width, len(e.Key))
	}
	if a.has("json") {
		return writeJSON(out, rows)
	}
	for i, r := range rows {
		e, _ := c.cat.Entry(r.Key)
		mark := " "
		if r.Modified {
			mark = "*"
		}
		fmt.Fprintf(out, "%s %-*s  %s\n", mark, width, r.Key, shown(e, rows[i].Value))
	}
	fmt.Fprintln(out, "\n* = differs from the default")
	return nil
}

func (c *configEnv) get(args []string, out io.Writer) error {
	a := parseCLI(args, []string{"json"}, nil)
	if len(a.pos) != 1 {
		return fmt.Errorf("usage: %s config get <key>", brand.AppID)
	}
	v, _, err := c.store.Get(a.pos[0])
	if err != nil {
		return err
	}
	if s, ok := v.(string); ok && !a.has("json") {
		fmt.Fprintln(out, s)
		return nil
	}
	return writeJSON(out, v)
}

func (c *configEnv) set(args []string, out io.Writer) error {
	a := parseCLI(args, []string{"json", "force", "dry-run", "replace"}, []string{"add", "remove"})
	addV, add := a.value("add")
	remV, remove := a.value("remove")
	if len(a.pos) < 1 || (!add && !remove && len(a.pos) < 2) {
		return fmt.Errorf("usage: %s config set <key> <value> (see `%s config help`)", brand.AppID, brand.AppID)
	}
	key := a.pos[0]
	ref, err := c.cat.Lookup(key)
	if err != nil {
		return err
	}
	e := ref.Entry
	var value any
	// arrErr: --add/--remove on the stored array failed; a keyboard takeover
	// below applies them to the compositor's array instead
	var arrErr error
	switch {
	case add || remove:
		if e.Type != "array" || ref.Index >= 0 {
			return fmt.Errorf("--add/--remove need an array key; %s is a %s", e.Key, e.Type)
		}
		value, arrErr = c.editArray(e, addV, add, remV, remove)
	case ref.Index >= 0:
		value, err = catalog.ParseItem(e, strings.Join(a.pos[1:], " "))
	default:
		value, err = catalog.ParseValue(e, strings.Join(a.pos[1:], " "), a.has("json"))
	}
	if err != nil {
		return err
	}
	// keyboard: the first change takes the compositor's settings over in the
	// same write; --add/--remove and [i] apply to the compositor's values
	build := func(base any) (any, error) {
		switch {
		case add || remove:
			return editArrayOn(base, e, addV, add, remV, remove)
		case ref.Index >= 0:
			return yozakura.ItemAt(base, ref.Index, value)
		}
		return value, nil
	}
	if a.has("dry-run") {
		return c.dryRunSet(out, key, e, ref.Index, value, arrErr, build, a.has("force"), a.has("replace"))
	}
	handled, changes, err := yozakura.KeyboardConfigSet(c.store, keyboardDaemon(), key, build, a.has("force"), a.has("replace"))
	if !handled && err == nil {
		if arrErr != nil {
			return arrErr
		}
		changes, err = c.store.Set(key, value, a.has("force"))
	}
	if err != nil {
		return err
	}
	printChanges(out, c.cat, changes, catalog.NormalizeKey(key), value)
	return nil
}

// dryRunSet prints what set would write; an unmanaged keyboard previews
// against the compositor's values, like the real write.
func (c *configEnv) dryRunSet(out io.Writer, key string, e *catalog.Entry, index int, value any, arrErr error, build func(any) (any, error), force, replace bool) error {
	handled, old, whole, err := yozakura.KeyboardConfigPreview(c.store, keyboardDaemon(), key, build, force, replace)
	if err != nil {
		return err
	}
	if handled {
		fmt.Fprintf(out, "%s: %s -> %s (dry run, not written)\n", e.Key, shown(e, old), shown(e, whole))
		return nil
	}
	if arrErr != nil {
		return arrErr
	}
	old, _, _ = c.store.Get(key)
	if index < 0 {
		if _, err := c.cat.Assign(e.Key, value, force); err != nil {
			return err
		}
	}
	fmt.Fprintf(out, "%s: %s -> %s (dry run, not written)\n", catalog.NormalizeKey(key), shown(e, old), shown(e, value))
	return nil
}

func (c *configEnv) editArray(e *catalog.Entry, addV string, add bool, remV string, remove bool) (any, error) {
	cur, _, err := c.store.Get(e.Key)
	if err != nil {
		return nil, err
	}
	return editArrayOn(cur, e, addV, add, remV, remove)
}

// editArrayOn is the array cur after --remove / --add.
func editArrayOn(cur any, e *catalog.Entry, addV string, add bool, remV string, remove bool) (any, error) {
	arr, _ := cur.([]any)
	arr = append([]any{}, arr...)
	if remove {
		item, err := catalog.ParseItem(e, remV)
		if err != nil {
			return nil, err
		}
		kept := arr[:0]
		found := false
		for _, x := range arr {
			if catalog.Compact(x) == catalog.Compact(item) {
				found = true
				continue
			}
			kept = append(kept, x)
		}
		if !found {
			return nil, fmt.Errorf("%s does not contain %s", e.Key, catalog.Compact(item))
		}
		arr = kept
	}
	if add {
		item, err := catalog.ParseItem(e, addV)
		if err != nil {
			return nil, err
		}
		arr = append(arr, item)
	}
	return arr, nil
}

func printChanges(out io.Writer, cat *catalog.Catalog, changes []catalog.Change, key string, value any) {
	if len(changes) == 0 {
		fmt.Fprintf(out, "%s: unchanged (%s)\n", key, catalog.Compact(value))
		return
	}
	for _, ch := range changes {
		e, _ := cat.Entry(ch.Key)
		if e == nil {
			e = &catalog.Entry{}
		}
		fmt.Fprintf(out, "%s: %s -> %s\n", ch.Key, shown(e, ch.Old), shown(e, ch.New))
	}
}

func (c *configEnv) toggle(args []string, out io.Writer) error {
	if len(args) != 1 {
		return fmt.Errorf("usage: %s config toggle <boolean key>", brand.AppID)
	}
	ref, err := c.cat.Lookup(args[0])
	if err != nil {
		return err
	}
	if ref.Entry.Type != "boolean" || ref.Index >= 0 {
		return fmt.Errorf("%s is a %s, not a boolean", ref.Entry.Key, ref.Entry.Type)
	}
	v, _, err := c.store.Get(ref.Entry.Key)
	if err != nil {
		return err
	}
	b, _ := v.(bool)
	handled, changes, err := yozakura.KeyboardConfigSet(c.store, keyboardDaemon(), ref.Entry.Key, func(any) (any, error) { return !b, nil }, false, false)
	if !handled && err == nil {
		changes, err = c.store.Set(ref.Entry.Key, !b, false)
	}
	if err != nil {
		return err
	}
	printChanges(out, c.cat, changes, ref.Entry.Key, !b)
	return nil
}
