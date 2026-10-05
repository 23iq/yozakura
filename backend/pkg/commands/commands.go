// Package commands reads the shell command registry
// (assets/commands/commands.json): the launcher's ">" commands, exposed to
// the CLI (`<app> cmd`) and the MCP server (shell_command). One entry per
// command; the registry is data only, so the launcher, the CLI and the MCP
// tools always offer the same commands.
package commands

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
)

// File is the registry path relative to the shell source.
var File = filepath.Join("assets", "commands", "commands.json")

// TranslationsFile holds the English titles of the registry keys.
var TranslationsFile = filepath.Join("translations", "en.json")

// Argument kinds.
const (
	ArgNone   = "none"
	ArgEnum   = "enum"
	ArgNumber = "number"
	ArgPreset = "preset"
)

// Plan kinds.
const (
	KindUI     = "ui"
	KindToggle = "toggle"
	KindCLI    = "cli"
	KindConfig = "config"
)

// Arg describes the optional argument of a command.
type Arg struct {
	Kind     string   `json:"kind"`
	Values   []string `json:"values,omitempty"`
	Min      *float64 `json:"min,omitempty"`
	Max      *float64 `json:"max,omitempty"`
	Step     float64  `json:"step,omitempty"`
	Default  string   `json:"default,omitempty"`
	Required bool     `json:"required,omitempty"`
}

// Run is what a command does; exactly one of UI, Toggle, CLI, Config is set.
type Run struct {
	UI     string         `json:"ui,omitempty"`
	Toggle string         `json:"toggle,omitempty"`
	CLI    []string       `json:"cli,omitempty"`
	Config string         `json:"config,omitempty"`
	Map    map[string]any `json:"map,omitempty"`
}

// Command is one registry entry. Title and Description are translation
// keys; Label and Help are their resolved English texts.
type Command struct {
	ID          string `json:"id"`
	Icon        string `json:"icon,omitempty"`
	Title       string `json:"title"`
	Description string `json:"description,omitempty"`
	Keywords    string `json:"keywords,omitempty"`
	Arg         *Arg   `json:"arg,omitempty"`
	Run         Run    `json:"run"`

	Label string `json:"-"`
	Help  string `json:"-"`
}

// Registry is the parsed commands.json.
type Registry struct {
	Version  int       `json:"version"`
	Commands []Command `json:"commands"`
}

// Load reads and validates the registry of the shell source at root and
// resolves titles from the English translations (falling back to the key).
func Load(root string) (*Registry, error) {
	if root == "" {
		return nil, errors.New("shell source not found: cannot read the command registry")
	}
	data, err := os.ReadFile(filepath.Join(root, File))
	if err != nil {
		return nil, err
	}
	r, err := Parse(data)
	if err != nil {
		return nil, fmt.Errorf("%s: %w", File, err)
	}
	tr := map[string]string{}
	if raw, err := os.ReadFile(filepath.Join(root, TranslationsFile)); err == nil {
		var all map[string]any
		if json.Unmarshal(raw, &all) == nil {
			for k, v := range all {
				if s, ok := v.(string); ok {
					tr[k] = s
				}
			}
		}
	}
	r.Localize(tr)
	return r, nil
}

// Parse decodes and validates a registry.
func Parse(data []byte) (*Registry, error) {
	var r Registry
	if err := json.Unmarshal(data, &r); err != nil {
		return nil, err
	}
	if err := r.Validate(); err != nil {
		return nil, err
	}
	r.Localize(nil)
	return &r, nil
}

// Validate checks ids, run kinds and argument specs.
func (r *Registry) Validate() error {
	seen := map[string]bool{}
	for i := range r.Commands {
		c := &r.Commands[i]
		if c.ID == "" || strings.ContainsAny(c.ID, " \t") {
			return fmt.Errorf("command %d: invalid id %q", i, c.ID)
		}
		if seen[c.ID] {
			return fmt.Errorf("duplicate command %q", c.ID)
		}
		seen[c.ID] = true
		if c.Title == "" {
			return fmt.Errorf("%s: missing title", c.ID)
		}
		n := 0
		for _, set := range []bool{c.Run.UI != "", c.Run.Toggle != "", len(c.Run.CLI) > 0, c.Run.Config != ""} {
			if set {
				n++
			}
		}
		if n != 1 {
			return fmt.Errorf("%s: run needs exactly one of ui, toggle, cli, config", c.ID)
		}
		if c.Run.Map != nil && c.Run.Config == "" {
			return fmt.Errorf("%s: map is only valid with config", c.ID)
		}
		a := c.Arg
		if a == nil {
			if c.Run.Config != "" {
				return fmt.Errorf("%s: a config command needs an argument", c.ID)
			}
			continue
		}
		switch a.Kind {
		case ArgNone:
		case ArgEnum:
			if len(a.Values) == 0 {
				return fmt.Errorf("%s: enum argument without values", c.ID)
			}
			if a.Default != "" && !contains(a.Values, a.Default) {
				return fmt.Errorf("%s: default %q is not one of the values", c.ID, a.Default)
			}
			for k := range c.Run.Map {
				if !contains(a.Values, k) {
					return fmt.Errorf("%s: map key %q is not one of the values", c.ID, k)
				}
			}
		case ArgNumber:
			if a.Min != nil && a.Max != nil && *a.Min > *a.Max {
				return fmt.Errorf("%s: min > max", c.ID)
			}
		case ArgPreset:
		default:
			return fmt.Errorf("%s: unknown argument kind %q", c.ID, a.Kind)
		}
	}
	return nil
}

