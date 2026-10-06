package yozakura

import (
	"context"
	"encoding/json"
	"fmt"
	"sort"
	"strings"

	"yozakura/backend/pkg/mcp"
	"yozakura/backend/pkg/svc/extras"
)

// Extras tools drive the daemon's "extras" service: the catalog of apps and
// tools (browsers, AI agents, media, games ...) the shell can install.

func extrasTools(d Deps) []mcp.ToolDef {
	return []mcp.ToolDef{
		define("extras_list", "List installable extras",
			`List the apps and tools the shell can install (the Extras catalog): id, name, category, description, state (installed | missing | installing | failed | unavailable), where an installed one comes from (pkg, flatpak, npm, bin) and, for failed or unavailable ones, a reason (needs_flatpak, needs_aur_helper, only_distro, needs_sync, network, ...). "category" filters by category id, "state" by state. Call it before extras_install to find ids.`,
			`{"type":"object","properties":{"category":{"type":"string"},"state":{"type":"string","enum":["installed","missing","installing","failed","unavailable"]}},"additionalProperties":false}`,
			toolOpts{readOnly: true}, d.extrasList),
		define("extras_install", "Install extras",
			`Install catalog entries by id (see extras_list), e.g. ["steam","discord","claude-code"]. Requirements are installed first and installed entries are skipped. Jobs run one after another in the background and may ask the user for their password (polkit); the call returns the queued jobs at once and extras_list shows progress (state "installing"). Some entries need the pacman [multilib] repo: the call then fails with needs_confirm; only repeat it with "confirmMultilib": true after the user agreed to enabling it. Entries that can't be installed here fail with "unavailable" and a reason per id.`,
			`{"type":"object","properties":{"ids":{"type":"array","items":{"type":"string"},"minItems":1},"confirmMultilib":{"type":"boolean","default":false}},"required":["ids"],"additionalProperties":false}`,
			toolOpts{openWorld: true}, d.extrasInstall),
	}
}

func (d Deps) extrasList(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ Category, State string }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	raw, err := d.call("extras.catalog", nil)
	if err != nil {
		return nil, err
	}
	var cat struct {
		Entries []struct {
			ID, Name, Category, Description string
			Recommended, Hidden             bool
		} `json:"entries"`
		Platform map[string]any `json:"platform"`
	}
	if err := json.Unmarshal(raw, &cat); err != nil {
		return nil, fmt.Errorf("extras.catalog: %v", err)
	}
	raw, err = d.call("extras.status", nil)
	if err != nil {
		return nil, err
	}
	var st map[string]extras.Status
	if err := json.Unmarshal(raw, &st); err != nil {
		return nil, fmt.Errorf("extras.status: %v", err)
	}
	list := []map[string]any{}
	for _, e := range cat.Entries {
		s := st[e.ID]
		if e.Hidden || (a.Category != "" && e.Category != a.Category) || (a.State != "" && string(s.State) != a.State) {
			continue
		}
		m := map[string]any{"id": e.ID, "name": e.Name, "category": e.Category, "description": e.Description,
			"state": string(s.State), "recommended": e.Recommended}
		if s.Source != "" {
			m["source"] = s.Source
		}
		if s.Reason != "" {
			m["reason"] = s.Reason
		}
		list = append(list, m)
	}
	sort.SliceStable(list, func(i, j int) bool { return list[i]["category"].(string) < list[j]["category"].(string) })
	return mcp.JSONResult(map[string]any{"entries": list, "platform": cat.Platform}), nil
}

func (d Deps) extrasInstall(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct {
		IDs             []string `json:"ids"`
		ConfirmMultilib bool     `json:"confirmMultilib"`
	}
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	if len(a.IDs) == 0 {
		return nil, fmt.Errorf("ids is required")
	}
	raw, err := d.call("extras.install", map[string]any{"ids": a.IDs, "confirmMultilib": a.ConfirmMultilib})
	if err != nil {
		return nil, extrasInstallErr(err)
	}
	var res map[string]any
	if err := json.Unmarshal(raw, &res); err != nil {
		return nil, fmt.Errorf("extras.install: %v", err)
	}
	if jobs, _ := res["jobs"].([]any); len(jobs) == 0 {
		res["message"] = "nothing to install: everything is already installed"
	} else {
		res["message"] = "queued; installs run one after another and may ask for the user's password"
	}
	return mcp.JSONResult(res), nil
}

// extrasInstallErr turns the service's coded errors into text a model can
// act on.
func extrasInstallErr(err error) error {
	code, data := extras.ParseError(err.Error())
	switch code {
	case extras.CodeNeedsConfirm:
		return fmt.Errorf("needs_confirm: %v need the pacman [multilib] repo, which this would enable (system change). Ask the user, then call again with confirmMultilib true", data["entries"])
	case extras.CodeUnavailable:
		reasons, _ := data["reasons"].(map[string]any)
		parts := make([]string, 0, len(reasons))
		for id, r := range reasons {
			parts = append(parts, fmt.Sprintf("%s: %v", id, r))
		}
		sort.Strings(parts)
		return fmt.Errorf("unavailable on this system (%s)", strings.Join(parts, ", "))
	}
	return err
}
