package binds

import (
	"slices"
	"strings"

	"yozakura/backend/pkg/brand"
)

// A workaround is a bindable command for something the action catalog has
// no action for. Commands go through yozd where they can, so they work on
// every compositor (and on Hyprland with a Lua config, where the legacy
// `hyprctl dispatch <name>` syntax is rejected).
type workaround struct {
	id, title, keywords string
	command             string
	compositors         []string // nil = any
}

var workarounds = []workaround{
	{id: "keyboard-layout-next", title: "Switch keyboard layout (next)",
		keywords: "keyboard layout language switch next xkb раскладка язык переключить клавиатура следующая",
		command:  brand.DaemonCommand("system", "switch-keyboard-layout", "next")},
	{id: "keyboard-layout-prev", title: "Switch keyboard layout (previous)",
		keywords: "keyboard layout language switch previous xkb раскладка язык предыдущая",
		command:  brand.DaemonCommand("system", "switch-keyboard-layout", "prev")},
	{id: "mic-mute", title: "Mute microphone",
		keywords: "microphone mic mute unmute toggle микрофон выключить заглушить",
		command:  "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"},
	{id: "color-picker", title: "Pick a color from the screen",
		keywords: "color colour picker pipette eyedropper цвет пипетка",
		command:  brand.Command("colorpicker")},
	{id: "suspend", title: "Suspend (sleep)",
		keywords: "suspend sleep сон спящий режим", command: brand.Command("suspend")},
	{id: "window-pin", title: "Pin window (show on every workspace)",
		keywords: "pin sticky window all workspaces закрепить окно", command: brand.DaemonCommand("window", "pin"),
		compositors: []string{"hyprland"}},
	{id: "group-toggle", title: "Toggle window group (tabs)",
		keywords: "group tabbed tabs window toggle группа вкладки окна", command: brand.DaemonCommand("window", "toggle-group"),
		compositors: []string{"hyprland"}},
	{id: "group-next", title: "Next window in group",
		keywords: "group tab next window группа вкладка следующая", command: brand.DaemonCommand("window", "group-nav", "f"),
		compositors: []string{"hyprland"}},
	{id: "group-prev", title: "Previous window in group",
		keywords: "group tab previous window группа вкладка предыдущая", command: brand.DaemonCommand("window", "group-nav", "b"),
		compositors: []string{"hyprland"}},
	{id: "tiling-layout-next", title: "Next tiling layout",
		keywords: "tiling layout next cycle dwindle master scrolling monocle раскладка окон layout следующая",
		command:  brand.DaemonCommand("layout", "next", "1")},
}

// Workarounds suggests commands to bind when the catalog has no action for
// what the query asks: compositor features through yozd, a few system
// commands, an installed app (apps.launch) or any shell command
// (command.run). Each result is a ready binds_set action.
func (a *Advisor) Workarounds(text string) []Result {
	q := parseQuery(text)
	if len(q) == 0 {
		return []Result{}
	}
	out := []Result{}
	for _, w := range workarounds {
		if w.compositors != nil && a.CompositorName != "" && !slices.Contains(w.compositors, a.CompositorName) {
			continue
		}
		hay := addWords(addWords(nil, w.title, 1), w.keywords, 0.9)
		s := q.score(hay)
		if s < minScore {
			continue
		}
		note := "runs `" + w.command + "`"
		if w.compositors != nil {
			note += " (" + strings.Join(w.compositors, ", ") + " only)"
		}
		out = append(out, Result{Kind: KindWorkaround, ID: w.id, Label: w.title, Group: "apps", Score: s,
			Action: ActionRef{ID: "command.run", Args: map[string]any{"command": w.command}}, Note: note, Compositors: w.compositors})
	}
	return out
}

// FallbackHints are the generic ways to bind anything the search did not
// find, for the caller to offer (never chosen automatically).
func FallbackHints() []string {
	return []string{
		"Bind any shell command: action {\"id\":\"command.run\",\"args\":{\"command\":\"...\"}} (runs through sh in the compositor).",
		"Open an installed app: action {\"id\":\"apps.launch\",\"args\":{\"app\":\"<desktop id>\"}} (binds_search finds installed apps).",
		"Several steps on one key: save them as a routine (routines tools, when available), then bind the routine.",
	}
}
