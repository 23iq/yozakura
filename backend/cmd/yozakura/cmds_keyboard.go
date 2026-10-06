package main

import (
	"encoding/json"
	"fmt"
	"io"
	"strings"

	"yozakura/backend/pkg/catalog"
	"yozakura/backend/pkg/mcp/yozakura"
)

const keyboardHelp = `Usage: {bin} keyboard [list] [--json]
       {bin} keyboard add <layout>[:<variant>] [--replace]
       {bin} keyboard remove <layout>[:<variant>] [--replace]
       {bin} keyboard switch-bind alt_shift|super_space|caps|ctrl_shift|none [--replace]
       {bin} keyboard next

Keyboard layouts (keyboard.layouts / keyboard.switchBind; the running shell
applies a change live). add appends a layout (e.g. ru, us:intl, de:nodeadkeys),
remove drops it (the last one stays), switch-bind picks the key combination
that cycles layouts and next switches to the next layout right now.
Until the first change Yozakura leaves the keyboard to your compositor config
and list shows its settings; the first add/remove/switch-bind takes them over
(keyboard.managed) and needs the shell running. When the compositor cannot
report its settings, --replace confirms they may be replaced.
`

type keyboardEnv struct {
	c     usageCaller
	store func() (*catalog.Store, error)
}

func defaultKeyboardEnv() keyboardEnv {
	return keyboardEnv{c: newClient(), store: func() (*catalog.Store, error) {
		e, err := loadConfigEnv()
		if err != nil {
			return nil, err
		}
		return e.store, nil
	}}
}

// runKeyboard implements `yozakura keyboard ...`.
func runKeyboard(args []string, env keyboardEnv, out, errOut io.Writer) int {
	a := parseCLI(args, []string{"json", "help", "h", "replace"}, nil)
	if a.has("help") || a.has("h") || (len(a.pos) > 0 && a.pos[0] == "help") {
		fmt.Fprint(out, branded(keyboardHelp))
		return 0
	}
	sub, rest := "list", a.pos
	if len(rest) > 0 {
		sub, rest = rest[0], rest[1:]
	}
	var err error
	switch {
	case sub == "list" && len(rest) == 0:
		err = keyboardList(env, a.has("json"), out)
	case (sub == "add" || sub == "remove") && len(rest) == 1:
		err = keyboardEdit(env, sub == "add", rest[0], a.has("replace"), out)
	case (sub == "switch-bind" || sub == "switchbind") && len(rest) == 1:
		err = keyboardSwitchBind(env, rest[0], a.has("replace"), out)
	case sub == "next" && len(rest) == 0:
		if _, err = env.c.Call("keyboard.next", nil); err == nil {
			return 0
		}
		err = fmt.Errorf("%v (is the shell running?)", err)
	default:
		fmt.Fprintf(errOut, "Error: unknown arguments %q\n", strings.Join(append([]string{sub}, rest...), " "))
		fmt.Fprint(errOut, branded(keyboardHelp))
		return 2
	}
	if err != nil {
		fmt.Fprintf(errOut, "Error: %v\n", err)
		return 1
	}
	return 0
}

func keyboardList(env keyboardEnv, asJSON bool, out io.Writer) error {
	store, err := env.store()
	if err != nil {
		return err
	}
	st, err := yozakura.ReadKeyboard(store, env.c)
	if err != nil {
		return err
	}
	if asJSON {
		return printJSON(out, st, nil)
	}
	active := ""
	if len(st.Active) > 0 {
		active = jsonString(st.Active, "name")
	}
	for i, l := range st.Layouts {
		fmt.Fprintf(out, "%d  %s\n", i+1, l)
	}
	fmt.Fprintf(out, "Switch: %s\n", st.SwitchBind)
	if !st.Managed {
		fmt.Fprintln(out, "Managed by: your compositor config (a change here lets Yozakura manage it)")
	}
	if active != "" {
		fmt.Fprintf(out, "Active: %s\n", active)
	}
	return nil
}

func keyboardEdit(env keyboardEnv, add bool, spec string, replace bool, out io.Writer) error {
	l, err := yozakura.ParseLayoutSpec(spec)
	if err != nil {
		return err
	}
	if add {
		if err := yozakura.CheckLayoutKnown(env.c, l); err != nil {
			return err
		}
	}
	store, err := env.store()
	if err != nil {
		return err
	}
	if err := yozakura.ManageKeyboard(store, env.c, replace); err != nil {
		return err
	}
	st, err := yozakura.ReadKeyboard(store, nil)
	if err != nil {
		return err
	}
	list := st.Layouts
	if add {
		var changed bool
		if list, changed = yozakura.AddLayout(list, l); !changed {
			fmt.Fprintf(out, "%s is already configured\n", l)
			return nil
		}
	} else if list, err = yozakura.RemoveLayout(list, l); err != nil {
		return err
	}
	if err := yozakura.SaveLayouts(store, list); err != nil {
		return err
	}
	names := make([]string, len(list))
	for i, x := range list {
		names[i] = x.String()
	}
	fmt.Fprintf(out, "Layouts: %s\n", strings.Join(names, ", "))
	return nil
}

func keyboardSwitchBind(env keyboardEnv, bind string, replace bool, out io.Writer) error {
	if !yozakura.ValidSwitchBind(bind) {
		return fmt.Errorf("switch-bind must be one of %s", strings.Join(yozakura.SwitchBinds, ", "))
	}
	store, err := env.store()
	if err != nil {
		return err
	}
	if err := yozakura.ManageKeyboard(store, env.c, replace); err != nil {
		return err
	}
	if _, err := store.Set("keyboard.switchBind", bind, false); err != nil {
		return err
	}
	fmt.Fprintf(out, "Switch: %s\n", bind)
	return nil
}

// jsonString reads one string member of a JSON object ("" when absent).
func jsonString(raw []byte, key string) string {
	var m map[string]any
	if json.Unmarshal(raw, &m) != nil {
		return ""
	}
	s, _ := m[key].(string)
	return s
}
