package main

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/catalog"
	"yozakura/backend/pkg/paths"
)

// reset, path, schema and the completion helpers of `yozakura config`.

func (c *configEnv) reset(args []string, out io.Writer) error {
	a := parseCLI(args, []string{"yes", "y"}, nil)
	if len(a.pos) != 1 {
		return fmt.Errorf("usage: %s config reset <key|domain> [--yes]", brand.AppID)
	}
	target := catalog.NormalizeKey(a.pos[0])
	var changes []catalog.Change
	var err error
	if c.cat.HasDomain(target) {
		if !a.has("yes") && !a.has("y") {
			cur, err := c.store.Current(target)
			if err != nil {
				return err
			}
			n := 0
			for _, e := range c.cat.Keys(target, true) {
				if v, ok := lookupPath(cur, e.Path); !ok || catalog.Compact(v) != catalog.Compact(e.Default) {
					n++
				}
			}
			return fmt.Errorf("this resets all of %s (%d customized keys); run again with --yes", target, n)
		}
		changes, err = c.store.ResetDomain(target)
	} else {
		changes, err = c.store.Reset(target)
	}
	if err != nil {
		return err
	}
	if len(changes) == 0 {
		fmt.Fprintf(out, "%s: already at defaults\n", target)
		return nil
	}
	printChanges(out, c.cat, changes, target, nil)
	return nil
}

func lookupPath(doc map[string]any, path []string) (any, bool) {
	var cur any = doc
	for _, p := range path {
		m, ok := cur.(map[string]any)
		if !ok {
			return nil, false
		}
		if cur, ok = m[p]; !ok {
			return nil, false
		}
	}
	return cur, true
}

func (c *configEnv) path(args []string, out io.Writer) error {
	p := paths.New()
	if len(args) == 0 {
		fmt.Fprintln(out, filepath.Dir(p.Config("theme")))
		return nil
	}
	if !c.cat.HasDomain(args[0]) {
		return fmt.Errorf("unknown config domain %q (domains: %s)", args[0], strings.Join(c.cat.DomainNames(), ", "))
	}
	fmt.Fprintln(out, p.Config(args[0]))
	return nil
}

func (c *configEnv) schema(args []string, out io.Writer) error {
	file := catalog.SchemaFile
	if len(args) > 0 {
		if !c.cat.HasDomain(args[0]) {
			return fmt.Errorf("unknown config domain %q (domains: %s)", args[0], strings.Join(c.cat.DomainNames(), ", "))
		}
		file = strings.Replace(file, brand.AppID+".schema.json", args[0]+".schema.json", 1)
	}
	data, err := os.ReadFile(filepath.Join(c.src, file))
	if err != nil {
		return fmt.Errorf("%v (generate it with `make schema` in the shell source)", err)
	}
	_, err = out.Write(data)
	return err
}

// complete prints completion candidates (used by the shell completions).
func (c *configEnv) complete(cmd string, args []string, out io.Writer) {
	switch cmd {
	case "__domains":
		for _, d := range c.cat.DomainNames() {
			fmt.Fprintln(out, d)
		}
	case "__keys":
		for _, e := range c.cat.Keys("", false) {
			fmt.Fprintln(out, e.Key)
		}
	case "__values":
		if len(args) == 0 {
			return
		}
		ref, err := c.cat.Lookup(args[0])
		if err != nil {
			return
		}
		e := ref.Entry
		switch {
		case len(e.Enum) > 0:
			for _, v := range e.Enum {
				fmt.Fprintln(out, catalog.Scalar(v))
			}
		case e.Type == "boolean":
			fmt.Fprintln(out, "true")
			fmt.Fprintln(out, "false")
		case e.Items != nil && len(e.Items.Enum) > 0:
			for _, v := range e.Items.Enum {
				fmt.Fprintln(out, catalog.Scalar(v))
			}
		}
	}
}
