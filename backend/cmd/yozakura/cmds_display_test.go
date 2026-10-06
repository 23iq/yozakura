package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"testing"
	"time"
	yipc "yozakura/backend/pkg/yozd/ipc"

	"github.com/stretchr/testify/assert"
)

type recCaller struct {
	results map[string]string
	calls   []string
	params  map[string]any
}

func (r *recCaller) Call(method string, params any) (json.RawMessage, error) {
	r.calls = append(r.calls, method)
	if r.params == nil {
		r.params = map[string]any{}
	}
	r.params[method] = params
	if s, ok := r.results[method]; ok {
		return json.RawMessage(s), nil
	}
	return nil, errors.New("down")
}

const dp1 = `[{"id":"LG|27GP|123","name":"DP-1","make":"LG","model":"27GP","enabled":true,"width":2560,"height":1440,"refresh":144,"x":0,"y":0,"scale":1,"transform":0,"vrr":false,
 "modes":[{"width":2560,"height":1440,"refresh":144},{"width":2560,"height":1440,"refresh":239.97},{"width":1920,"height":1080,"refresh":60}]}]`

func displayTestEnv(t *testing.T, tty bool, answer bool) (displayEnv, *recCaller, *time.Duration) {
	sandbox(t)
	rc := &recCaller{results: map[string]string{
		"displays.list": dp1, "displays.apply": `{"session":"s1","revertIn":15,"live":true}`,
		"displays.keep": `{"ok":true,"saved":true}`, "displays.revert": `{"ok":true}`,
	}}
	var slept time.Duration
	env := displayEnv{
		c: rc, tty: tty,
		confirm: func(string, time.Duration) (bool, bool) { return answer, true },
		sleep:   func(d time.Duration) { slept = d },
	}
	return env, rc, &slept
}

func TestDisplaySetArgs(t *testing.T) {
	env, rc, _ := displayTestEnv(t, false, false)
	var out, errOut bytes.Buffer
	code := runDisplay([]string{"set", "DP-1", "--mode", "2560x1440@240", "--scale", "1", "--yes"}, env, &out, &errOut)
	assert.Equal(t, 0, code, errOut.String())
	assert.Equal(t, []string{"displays.list", "displays.apply", "displays.keep"}, rc.calls)
	cfgs := rc.params["displays.apply"].(map[string]any)["outputs"].([]yipc.OutputConfig)
	if !assert.Len(t, cfgs, 1) {
		return
	}
	assert.Equal(t, "DP-1", cfgs[0].Name)
	assert.Equal(t, 2560, cfgs[0].Width)
	assert.InDelta(t, 239.97, cfgs[0].Refresh, 0.001, "snapped to the real mode")
	assert.Equal(t, 1.0, cfgs[0].Scale)
	assert.Equal(t, map[string]any{"session": "s1"}, rc.params["displays.keep"])

	// the backend saves the kept layout (displays.keep reports saved)
	assert.NotContains(t, errOut.String(), "not saved")
	rc.results["displays.keep"] = `{"ok":true,"saved":false}`
	errOut.Reset()
	assert.Equal(t, 0, runDisplay([]string{"set", "DP-1", "--scale", "1.25", "--yes"}, env, &out, &errOut), errOut.String())
	assert.Contains(t, errOut.String(), "not saved")
}

func TestDisplaySetConfirmAndRevert(t *testing.T) {
	// tty, answer no: reverted, nothing saved
	env, rc, _ := displayTestEnv(t, true, false)
	var out, errOut bytes.Buffer
	assert.Equal(t, 3, runDisplay([]string{"set", "DP-1", "--mode", "1920x1080"}, env, &out, &errOut))
	assert.Equal(t, []string{"displays.list", "displays.apply", "displays.revert"}, rc.calls)
	_, got, _ := run(t, cfg, "get", "displays.monitors", "--json")
	assert.Equal(t, "[]\n", got)

	// tty, answer yes: kept
	env, rc, _ = displayTestEnv(t, true, true)
	assert.Equal(t, 0, runDisplay([]string{"set", "DP-1", "--rotate", "90"}, env, &out, &errOut))
	assert.Equal(t, "displays.keep", rc.calls[len(rc.calls)-1])

	// no tty, no --yes: waits the timeout, then reverts; never keeps
	env, rc, slept := displayTestEnv(t, false, true)
	out.Reset()
	assert.Equal(t, 3, runDisplay([]string{"set", "DP-1", "--vrr", "on"}, env, &out, &errOut))
	assert.Equal(t, 15*time.Second, *slept)
	assert.Equal(t, "displays.revert", rc.calls[len(rc.calls)-1])
	assert.NotContains(t, rc.calls, "displays.keep")
}

func TestDisplayErrors(t *testing.T) {
	env, rc, _ := displayTestEnv(t, false, false)
	var out, errOut bytes.Buffer
	for _, args := range [][]string{
		{"set", "DP-9", "--scale", "1"},
		{"set", "DP-1", "--mode", "3840x2160@60"},
		{"set", "DP-1", "--mode", "bogus"},
		{"set", "DP-1", "--scale", "9"},
		{"set", "DP-1", "--rotate", "45"},
		{"set", "DP-1", "--vrr", "maybe"},
		{"set", "DP-1", "--pos", "1920"},
	} {
		errOut.Reset()
		assert.Equal(t, 1, runDisplay(args, env, &out, &errOut), "%v", args)
		assert.Contains(t, errOut.String(), "Error:")
	}
	assert.NotContains(t, rc.calls, "displays.apply", "bad input never reaches the daemon")
	assert.Equal(t, 2, runDisplay([]string{"bogus"}, env, &out, &errOut))
	assert.Equal(t, 2, runDisplay([]string{"set"}, env, &out, &errOut))

	out.Reset()
	assert.Equal(t, 0, runDisplay([]string{"set", "DP-1", "--scale", "1"}, env, &out, &errOut), "same as now")
	assert.Contains(t, out.String(), "nothing to change")
}

func TestDisplayList(t *testing.T) {
	env, _, _ := displayTestEnv(t, false, false)
	var out, errOut bytes.Buffer
	assert.Equal(t, 0, runDisplay(nil, env, &out, &errOut))
	assert.Regexp(t, `DP-1\s+2560x1440@144\s+1\s+0,0`, out.String())
	out.Reset()
	assert.Equal(t, 0, runDisplay([]string{"list", "--json"}, env, &out, &errOut))
	assert.Contains(t, out.String(), `"name": "DP-1"`)
	assert.Equal(t, 1, runDisplay(nil, displayEnv{c: &recCaller{}}, &out, &errOut), "shell down")
}
