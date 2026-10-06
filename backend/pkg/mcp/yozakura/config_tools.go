package yozakura

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	"yozakura/backend/pkg/catalog"
	"yozakura/backend/pkg/mcp"
)

// The config tools share the settings catalog (assets/schema, see package
// catalog) with `yozakura config`: same descriptions, same validation, same
// writes (atomic, order-preserving, hot-applied by the shell).

func (d Deps) catalog() (*catalog.Catalog, *catalog.Store, error) {
	if d.ConfigFile == nil {
		return nil, nil, fmt.Errorf("no config path resolver")
	}
	cat, err := catalog.Load(d.ShellSource)
	if err != nil {
		return nil, nil, err
	}
	return cat, &catalog.Store{Cat: cat, File: d.ConfigFile}, nil
}

// fullKey joins the optional domain argument and a key; without a domain
// the key must be fully qualified ("bar.position").
func fullKey(domain, key string) string {
	key = catalog.NormalizeKey(key)
	switch {
	case domain == "":
		return key
	case key == "":
		return domain
	}
	return domain + "." + key
}

const keyProp = `"domain":{"type":"string","description":"Config domain (bar, theme, notch, dock, compositor, ...). Optional when key is fully qualified."},"key":{"type":"string","description":"Dotted key inside the domain (\"position\", \"layout.style\") or fully qualified (\"bar.position\"); array items as key.N."}`

func configTools(d Deps) []mcp.ToolDef {
	return []mcp.ToolDef{
		define("config_schema", "List config keys",
			`Discover the shell's settings catalog. Without arguments: the config domains with a description and their top-level keys. With "domain": every leaf key of that domain (relative dotted path) with type, default, title, description and allowed values/range; "prefix" narrows to a sub-tree (e.g. domain "bar", prefix "activities"). Use config_search to find a key by words and config_describe for one key in detail. Never guess key names.`,
			`{"type":"object","properties":{"domain":{"type":"string","description":"Config domain, e.g. \"bar\", \"theme\", \"notch\"."},"prefix":{"type":"string","description":"Optional dotted sub-key to list, e.g. \"activities\"."}},"additionalProperties":false}`,
			toolOpts{readOnly: true}, d.configSchema),
		define("config_search", "Search settings",
			`Find settings by natural words ("bar height", "transparency", "rounded corners", "clock 12h"). Ranks keys by key name, title, description, settings keywords and allowed values; returns fully qualified keys with title and description. Use it before config_set when you do not know the exact key.`,
			`{"type":"object","properties":{"query":{"type":"string","description":"Words to search for."},"limit":{"type":"integer","minimum":1,"maximum":100,"description":"Most results (default 15)."}},"required":["query"],"additionalProperties":false}`,
			toolOpts{readOnly: true}, d.configSearch),
		define("config_describe", "Describe a setting",
			`Everything about one config key: title, description, type, default, current value (and whether the config file sets it), allowed values with labels, numeric range and unit, the settings page it lives on and when it is shown (visibleWhen). Call it before changing a key you have not used yet.`,
			`{"type":"object","properties":{`+keyProp+`},"required":["key"],"additionalProperties":false}`,
			toolOpts{readOnly: true}, d.configDescribe),
		define("config_get", "Read config",
			`Read the current value of a config key (or a whole domain when "key" is omitted). Missing keys report their default (isDefault true). Examples: {"key":"bar.position"} -> "top"; {"domain":"theme","key":"roundness"} -> 16.`,
			`{"type":"object","properties":{`+keyProp+`},"additionalProperties":false}`,
			toolOpts{readOnly: true}, d.configGet),
		define("config_set", "Change config",
			`Change a config key; the shell applies it live and it persists. The value is validated against the catalog: JSON type, allowed values (enum), numeric range, array items; objects may be partial (merged member by member). Returns each changed key with old and new value. Examples: {"key":"bar.position","value":"bottom"}, {"domain":"theme","key":"roundness","value":12}, {"key":"bar.layout.left","value":["launcher","workspaces","clock"]}, {"key":"bar.activities","value":{"enabled":false}}. Invalid keys get "did you mean" suggestions.`,
			`{"type":"object","properties":{`+keyProp+`,"value":{"description":"New value (JSON) of the key's type."},"force":{"type":"boolean","description":"Skip enum/range checks (type is still checked). Only when the user explicitly asks for an out-of-range value."},"replace":{"type":"boolean","description":"keyboard.* only: when the compositor's keyboard settings cannot be read, replace them anyway (only if the user agreed)."}},"required":["key","value"],"additionalProperties":false}`,
			toolOpts{idempotent: true}, d.configSet),
	}
}

