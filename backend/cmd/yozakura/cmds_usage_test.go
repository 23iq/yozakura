package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"testing"

	"github.com/stretchr/testify/assert"
)

type fakeUsageIPC struct {
	results map[string]string
	method  string
	params  any
}

func (f *fakeUsageIPC) Call(method string, params any) (json.RawMessage, error) {
	f.method, f.params = method, params
	if r, ok := f.results[method]; ok {
		return json.RawMessage(r), nil
	}
	return nil, errors.New("down")
}

func TestUsageCLISummary(t *testing.T) {
	f := &fakeUsageIPC{results: map[string]string{"usage.summary": `{"range":"week","groupBy":"model","from":"2026-10-05T00:00:00Z","to":"2026-10-12T00:00:00Z",
		"totals":{"requests":3,"inputTokens":1500000,"outputTokens":20000,"cachedTokens":0,"costUSD":1.5,"estimated":true,"unpriced":1},
		"rows":[{"key":"gpt-4o","provider":"openai","requests":2,"inputTokens":1500000,"outputTokens":20000,"costUSD":1.5,"estimated":true},
		        {"key":"mystery","provider":"custom","requests":1,"unpriced":1}]}`}}
	var out, errOut bytes.Buffer
	assert.Equal(t, 0, runUsage([]string{"week", "--by", "model"}, f, &out, &errOut))
	assert.Equal(t, "usage.summary", f.method)
	assert.Contains(t, out.String(), "Week usage, 2026-10-05")
	assert.Contains(t, out.String(), "openai/gpt-4o")
	assert.Contains(t, out.String(), "1.50M")
	assert.Contains(t, out.String(), "≈$1.5000+") // estimate plus unpriced requests
	assert.Contains(t, out.String(), "custom/mystery")

	out.Reset()
	assert.Equal(t, 0, runUsage([]string{"--json", "--by=model"}, f, &out, &errOut))
	assert.Contains(t, out.String(), `"groupBy": "model"`)
}

func TestUsageCLIErrors(t *testing.T) {
	f := &fakeUsageIPC{}
	var out, errOut bytes.Buffer
	assert.Equal(t, 2, runUsage([]string{"year"}, f, &out, &errOut))
	assert.Equal(t, 2, runUsage([]string{"--by", "color"}, f, &out, &errOut))
	assert.Equal(t, 1, runUsage([]string{"limits"}, f, &out, &errOut)) // shell down
	assert.Equal(t, 0, runUsage([]string{"help"}, f, &out, &errOut))
	assert.Contains(t, out.String(), "usage limits")
}

func TestUsageCLILimits(t *testing.T) {
	f := &fakeUsageIPC{results: map[string]string{"usage.limits.get": `{"limits":[{"provider":"claude","source":"oauth","windows":[{"id":"5h","usedPercent":81.6,"resetsAt":"2030-01-01T00:00:00Z"},{"id":"week","usedPercent":38}]}]}`}}
	var out, errOut bytes.Buffer
	assert.Equal(t, 0, runUsage([]string{"limits"}, f, &out, &errOut))
	assert.Contains(t, out.String(), "claude")
	assert.Contains(t, out.String(), "82%")
	assert.Contains(t, out.String(), "38%")

	f.results["usage.limits.get"] = `{"limits":[]}`
	out.Reset()
	assert.Equal(t, 0, runUsage([]string{"limits"}, f, &out, &errOut))
	assert.Contains(t, out.String(), "No subscription limits")
}
