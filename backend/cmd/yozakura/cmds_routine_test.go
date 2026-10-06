package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
)

type routineCall struct {
	Method string
	Params map[string]any
}

func fakeRoutines(calls *[]routineCall, results map[string]string) routineCaller {
	return func(method string, params any) (json.RawMessage, error) {
		p, _ := params.(map[string]any)
		*calls = append(*calls, routineCall{method, p})
		if r, ok := results[method]; ok {
			if r == "ERR" {
				return nil, errors.New(`no routine "x"`)
			}
			return json.RawMessage(r), nil
		}
		return json.RawMessage(`{}`), nil
	}
}

func TestRoutineCLI(t *testing.T) {
	var calls []routineCall
	res := map[string]string{
		"list": `{"routines":[{"id":"morning","name":"Morning","steps":[{"kind":"delay","ms":1000}]}]}`,
		"get":  `{"routine":{"id":"morning","name":"Morning","steps":[{"kind":"tool","tool":"dnd_set","args":{"enabled":true}}]}}`,
		"run":  `{"id":"morning","ok":false,"steps":[{"index":0,"label":"Tool dnd_set","status":"failed","error":"boom"}]}`,
		"save": `{"routine":{"id":"evening","name":"Evening"}}`,
	}
	var out, errOut bytes.Buffer
	call := fakeRoutines(&calls, res)

	assert.Equal(t, 0, runRoutineWith(call, []string{"list"}, nil, &out, &errOut))
	assert.Contains(t, out.String(), "morning")
	assert.Contains(t, out.String(), "(1 steps)")

	out.Reset()
	assert.Equal(t, 0, runRoutineWith(call, []string{"show", "Morning"}, nil, &out, &errOut))
	assert.Contains(t, out.String(), `1. Tool dnd_set {"enabled":true}`)
	assert.Equal(t, map[string]any{"id": "Morning"}, calls[len(calls)-1].Params)

	out.Reset()
	assert.Equal(t, 1, runRoutineWith(call, []string{"run", "morning"}, nil, &out, &errOut))
	assert.Contains(t, out.String(), "failed  1. Tool dnd_set: boom")

	out.Reset()
	assert.Equal(t, 0, runRoutineWith(call, []string{"save", "-"}, strings.NewReader(`{"name":"Evening","steps":[]}`), &out, &errOut))
	assert.Contains(t, out.String(), "Saved Evening (evening)")
	assert.NotContains(t, calls[len(calls)-1].Params, "replace")

	file := filepath.Join(t.TempDir(), "r.json")
	assert.NoError(t, os.WriteFile(file, []byte(`{"id":"evening","name":"Evening","steps":[]}`), 0o644))
	assert.Equal(t, 0, runRoutineWith(call, []string{"save", file}, nil, &out, &errOut))
	assert.Equal(t, "evening", calls[len(calls)-1].Params["replace"])

	assert.Equal(t, 1, runRoutineWith(call, []string{"save", "-"}, strings.NewReader(`nope`), &out, &errOut))
	assert.Equal(t, 2, runRoutineWith(call, nil, nil, &out, &errOut))
	assert.Equal(t, 2, runRoutineWith(call, []string{"dance"}, nil, &out, &errOut))

	res["delete"] = "ERR"
	assert.Equal(t, 1, runRoutineWith(call, []string{"delete", "x"}, nil, &out, &errOut))
	assert.Contains(t, errOut.String(), `no routine "x"`)
}
