package main

import (
	"fmt"
	"io"
	"strings"

	"yozakura/backend/pkg/catalog"
)

// keyInfo is the `config describe --json` shape (also used by MCP).
type keyInfo struct {
	*catalog.Entry
	Current  any    `json:"current"`
	Explicit bool   `json:"explicit"` // set in the config file (else the default applies)
	File     string `json:"file"`
}

func (c *configEnv) describe(args []string, out io.Writer) error {
	a := parseCLI(args, []string{"json"}, nil)
	if len(a.pos) != 1 {
		return fmt.Errorf("usage: config describe <key>")
	}
	ref, err := c.cat.Lookup(a.pos[0])
	if err != nil {
		return err
	}
	e := ref.Entry
	cur, explicit, err := c.store.Get(e.Key)
	if err != nil {
		return err
	}
	info := keyInfo{Entry: e, Current: cur, Explicit: explicit, File: c.store.File(e.Domain)}
	if a.has("json") {
		return writeJSON(out, info)
	}
	title := e.Title
	if title == "" {
		title = e.Path[len(e.Path)-1]
	}
	fmt.Fprintf(out, "%s - %s\n", e.Key, title)
	if e.Description != "" {
		fmt.Fprintf(out, "  %s\n", e.Description)
	}
	row := func(label, value string) {
		if value != "" {
			fmt.Fprintf(out, "  %-10s %s\n", label+":", value)
		}
	}
	typ := e.Type
	if e.Type == "array" && e.Items != nil && e.Items.Type != "" {
		typ = "array of " + e.Items.Type
	}
	if e.Format != "" {
		typ += " (" + e.Format + ")"
	}
	row("type", typ)
	row("allowed", allowedText(e))
	if e.Min != nil || e.Max != nil {
		row("range", catalog.Range(e.Min, e.Max)+" "+e.Unit)
	} else {
		row("unit", e.Unit)
	}
	if len(e.Special) > 0 {
		var parts []string
		for _, sv := range e.Special {
			p := catalog.Scalar(sv.Value)
			if sv.Label != "" {
				p += " (" + sv.Label + ")"
			}
			parts = append(parts, p)
		}
		row("special", strings.Join(parts, ", "))
	}
	if e.Type == "object" {
		row("keys", strings.Join(e.Children, ", "))
	}
	row("default", shown(e, e.Default))
	state := "default"
	if explicit {
		state = "set in file"
	}
	row("current", shown(e, cur)+"  ("+state+")")
	if s := e.Settings; s != nil {
		where := c.cat.CategoryTitle(s.Category) + " > " + s.Section
		if s.Control != "" {
			where += " (" + s.Control
			if s.Component != "" {
				where += ": " + s.Component
			}
			where += ")"
		}
		if s.EntryTitle != "" {
			where += " - part of \"" + s.EntryTitle + "\""
		}
		row("settings", where)
		if len(s.VisibleWhen) > 0 {
			row("shown if", string(s.VisibleWhen))
		}
		if len(s.EnabledWhen) > 0 {
			row("enabled if", string(s.EnabledWhen))
		}
	}
	if e.ReadOnly {
		row("note", "read-only")
	}
	row("file", c.store.File(e.Domain))
	return nil
}

func allowedText(e *catalog.Entry) string {
	list := func(vals []any, labels map[string]string) string {
		parts := make([]string, len(vals))
		for i, v := range vals {
			parts[i] = catalog.Scalar(v)
			if l := labels[catalog.Scalar(v)]; l != "" && !strings.EqualFold(l, parts[i]) {
				parts[i] += " (" + l + ")"
			}
		}
		return strings.Join(parts, ", ")
	}
	switch {
	case len(e.Enum) > 0:
		return list(e.Enum, e.EnumLabels)
	case e.Items != nil && len(e.Items.Enum) > 0:
		s := "items from " + list(e.Items.Enum, nil)
		if e.UniqueItems {
			s += " (each once)"
		}
		return s
	case e.Type == "boolean":
		return "true, false"
	case e.Pattern != "":
		return "matching " + e.Pattern
	}
	return ""
}

func (c *configEnv) search(args []string, out io.Writer) error {
	a := parseCLI(args, []string{"json"}, []string{"n", "limit"})
	if len(a.pos) == 0 {
		return fmt.Errorf("usage: config search <words...>")
	}
	limit := 20
	for _, f := range []string{"n", "limit"} {
		if v, ok := a.value(f); ok {
			if _, err := fmt.Sscanf(v, "%d", &limit); err != nil {
				return fmt.Errorf("--%s needs a number", f)
			}
		}
	}
	hits := c.cat.Search(strings.Join(a.pos, " "), limit)
	if a.has("json") {
		type hit struct {
			Key         string `json:"key"`
			Type        string `json:"type"`
			Title       string `json:"title,omitempty"`
			Description string `json:"description,omitempty"`
			Score       int    `json:"score"`
		}
		rows := make([]hit, len(hits))
		for i, h := range hits {
			rows[i] = hit{h.Entry.Key, h.Entry.Type, h.Entry.Title, h.Entry.Description, h.Score}
		}
		return writeJSON(out, rows)
	}
	if len(hits) == 0 {
		fmt.Fprintln(out, "No matching settings.")
		return nil
	}
	width := 0
	for _, h := range hits {
		width = max(width, len(h.Entry.Key))
	}
	for _, h := range hits {
		desc := truncate(h.Entry.Description, 90)
		fmt.Fprintf(out, "%-*s  %s\n", width, h.Entry.Key, firstNonEmpty(h.Entry.Title+": "+desc, desc))
	}
	return nil
}

func firstNonEmpty(vals ...string) string {
	for _, v := range vals {
		if strings.TrimSpace(v) != "" && v != ": " {
			return v
		}
	}
	return ""
}

// truncate shortens s to n runes with an ellipsis.
func truncate(s string, n int) string {
	r := []rune(s)
	if len(r) <= n {
		return s
	}
	return string(r[:n-3]) + "..."
}
