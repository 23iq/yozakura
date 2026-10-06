package yozakura

import (
	"testing"

	"github.com/stretchr/testify/assert"

	"yozakura/backend/pkg/svc/tasks"
)

const taskJSON = `{"id":"k1","title":"Add tests","projectDir":"/p","status":"review","mode":"run","plan":[],
"runs":[{"index":0,"agent":"codex","status":"review","branch":"yoz/k1","worktree":"/w/k1","sessionId":"s1",
"summary":"Added tests","commitMessage":"test: add","checks":[{"command":"make check","status":"pass"}]}]}`

func TestTaskTools(t *testing.T) {
	d, _, ipc := newDeps(t)
	names := map[string]bool{}
	for _, td := range Tools(d) {
		names[td.Tool.Name] = true
	}
	for _, n := range []string{"task_create", "task_list", "task_status"} {
		assert.True(t, names[n], n)
	}
	ro := ReadOnlyToolNames()
	assert.Contains(t, ro, "task_list")
	assert.Contains(t, ro, "task_status")
	assert.NotContains(t, ro, "task_create")

	ipc.result["tasks.create"] = taskJSON
	m := structured(t, callTool(t, d, "task_create", `{"dir":"/p","prompt":"Add tests"}`))
	assert.Equal(t, "tasks.create", ipc.calls[0].Method)
	p := ipc.calls[0].Params.(tasks.CreateParams)
	assert.Equal(t, "claude", p.Agent)
	assert.Equal(t, "/p", p.Dir)
	assert.Equal(t, "k1", m["id"])
	run := m["runs"].([]any)[0].(map[string]any)
	assert.Equal(t, "test: add", run["commitMessage"])
	assert.NotContains(t, run, "sessionId")
	assert.Contains(t, m, "next")

	assert.True(t, callTool(t, d, "task_create", `{"dir":"/p"}`).IsError)

	ipc.result["tasks.list"] = `[` + taskJSON + `,{"id":"k0","status":"accepted","runs":[]}]`
	m = structured(t, callTool(t, d, "task_list", `{"active":true}`))
	assert.Len(t, m["tasks"], 1)
	m = structured(t, callTool(t, d, "task_list", `{}`))
	assert.Len(t, m["tasks"], 2)

	ipc.result["tasks.get"] = taskJSON
	m = structured(t, callTool(t, d, "task_status", `{"id":"k1"}`))
	assert.Equal(t, "review", m["status"])
	last := ipc.calls[len(ipc.calls)-1]
	assert.Equal(t, map[string]any{"id": "k1"}, last.Params)
}
