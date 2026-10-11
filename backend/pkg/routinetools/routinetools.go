// Package routinetools is the routine-facing metadata of the built-in MCP
// tools: which of them make sense as a routine step, how they are grouped
// for the editor and how a step reads as a sentence. It holds data only
// (the JSON schemas stay in backend/pkg/mcp/yozakura, which joins both in
// RoutineTools); the shell translates titles, descriptions and summaries
// itself (translations "routines.tool.<id>[.desc|.summary]").
package routinetools

import (
	"fmt"
	"strings"
)

// Categories in the order the picker shows them.
var Categories = []string{"media", "display", "focus", "apps", "network", "shell", "notes"}

// Meta describes one routine-usable tool.
type Meta struct {
	Category string
	// Summary is the English sentence template of a step (see Render).
	Summary string
}

// Tools are the tools offered as routine steps: actions with an effect.
// Everything else the MCP server exposes is read-only, edits keybinds /
// presets / notes in ways that need review, or is listed in Excluded.
var Tools = map[string]Meta{
	"media_control":            {"media", "{action|play=Play media|pause=Pause media|play-pause=Play or pause media|next=Skip to the next track|previous=Go back to the previous track|stop=Stop media}"},
	"volume_set":               {"media", "[Set volume to {percent}%][, change volume by {delta}%][, {mute|true=mute|false=unmute|toggle=toggle mute}]"},
	"audio_output_set":         {"media", "Switch sound output to {output}"},
	"brightness_set":           {"display", "[Set brightness to {percent}%][Change brightness by {delta}%]"},
	"nightlight_set":           {"display", "{enabled|true=Turn on|false=Turn off|unset=Toggle} night light[ at {temperature} K]"},
	"caffeine_set":             {"display", "{enabled|true=Turn on|false=Turn off|unset=Toggle} keeping the screen awake"},
	"wallpaper_set":            {"display", "Set wallpaper {path}"},
	"screenshot":               {"display", "Take a screenshot ({mode|full=whole screen|region=region|window=window|unset=whole screen})"},
	"dnd_set":                  {"focus", "{enabled|true=Turn on|false=Turn off|unset=Toggle} Do Not Disturb"},
	"focus_start":              {"focus", "Start focus mode[ for {minutes} min]"},
	"focus_stop":               {"focus", "Stop focus mode"},
	"notification_send":        {"focus", "Show notification \"{summary}\""},
	"timer_start":              {"notes", "Start a timer[ {duration}][ \"{name}\"]"},
	"timer_control":            {"notes", "{action|pause=Pause|resume=Resume|add=Add time to|reset=Reset|cancel=Cancel|dismiss=Dismiss} the timer[ {id}]"},
	"stopwatch_control":        {"notes", "{action|start=Start|pause=Pause|resume=Resume|toggle=Start or pause|lap=Lap|reset=Reset|status=Check} the stopwatch"},
	"reminder_add":             {"notes", "Remind me {when}[: {message}]"},
	"reminder_cancel":          {"notes", "Cancel reminder {id}"},
	"notes_create":             {"notes", "Create note \"{title}\""},
	"notes_append":             {"notes", "Add to note {id}"},
	"app_launch":               {"apps", "Open {app}[ on workspace {workspace}]"},
	"app_close":                {"apps", "Close [{app}||{title}||{id}||the window]"},
	"window_focus":             {"apps", "Focus [{app}||{title}||{id}||the window]"},
	"window_move_to_workspace": {"apps", "Move [{app}||the window] to workspace {workspace}"},
	"workspace_switch":         {"apps", "Switch to workspace {workspace}"},
	"special_open":             {"apps", "Open the special workspace {name}"},
	"clipboard_write":          {"apps", "Copy text to the clipboard"},
	"wifi_toggle":              {"network", "{enabled|true=Turn on|false=Turn off|unset=Toggle} Wi-Fi"},
	"wifi_connect":             {"network", "Connect to Wi-Fi {ssid}"},
	"bluetooth_connect":        {"network", "Connect Bluetooth device {device}"},
	"bluetooth_disconnect":     {"network", "Disconnect Bluetooth device {device}"},
	"keyboard_set":             {"network", "Change keyboard layouts"},
	"preset_apply":             {"shell", "Apply preset {name}"},
	"preset_apply_part":        {"shell", "Apply {kind|layout=layout|style=style|palette=palette} {name}"},
	"shell_command":            {"shell", "Run shell feature {command}[ {arg}]"},
	"shell_toggle":             {"shell", "Toggle the {panel} panel"},
	"config_set":               {"shell", "Set {key}"},
	"term_set":                 {"shell", "Change the terminal prompt[ to {preset}]"},
}

