package main

import (
	"bytes"
	"strconv"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestFocusCLI(t *testing.T) {
	ends := time.Date(2026, 10, 6, 15, 30, 0, 0, time.Local).UnixMilli()
	f := &fakeUsageIPC{results: map[string]string{
		"focus.get": `{"active":true,"known":true,"endsAt":` + strconv.FormatInt(ends, 10) + `,"minutesLeft":12}`,
		"ui.run":    `{}`,
	}}
	var out, errOut bytes.Buffer
	assert.Equal(t, 0, runFocus(nil, f, &out, &errOut))
	assert.Equal(t, "Focus mode: on until 15:30 (12 min left)\n", out.String())

	assert.Equal(t, 0, runFocus([]string{"start", "25"}, f, &out, &errOut))
	assert.Equal(t, map[string]any{"command": "focus:25"}, f.params)
	assert.Equal(t, 0, runFocus([]string{"start"}, f, &out, &errOut))
	assert.Equal(t, map[string]any{"command": "focus:0"}, f.params)
	assert.Equal(t, 0, runFocus([]string{"stop"}, f, &out, &errOut))
	assert.Equal(t, map[string]any{"command": "focus-stop"}, f.params)

	assert.Equal(t, 2, runFocus([]string{"start", "0"}, f, &out, &errOut))
	assert.Equal(t, 2, runFocus([]string{"later"}, f, &out, &errOut))

	out.Reset()
	f.results["focus.get"] = `{"active":false,"known":true}`
	assert.Equal(t, 0, runFocus([]string{"status"}, f, &out, &errOut))
	assert.Equal(t, "Focus mode: off\n", out.String())
	assert.Equal(t, 1, runFocus(nil, &fakeUsageIPC{}, &out, &errOut), "shell down")
}
