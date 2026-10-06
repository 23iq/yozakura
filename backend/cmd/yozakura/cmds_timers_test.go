package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"testing"

	"github.com/stretchr/testify/assert"
)

type timerCall struct {
	Method string
	Params map[string]any
}

func fakeTimers(calls *[]timerCall, results map[string]string) timerCaller {
	return func(method string, params any) (json.RawMessage, error) {
		p, _ := params.(map[string]any)
		*calls = append(*calls, timerCall{method, p})
		if r, ok := results[method]; ok {
			if r == "ERR" {
				return nil, errors.New("no timer \"x\"")
			}
			return json.RawMessage(r), nil
		}
		return json.RawMessage(`{}`), nil
	}
}

func TestTimerStartSplitsSpecAndName(t *testing.T) {
	var calls []timerCall
	res := map[string]string{"start": `{"timer":{"id":"t1","name":"pasta water","state":"running","leftMs":5400000}}`}
	var out, errOut bytes.Buffer
	assert.Equal(t, 0, runTimerWith(fakeTimers(&calls, res), []string{"1h", "30m", "pasta", "water"}, &out, &errOut))
	assert.Equal(t, timerCall{"start", map[string]any{"spec": "1h 30m", "name": "pasta water"}}, calls[0])
	assert.Contains(t, out.String(), `Started t1 "pasta water" 1:30:00 left`)

	calls = nil
	assert.Equal(t, 0, runTimerWith(fakeTimers(&calls, res), []string{"start", "25"}, &out, &errOut))
	assert.Equal(t, map[string]any{"spec": "25", "name": ""}, calls[0].Params)

	assert.Equal(t, 1, runTimerWith(fakeTimers(&calls, res), []string{"tea"}, &out, &errOut))
	assert.Contains(t, errOut.String(), "try")
	assert.Equal(t, 2, runTimerWith(fakeTimers(&calls, res), nil, &out, &errOut))
}

func TestTimerSubcommands(t *testing.T) {
	var calls []timerCall
	res := map[string]string{
		"pause":    `{"timer":{"id":"t1","state":"paused","leftMs":61000}}`,
		"add":      `{"timer":{"id":"t1","state":"running","leftMs":361000}}`,
		"dismiss":  `{"dismissed":2}`,
		"pomodoro": `{"timer":{"id":"t2","name":"Pomodoro","state":"running","leftMs":1500000,"pomodoro":{"phase":"work","round":1}}}`,
		"cancel":   "ERR",
		"list": `{"timers":[{"id":"t1","name":"tea","state":"paused","leftMs":61000}],
			"stopwatch":{"state":"running","elapsedMs":5000,"laps":[{"n":1}]},
			"reminders":[{"id":"r3","message":"call mom","at":1790000000000}]}`,
	}
	f := fakeTimers(&calls, res)
	var out, errOut bytes.Buffer
	assert.Equal(t, 0, runTimerWith(f, []string{"pause", "tea"}, &out, &errOut))
	assert.Contains(t, out.String(), "t1 paused at 1:01: paused")
	assert.Equal(t, 0, runTimerWith(f, []string{"add", "t1", "5m"}, &out, &errOut))
	assert.Equal(t, map[string]any{"id": "t1", "spec": "5m"}, calls[1].Params)
	assert.Equal(t, 0, runTimerWith(f, []string{"stop"}, &out, &errOut))
	assert.Contains(t, out.String(), "Stopped 2 timer(s)")
	assert.Equal(t, 0, runTimerWith(f, []string{"pomodoro", "50m", "10m"}, &out, &errOut))
	assert.Equal(t, map[string]any{"work": "50m", "break": "10m"}, calls[3].Params)
	assert.Contains(t, out.String(), "[work, round 1]")
	assert.Equal(t, 1, runTimerWith(f, []string{"cancel", "x"}, &out, &errOut))

	out.Reset()
	assert.Equal(t, 0, runTimerWith(f, []string{"list"}, &out, &errOut))
	assert.Contains(t, out.String(), `t1 "tea" paused at 1:01`)
	assert.Contains(t, out.String(), "stopwatch running 0:05 (1 laps)")
	assert.Contains(t, out.String(), "r3 at ")
	out.Reset()
	assert.Equal(t, 0, runTimerWith(f, []string{"list", "--json"}, &out, &errOut))
	assert.True(t, json.Valid(out.Bytes()))
}

func TestStopwatchAndRemindCLI(t *testing.T) {
	var calls []timerCall
	res := map[string]string{
		"stopwatch":   `{"stopwatch":{"state":"running","elapsedMs":12000,"laps":[{"n":1,"totalMs":12000,"splitMs":12000}]}}`,
		"reminderAdd": `{"reminder":{"id":"r1","message":"call mom","at":1790000000000}}`,
	}
	f := fakeTimers(&calls, res)
	var out, errOut bytes.Buffer
	assert.Equal(t, 0, runStopwatchWith(f, []string{"lap"}, &out, &errOut))
	assert.Equal(t, "lap", calls[0].Params["action"])
	assert.Contains(t, out.String(), "lap 1  0:12  (+0:12)")
	assert.Equal(t, 0, runStopwatchWith(f, nil, &out, &errOut))
	assert.Equal(t, "status", calls[1].Params["action"])

	assert.Equal(t, 0, runRemindWith(f, []string{"in", "20m", "call", "mom"}, &out, &errOut))
	assert.Equal(t, map[string]any{"when": "in 20m", "message": "call mom"}, calls[2].Params)
	assert.Equal(t, 0, runRemindWith(f, []string{"18:00", "call", "mom"}, &out, &errOut))
	assert.Equal(t, "18:00", calls[3].Params["when"])
	assert.Contains(t, out.String(), "Reminder r1 at ")
	assert.Equal(t, 0, runRemindWith(f, []string{"cancel", "r1"}, &out, &errOut))
	assert.Equal(t, "reminderCancel", calls[4].Method)
	assert.Equal(t, 1, runRemindWith(f, []string{"someday", "x"}, &out, &errOut))
}

func TestCompletionHasTimerCommands(t *testing.T) {
	for _, sh := range []string{"bash", "zsh", "fish"} {
		s, err := completionScript(sh)
		assert.NoError(t, err)
		assert.Contains(t, s, "pomodoro", sh)
		assert.Contains(t, s, "lap", sh)
	}
}
