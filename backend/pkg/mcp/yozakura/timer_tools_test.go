package yozakura

import (
	"encoding/json"
	"testing"

	"yozakura/backend/pkg/mcp"

	"github.com/stretchr/testify/assert"
)

func structured(t *testing.T, res *mcp.CallToolResult) map[string]any {
	t.Helper()
	assert.False(t, res.IsError, "%+v", res.Content)
	var m map[string]any
	if len(res.Content) > 0 {
		assert.NoError(t, json.Unmarshal([]byte(res.Content[0].Text), &m))
	}
	return m
}

func TestTimerToolsAreRegistered(t *testing.T) {
	d, _, _ := newDeps(t)
	names := map[string]bool{}
	for _, td := range Tools(d) {
		names[td.Tool.Name] = true
	}
	for _, n := range []string{"timer_start", "timer_list", "timer_control", "stopwatch_control",
		"reminder_add", "reminder_list", "reminder_cancel"} {
		assert.True(t, names[n], n)
	}
	ro := ReadOnlyToolNames()
	assert.Contains(t, ro, "timer_list")
	assert.NotContains(t, ro, "timer_start")
}

func TestTimerStartAndUndo(t *testing.T) {
	d, _, ipc := newDeps(t)
	ipc.result["timers.start"] = `{"timer":{"id":"t3","name":"tea","state":"running","totalMs":600000,"leftMs":600000,"endsAt":1790000000000}}`
	m := structured(t, callTool(t, d, "timer_start", `{"duration":"10m","name":"tea"}`))
	assert.Equal(t, "timers.start", ipc.calls[0].Method)
	assert.Equal(t, map[string]any{"spec": "10m", "name": "tea"}, ipc.calls[0].Params)
	assert.Equal(t, "10:00", m["timer"].(map[string]any)["left"])
	assert.Equal(t, map[string]any{"tool": "timer_control", "args": map[string]any{"id": "t3", "action": "cancel"}}, m["undo"])

	assert.True(t, callTool(t, d, "timer_start", `{}`).IsError)

	ipc.result["timers.pomodoro"] = `{"timer":{"id":"t4","name":"Pomodoro","state":"running","leftMs":1500000,"pomodoro":{"phase":"work","round":1}}}`
	m = structured(t, callTool(t, d, "timer_start", `{"pomodoro":true,"break":"10m"}`))
	last := ipc.calls[len(ipc.calls)-1]
	assert.Equal(t, "timers.pomodoro", last.Method)
	assert.Equal(t, "10m", last.Params.(map[string]any)["break"])
	assert.Equal(t, "work", m["timer"].(map[string]any)["pomodoro"].(map[string]any)["phase"])
}

func TestTimerControlUndo(t *testing.T) {
	d, _, ipc := newDeps(t)
	ipc.result["timers.pause"] = `{"timer":{"id":"t1","state":"paused","leftMs":5000}}`
	m := structured(t, callTool(t, d, "timer_control", `{"id":"t1","action":"pause"}`))
	assert.Equal(t, "resume", m["undo"].(map[string]any)["args"].(map[string]any)["action"])

	ipc.result["timers.add"] = `{"timer":{"id":"t1","state":"running","leftMs":305000},"addedSeconds":300}`
	m = structured(t, callTool(t, d, "timer_control", `{"id":"t1","action":"add","amount":"5m"}`))
	assert.Equal(t, "-300s", m["undo"].(map[string]any)["args"].(map[string]any)["amount"])
	assert.Equal(t, "5m", ipc.calls[len(ipc.calls)-1].Params.(map[string]any)["spec"])
	assert.True(t, callTool(t, d, "timer_control", `{"id":"t1","action":"add"}`).IsError)

	ipc.result["timers.cancel"] = `{"timer":{"id":"t1","name":"tea","state":"running","leftMs":42000}}`
	m = structured(t, callTool(t, d, "timer_control", `{"id":"t1","action":"cancel"}`))
	assert.Equal(t, map[string]any{"tool": "timer_start", "args": map[string]any{"duration": "42s", "name": "tea"}}, m["undo"])

	ipc.result["timers.dismiss"] = `{"dismissed":2}`
	m = structured(t, callTool(t, d, "timer_control", `{"action":"dismiss"}`))
	assert.EqualValues(t, 2, m["dismissed"])
}

func TestTimerListAndStopwatch(t *testing.T) {
	d, _, ipc := newDeps(t)
	ipc.result["timers.list"] = `{"now":1,"timers":[{"id":"t1","name":"tea","state":"paused","totalMs":600000,"leftMs":61000}],
		"stopwatch":{"state":"running","elapsedMs":3723000,"laps":[{"n":1,"totalMs":1000,"splitMs":1000}]},
		"reminders":[{"id":"r2","message":"call mom","at":1790000000000,"leftMs":60000}]}`
	m := structured(t, callTool(t, d, "timer_list", `{}`))
	assert.Equal(t, "1:01", m["timers"].([]any)[0].(map[string]any)["left"])
	assert.Equal(t, "1:02:03", m["stopwatch"].(map[string]any)["elapsed"])
	assert.Equal(t, "r2", m["reminders"].([]any)[0].(map[string]any)["id"])
	m = structured(t, callTool(t, d, "reminder_list", `{}`))
	assert.Equal(t, "1m", m["reminders"].([]any)[0].(map[string]any)["in"])

	ipc.result["timers.stopwatch"] = `{"stopwatch":{"state":"running","elapsedMs":0,"laps":[]},"previous":{"state":"idle"}}`
	m = structured(t, callTool(t, d, "stopwatch_control", `{"action":"start"}`))
	assert.Equal(t, "reset", m["undo"].(map[string]any)["args"].(map[string]any)["action"])
}

func TestReminderTools(t *testing.T) {
	d, _, ipc := newDeps(t)
	ipc.result["timers.reminderAdd"] = `{"reminder":{"id":"r5","message":"stretch","at":1790000000000,"leftMs":1200000}}`
	m := structured(t, callTool(t, d, "reminder_add", `{"when":"in 20m","message":"stretch"}`))
	assert.Equal(t, map[string]any{"when": "in 20m", "message": "stretch"}, ipc.calls[0].Params)
	assert.Equal(t, map[string]any{"tool": "reminder_cancel", "args": map[string]any{"id": "r5"}}, m["undo"])

	callTool(t, d, "reminder_add", `{"when":"2026-10-07T09:00:00Z","message":"x"}`)
	assert.EqualValues(t, int64(1791363600000), ipc.calls[1].Params.(map[string]any)["at"])

	// newDeps' clock is 2026-10-05; the reminder is later, so undo re-adds it.
	ipc.result["timers.reminderCancel"] = `{"reminder":{"id":"r5","message":"stretch","at":1800000000000}}`
	m = structured(t, callTool(t, d, "reminder_cancel", `{"id":"r5"}`))
	assert.Equal(t, "reminder_add", m["undo"].(map[string]any)["tool"])

	ipc.down = true
	assert.True(t, callTool(t, d, "reminder_list", `{}`).IsError)
}
