package yozakura

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestNewToolGroupsRegistered(t *testing.T) {
	d, _, _ := newDeps(t)
	names := map[string]bool{}
	for _, td := range Tools(d) {
		names[td.Tool.Name] = true
	}
	for _, n := range []string{"routines_list", "routine_run", "routine_save", "routine_delete",
		"notes_search", "notes_read", "notes_create", "notes_append", "apps_find", "app_launch", "app_close",
		"system_info", "network_status", "bluetooth_status", "bluetooth_connect", "bluetooth_disconnect",
		"wifi_connect", "wifi_toggle", "audio_output_set", "brightness_get", "brightness_set",
		"nightlight_set", "caffeine_set", "focus_start", "focus_stop", "screen_look"} {
		assert.True(t, names[n], n)
	}
	ro := ReadOnlyToolNames()
	for _, n := range []string{"routines_list", "notes_search", "notes_read", "apps_find", "system_info",
		"network_status", "bluetooth_status", "brightness_get", "screen_look"} {
		assert.Contains(t, ro, n)
	}
	for _, n := range []string{"routine_save", "routine_delete", "app_close", "notes_append", "wifi_toggle"} {
		assert.NotContains(t, ro, n)
	}
}

func TestRoutineTools(t *testing.T) {
	d, _, ipc := newDeps(t)
	ipc.result["routines.list"] = `{"routines":[{"id":"morning","name":"Morning","icon":"sun","steps":[{"kind":"tool","tool":"dnd_set","args":{"enabled":false}},{"kind":"delay","ms":1000}]}]}`
	m := structured(t, callTool(t, d, "routines_list", `{}`))
	r := m["routines"].([]any)[0].(map[string]any)
	assert.Equal(t, "morning", r["id"])
	assert.Equal(t, "Tool dnd_set", r["steps"].([]any)[0].(map[string]any)["label"])

	// New routine: undo deletes it, and the result says how to bind it.
	ipc.result["routines.save"] = `{"routine":{"id":"focus","name":"Focus","steps":[{"kind":"tool","tool":"focus_start"}]},"previous":null}`
	m = structured(t, callTool(t, d, "routine_save", `{"name":"Focus","steps":[{"kind":"tool","tool":"focus_start"}]}`))
	assert.Equal(t, map[string]any{"tool": "routine_delete", "args": map[string]any{"id": "focus"}}, m["undo"])
	assert.Equal(t, "utilities.routine", m["bindAction"].(map[string]any)["id"])
	last := ipc.calls[len(ipc.calls)-1]
	assert.Equal(t, "routines.save", last.Method)
	assert.NotContains(t, last.Params.(map[string]any), "replace")

	// Updating returns the previous version as the undo.
	ipc.result["routines.save"] = `{"routine":{"id":"focus","name":"Focus","steps":[]},"previous":{"id":"focus","name":"Old","icon":"moon","steps":[{"kind":"delay","ms":5}]}}`
	m = structured(t, callTool(t, d, "routine_save", `{"id":"focus","name":"Focus","steps":[{"kind":"delay","ms":10}]}`))
	u := m["undo"].(map[string]any)
	assert.Equal(t, "routine_save", u["tool"])
	assert.Equal(t, "Old", u["args"].(map[string]any)["name"])
	assert.Equal(t, "focus", ipc.calls[len(ipc.calls)-1].Params.(map[string]any)["replace"])

	// Invalid steps are refused before reaching the daemon.
	n := len(ipc.calls)
	assert.True(t, callTool(t, d, "routine_save", `{"name":"x","steps":[{"kind":"tool","tool":"routine_run"}]}`).IsError)
	assert.Len(t, ipc.calls, n)

	ipc.result["routines.delete"] = `{"routine":{"id":"focus","name":"Focus","icon":"lightning","steps":[{"kind":"delay","ms":10}]}}`
	m = structured(t, callTool(t, d, "routine_delete", `{"id":"focus"}`))
	assert.Equal(t, "routine_save", m["undo"].(map[string]any)["tool"])

	ipc.result["routines.run"] = `{"id":"focus","name":"Focus","ok":false,"steps":[{"index":0,"kind":"tool","label":"Tool x","status":"failed","error":"nope"}]}`
	res := callTool(t, d, "routine_run", `{"id":"focus"}`)
	assert.True(t, res.IsError)
	assert.Contains(t, res.Content[0].Text, "nope")
	assert.Equal(t, true, ipc.calls[len(ipc.calls)-1].Params.(map[string]any)["quiet"])
}