// Localize sets Label/Help from a translation table (nil: the keys).
func (r *Registry) Localize(tr map[string]string) {
	for i := range r.Commands {
		c := &r.Commands[i]
		c.Label = lookup(tr, c.Title)
		c.Help = lookup(tr, c.Description)
	}
}

func lookup(tr map[string]string, key string) string {
	if s, ok := tr[key]; ok && s != "" {
		return s
	}
	return key
}

// Find returns the command with that id (case-insensitive).
func (r *Registry) Find(id string) (*Command, bool) {
	id = strings.ToLower(strings.TrimSpace(id))
	for i := range r.Commands {
		if strings.ToLower(r.Commands[i].ID) == id {
			return &r.Commands[i], true
		}
	}
	return nil, false
}

// IDs lists the command ids in registry order.
func (r *Registry) IDs() []string {
	out := make([]string, 0, len(r.Commands))
	for _, c := range r.Commands {
		out = append(out, c.ID)
	}
	return out
}

// TakesArg reports whether the command accepts an argument.
func (c *Command) TakesArg() bool { return c.Arg != nil && c.Arg.Kind != ArgNone }

// Usage is a one-line synopsis ("glass <0..1>", "wallpaper [random|next|previous]").
func (c *Command) Usage() string {
	if !c.TakesArg() {
		return c.ID
	}
	var spec string
	switch c.Arg.Kind {
	case ArgEnum:
		spec = strings.Join(c.Arg.Values, "|")
	case ArgNumber:
		spec = rangeText(c.Arg)
	case ArgPreset:
		spec = "preset name"
	}
	if c.Arg.Required {
		return c.ID + " <" + spec + ">"
	}
	return c.ID + " [" + spec + "]"
}

func rangeText(a *Arg) string {
	switch {
	case a.Min != nil && a.Max != nil:
		return num(*a.Min) + ".." + num(*a.Max)
	case a.Min != nil:
		return ">=" + num(*a.Min)
	case a.Max != nil:
		return "<=" + num(*a.Max)
	}
	return "number"
}

func num(f float64) string { return strconv.FormatFloat(f, 'f', -1, 64) }

// ResolveArg validates a raw argument (applying the default) and returns
// the canonical form ("" when the command takes none).
func (c *Command) ResolveArg(raw string) (string, error) {
	raw = strings.TrimSpace(raw)
	if !c.TakesArg() {
		if raw != "" {
			return "", fmt.Errorf("%s takes no argument", c.ID)
		}
		return "", nil
	}
	a := c.Arg
	if raw == "" {
		raw = a.Default
	}
	if raw == "" {
		if a.Required {
			return "", fmt.Errorf("usage: %s", c.Usage())
		}
		return "", nil
	}
	switch a.Kind {
	case ArgEnum:
		for _, v := range a.Values {
			if strings.EqualFold(v, raw) {
				return v, nil
			}
		}
		return "", fmt.Errorf("%s: %q is not one of %s", c.ID, raw, strings.Join(a.Values, ", "))
	case ArgNumber:
		f, err := strconv.ParseFloat(strings.ReplaceAll(raw, ",", "."), 64)
		if err != nil {
			return "", fmt.Errorf("%s: %q is not a number", c.ID, raw)
		}
		if (a.Min != nil && f < *a.Min) || (a.Max != nil && f > *a.Max) {
			return "", fmt.Errorf("%s: %s is out of range %s", c.ID, num(f), rangeText(a))
		}
		return num(f), nil
	}
	return raw, nil
}

// Plan is the resolved action of one invocation.
type Plan struct {
	Kind  string   // ui | toggle | cli | config
	Value string   // ui.run / ui.toggle command
	Args  []string // cli arguments after the app binary
	Key   string   // config key
	// ConfigValue is the mapped value, or the canonical argument string
	// (parsed against the catalog type by the executor).
	ConfigValue any
}