// Excluded are the effectful tools that deliberately are not routine
// steps (the audit test makes every new tool pick a side).
var Excluded = map[string]string{
	"config_schema": "read", "preset_save": "creates a preset", "preset_mix": "builds a preset",
	"preset_duplicate": "preset management", "preset_rename": "preset management", "preset_delete": "destructive",
	"preset_export": "file output", "preset_import": "file input", "special_add": "workspace management",
	"special_update": "workspace management", "special_remove": "workspace management",
	"special_app_add": "workspace management", "task_create": "coding agent task", "binds_set": "keybind management",
	"binds_remove": "keybind management", "binds_undo": "keybind management", "routine_run": "routines do not nest here",
	"routine_save": "edits routines", "routine_delete": "edits routines", "notes_delete": "destructive",
	"notes_restore": "note management", "extras_install": "installs software", "displays_apply": "needs keep/revert",
	"displays_confirm": "needs keep/revert",
}

// Lookup returns the metadata of a routine-usable tool.
func Lookup(name string) (Meta, bool) {
	m, ok := Tools[name]
	return m, ok
}

// Label is the English sentence of a tool step ("Turn on Do Not Disturb");
// tools without metadata read "Tool <name>".
func Label(tool string, args map[string]any) string {
	m, ok := Tools[tool]
	if !ok {
		return "Tool " + tool
	}
	if s := Render(m.Summary, args); s != "" {
		return s
	}
	return capitalize(strings.ReplaceAll(tool, "_", " "))
}

// Render fills a summary template. {key} is the argument's value; {key|a=x|b=y|*=z}
// picks by value (booleans are "true"/"false", a missing argument "unset");
// [ ... ] is dropped when an argument inside is missing and, with `||`, holds
// alternatives ("[{app}||the window]"). A leading ", " is trimmed and the
// first letter capitalised.
func Render(tpl string, args map[string]any) string {
	var out strings.Builder
	for i := 0; i < len(tpl); {
		switch tpl[i] {
		case '[':
			end := strings.IndexByte(tpl[i:], ']')
			if end < 0 {
				out.WriteString(tpl[i:])
				i = len(tpl)
				break
			}
			out.WriteString(optional(tpl[i+1:i+end], args))
			i += end + 1
		case '{':
			end := strings.IndexByte(tpl[i:], '}')
			if end < 0 {
				out.WriteString(tpl[i:])
				i = len(tpl)
				break
			}
			v, _ := placeholder(tpl[i+1:i+end], args)
			out.WriteString(v)
			i += end + 1
		default:
			out.WriteByte(tpl[i])
			i++
		}
	}
	s := strings.TrimSpace(strings.Join(strings.Fields(out.String()), " "))
	s = strings.TrimSpace(strings.TrimPrefix(s, ","))
	return capitalize(s)
}

// optional renders a [..] segment: its text when every placeholder in it
// has a value; for "a|b" the first alternative that does.
func optional(seg string, args map[string]any) string {
	for _, alt := range strings.Split(seg, "||") {
		if s, ok := renderAll(alt, args); ok {
			return s
		}
	}
	return ""
}

// renderAll renders text with placeholders; ok is false when one is unset.
func renderAll(text string, args map[string]any) (string, bool) {
	var out strings.Builder
	for i := 0; i < len(text); {
		if text[i] != '{' {
			out.WriteByte(text[i])
			i++
			continue
		}
		end := strings.IndexByte(text[i:], '}')
		if end < 0 {
			out.WriteString(text[i:])
			break
		}
		v, set := placeholder(text[i+1:i+end], args)
		if !set {
			return "", false
		}
		out.WriteString(v)
		i += end + 1
	}
	return out.String(), true
}

// placeholder resolves "key" or "key|v=text|*=text".
func placeholder(spec string, args map[string]any) (string, bool) {
	parts := strings.Split(spec, "|")
	key := parts[0]
	val, set := "unset", false
	if v, ok := args[key]; ok && v != nil && fmt.Sprint(v) != "" {
		val, set = fmt.Sprint(v), true
	}
	if len(parts) == 1 {
		if !set {
			return "", false
		}
		return val, true
	}
	def := ""
	for _, p := range parts[1:] {
		k, text, ok := strings.Cut(p, "=")
		if !ok {
			continue
		}
		if k == val {
			return text, true
		}
		if k == "*" {
			def = text
		}
	}
	if def != "" {
		return def, set
	}
	return val, set
}

func capitalize(s string) string {
	if s == "" {
		return s
	}
	r := []rune(s)
	if r[0] >= 'a' && r[0] <= 'z' {
		r[0] -= 32
	}
	return string(r)
}
