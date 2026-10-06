package yozakura

import (
	"path/filepath"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"

	"yozakura/backend/pkg/svc/usage"
)

func TestUsageSummaryTool(t *testing.T) {
	d, _, ipc := newDeps(t)
	d.UsageDir = filepath.Join(t.TempDir(), "usage")
	cost := 0.25
	l := usage.NewLedger(d.UsageDir)
	assert.NoError(t, l.Append(usage.Record{Time: d.now(), Provider: "openai", Model: "gpt-4o", InputTokens: 1200, OutputTokens: 80, CostUSD: &cost, Estimated: true}))
	assert.NoError(t, l.Append(usage.Record{Time: d.now().Add(-40 * 24 * time.Hour), Provider: "groq", Model: "old"}))

	res := callTool(t, d, "usage_summary", `{"range":"month","groupBy":"model"}`)
	assert.False(t, res.IsError, res.Text())
	assert.Contains(t, res.Text(), `"key": "gpt-4o"`)
	assert.Contains(t, res.Text(), `"inputTokens": 1200`)
	assert.NotContains(t, res.Text(), `"old"`)
	assert.NotContains(t, res.Text(), `"limits"`)

	ipc.result["usage.limits.get"] = `{"limits":[{"provider":"claude","windows":[{"id":"5h","usedPercent":42}],"updatedAt":"2026-10-05T12:00:00Z"}]}`
	res = callTool(t, d, "usage_summary", `{"limits":true}`)
	assert.Contains(t, res.Text(), `"usedPercent": 42`)

	ipc.down = true
	res = callTool(t, d, "usage_summary", `{"limits":true}`)
	assert.Contains(t, res.Text(), "limitsNote")

	assert.True(t, callTool(t, d, "usage_summary", `{"groupBy":"color"}`).IsError)
}