func (d Deps) configSchema(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ Domain, Prefix string }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	cat, _, err := d.catalog()
	if err != nil {
		return nil, err
	}
	if a.Domain == "" {
		type dom struct {
			Domain      string   `json:"domain"`
			Description string   `json:"description,omitempty"`
			Leaves      int      `json:"leafKeys"`
			Keys        []string `json:"keys"`
		}
		var out []dom
		for _, dm := range cat.Domains() {
			out = append(out, dom{dm.Name, dm.Description, dm.Keys, cat.TopKeys(dm.Name)})
		}
		return mcp.JSONResult(map[string]any{"domains": out}), nil
	}
	prefix := fullKey(a.Domain, a.Prefix)
	if !cat.HasDomain(prefix) {
		if _, err := cat.Lookup(prefix); err != nil {
			return nil, err
		}
	}
	type key struct {
		Key         string   `json:"key"`
		Type        string   `json:"type"`
		Default     any      `json:"default"`
		Title       string   `json:"title,omitempty"`
		Description string   `json:"description,omitempty"`
		Enum        []any    `json:"enum,omitempty"`
		Min         *float64 `json:"minimum,omitempty"`
		Max         *float64 `json:"maximum,omitempty"`
		Unit        string   `json:"unit,omitempty"`
	}
	var keys []key
	for _, e := range cat.Keys(prefix, true) {
		def := e.Default
		if arr, ok := def.([]any); ok && len(catalog.Compact(arr)) > 200 {
			def = fmt.Sprintf("[%d items]", len(arr))
		}
		keys = append(keys, key{strings.Join(e.Path, "."), e.Type, def, e.Title, e.Description, e.Enum, e.Min, e.Max, e.Unit})
	}
	return mcp.JSONResult(map[string]any{"domain": a.Domain, "keys": keys}), nil
}

func (d Deps) configSearch(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct {
		Query string
		Limit int
	}
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	if strings.TrimSpace(a.Query) == "" {
		return nil, fmt.Errorf("query is required")
	}
	if a.Limit <= 0 {
		a.Limit = 15
	}
	cat, _, err := d.catalog()
	if err != nil {
		return nil, err
	}
	type hit struct {
		Key         string `json:"key"`
		Type        string `json:"type"`
		Title       string `json:"title,omitempty"`
		Description string `json:"description,omitempty"`
	}
	hits := []hit{}
	for _, h := range cat.Search(a.Query, a.Limit) {
		hits = append(hits, hit{h.Entry.Key, h.Entry.Type, h.Entry.Title, h.Entry.Description})
	}
	return mcp.JSONResult(map[string]any{"query": a.Query, "results": hits}), nil
}

func masked(e *catalog.Entry, v any) any {
	if s, ok := v.(string); ok && e.Secret && s != "" {
		return "********"
	}
	return v
}

// maskSecrets hides credential values inside a domain document.
func maskSecrets(cat *catalog.Catalog, domain string, doc map[string]any) {
	for _, e := range cat.Keys(domain, true) {
		if !e.Secret {
			continue
		}
		m := doc
		for _, p := range e.Path[:len(e.Path)-1] {
			next, ok := m[p].(map[string]any)
			if !ok {
				m = nil
				break
			}
			m = next
		}
		if m != nil {
			last := e.Path[len(e.Path)-1]
			m[last] = masked(e, m[last])
		}
	}
}

func (d Deps) configDescribe(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ Domain, Key string }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	cat, store, err := d.catalog()
	if err != nil {
		return nil, err
	}
	ref, err := cat.Lookup(fullKey(a.Domain, a.Key))
	if err != nil {
		return nil, err
	}
	cur, explicit, err := store.Get(ref.Entry.Key)
	if err != nil {
		return nil, err
	}
	out := map[string]any{"entry": ref.Entry, "current": masked(ref.Entry, cur), "setInFile": explicit, "file": store.File(ref.Entry.Domain)}
	if s := ref.Entry.Settings; s != nil && s.Category != "" {
		out["settingsPage"] = cat.CategoryTitle(s.Category)
	}
	return mcp.JSONResult(out), nil
}

func (d Deps) configGet(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ Domain, Key string }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	key := fullKey(a.Domain, a.Key)
	if key == "" {
		return nil, fmt.Errorf("key (or domain) is required")
	}
	cat, store, err := d.catalog()
	if err != nil {
		return nil, err
	}
	if cat.HasDomain(key) {
		cur, err := store.Current(key)
		if err != nil {
			return nil, err
		}
		maskSecrets(cat, key, cur)
		return mcp.JSONResult(map[string]any{"domain": key, "value": cur}), nil
	}
	ref, err := cat.Lookup(key)
	if err != nil {
		return nil, err
	}
	v, explicit, err := store.Get(key)
	if err != nil {
		return nil, err
	}
	return mcp.JSONResult(map[string]any{"key": catalog.NormalizeKey(key), "value": masked(ref.Entry, v), "isDefault": !explicit}), nil
}

func (d Deps) configSet(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct {
		Domain  string
		Key     string
		Value   json.RawMessage
		Force   bool
		Replace bool
	}
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	if a.Key == "" || len(a.Value) == 0 {
		return nil, fmt.Errorf("key and value are required")
	}
	var value any
	if err := json.Unmarshal(a.Value, &value); err != nil {
		return nil, fmt.Errorf("value is not valid JSON: %v", err)
	}
	_, store, err := d.catalog()
	if err != nil {
		return nil, err
	}
	key := fullKey(a.Domain, a.Key)
	// keyboard: the first change takes the compositor's settings over, in
	// the same write (ruling K-1)
	handled, changes, err := KeyboardConfigSet(store, d.callerOrNil(), key, func(base any) (any, error) {
		if ref, err := store.Cat.Lookup(key); err == nil && ref.Index >= 0 {
			return ItemAt(base, ref.Index, value)
		}
		return value, nil
	}, a.Force, a.Replace)
	if !handled && err == nil {
		changes, err = store.Set(key, value, a.Force)
	}
	if err != nil {
		return nil, err
	}
	if changes == nil {
		changes = []catalog.Change{}
	}
	return mcp.JSONResult(map[string]any{"ok": true, "changed": changes}), nil
}