// Plan resolves a command invocation with its raw argument.
func (c *Command) Plan(raw string) (Plan, error) {
	arg, err := c.ResolveArg(raw)
	if err != nil {
		return Plan{}, err
	}
	expand := func(s string) string { return strings.ReplaceAll(s, "{arg}", arg) }
	switch {
	case c.Run.UI != "":
		return Plan{Kind: KindUI, Value: expand(c.Run.UI)}, nil
	case c.Run.Toggle != "":
		return Plan{Kind: KindToggle, Value: expand(c.Run.Toggle)}, nil
	case len(c.Run.CLI) > 0:
		args := make([]string, 0, len(c.Run.CLI))
		for _, a := range c.Run.CLI {
			e := expand(a)
			if e == "" && strings.Contains(a, "{arg}") {
				continue
			}
			args = append(args, e)
		}
		return Plan{Kind: KindCLI, Args: args}, nil
	}
	var v any = arg
	if c.Run.Map != nil {
		mv, ok := c.Run.Map[arg]
		if !ok {
			return Plan{}, fmt.Errorf("%s: no value for %q", c.ID, arg)
		}
		v = mv
	}
	return Plan{Kind: KindConfig, Key: c.Run.Config, ConfigValue: v}, nil
}

// UICommands lists every ui.run / ui.toggle command the registry can send
// (enum arguments expanded), sorted; used to check the registry against
// the shell's command switch.
func (r *Registry) UICommands() (run, toggle []string) {
	add := func(dst *[]string, tpl string, a *Arg) {
		if strings.Contains(tpl, "{arg}") && a != nil && a.Kind == ArgEnum {
			for _, v := range a.Values {
				*dst = append(*dst, strings.ReplaceAll(tpl, "{arg}", v))
			}
			return
		}
		*dst = append(*dst, tpl)
	}
	for _, c := range r.Commands {
		if c.Run.UI != "" {
			add(&run, c.Run.UI, c.Arg)
		}
		if c.Run.Toggle != "" {
			add(&toggle, c.Run.Toggle, c.Arg)
		}
	}
	sort.Strings(run)
	sort.Strings(toggle)
	return run, toggle
}

// Executor performs plans; every side effect is injected.
type Executor struct {
	// Call performs a daemon IPC call (ui.run / ui.toggle).
	Call func(method string, params any) error
	// Exec runs the app binary with args and returns its output.
	Exec func(args []string) (string, error)
	// SetConfig validates and writes a config key; value is a mapped
	// value or the argument string. Returns a human summary.
	SetConfig func(key string, value any) (string, error)
}

// Do executes a plan and returns a short human-readable result.
func (e Executor) Do(p Plan) (string, error) {
	switch p.Kind {
	case KindUI, KindToggle:
		if e.Call == nil {
			return "", errors.New("no daemon connection")
		}
		method := "ui.run"
		if p.Kind == KindToggle {
			method = "ui.toggle"
		}
		if err := e.Call(method, map[string]any{"command": p.Value}); err != nil {
			return "", err
		}
		return method + " " + p.Value, nil
	case KindCLI:
		if e.Exec == nil {
			return "", errors.New("cannot run commands")
		}
		return e.Exec(p.Args)
	case KindConfig:
		if e.SetConfig == nil {
			return "", errors.New("cannot write config")
		}
		return e.SetConfig(p.Key, p.ConfigValue)
	}
	return "", fmt.Errorf("unknown plan kind %q", p.Kind)
}

// Run resolves and executes command id with a raw argument.
func (r *Registry) Run(e Executor, id, raw string) (string, error) {
	c, ok := r.Find(id)
	if !ok {
		return "", fmt.Errorf("unknown command %q (commands: %s)", id, strings.Join(r.IDs(), ", "))
	}
	p, err := c.Plan(raw)
	if err != nil {
		return "", err
	}
	return e.Do(p)
}

func contains(list []string, s string) bool {
	for _, v := range list {
		if v == s {
			return true
		}
	}
	return false
}

// View is the public description of a command (CLI --json, MCP listing).
type View struct {
	ID          string `json:"id"`
	Title       string `json:"title"`
	Description string `json:"description,omitempty"`
	Usage       string `json:"usage"`
	Keywords    string `json:"keywords,omitempty"`
	Arg         *Arg   `json:"arg,omitempty"`
}

// Views describes every command in registry order.
func (r *Registry) Views() []View {
	out := make([]View, 0, len(r.Commands))
	for i := range r.Commands {
		c := &r.Commands[i]
		help := c.Help
		if help == c.Description {
			help = ""
		}
		out = append(out, View{ID: c.ID, Title: c.Label, Description: help, Usage: c.Usage(), Keywords: c.Keywords, Arg: c.Arg})
	}
	return out
}
