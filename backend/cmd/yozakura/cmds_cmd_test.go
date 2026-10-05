package main

import (
	"bytes"
	"encoding/json"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"

	"yozakura/backend/pkg/commands"
)

func fakeCmdEnv(calls *[]string) cmdEnv {
	return cmdEnv{
		root: "../../..",
		exec: commands.Executor{
			Call: func(m string, p any) error {
				*calls = append(*calls, m+" "+p.(map[string]any)["command"].(string))
				return nil
			},
			Exec: func(a []string) (string, error) {
				*calls = append(*calls, "exec "+strings.Join(a, " "))
				return "", nil
			},
			SetConfig: func(k string, v any) (string, error) {
				*calls = append(*calls, "set "+k)
				return k + " set", nil
			},
		},
	}
}

func TestCmdList(t *testing.T) {
	var calls []string
	var out, errOut bytes.Buffer
	assert.Equal(t, 0, runCmdWith(fakeCmdEnv(&calls), []string{"list"}, &out, &errOut), errOut.String())
	assert.Contains(t, out.String(), "glass <0..1>")
	assert.Contains(t, out.String(), "preset <preset name>")

	out.Reset()
	assert.Equal(t, 0, runCmdWith(fakeCmdEnv(&calls), []string{"list", "--json"}, &out, &errOut))
	var views []commands.View
	assert.NoError(t, json.Unmarshal(out.Bytes(), &views))
	assert.NotEmpty(t, views)

	out.Reset()
	assert.Equal(t, 0, runCmdWith(fakeCmdEnv(&calls), []string{"__args", "wallpaper"}, &out, &errOut))
	assert.Contains(t, out.String(), "random")
	assert.Empty(t, calls)
}

func TestCmdRun(t *testing.T) {
	var calls []string
	var out, errOut bytes.Buffer
	env := fakeCmdEnv(&calls)
	assert.Equal(t, 0, runCmdWith(env, []string{"dnd"}, &out, &errOut), errOut.String())
	assert.Equal(t, 0, runCmdWith(env, []string{"preset", "Neon", "Tokyo"}, &out, &errOut), errOut.String())
	assert.Equal(t, 0, runCmdWith(env, []string{"glass", "0.6"}, &out, &errOut), errOut.String())
	assert.Equal(t, 0, runCmdWith(env, []string{"bar"}, &out, &errOut), errOut.String())
	assert.Equal(t, []string{"ui.run dnd-toggle", "exec preset apply Neon Tokyo", "set theme.glass.amount", "ui.toggle bar"}, calls)

	errOut.Reset()
	assert.Equal(t, 1, runCmdWith(env, []string{"glass", "7"}, &out, &errOut))
	assert.Contains(t, errOut.String(), "out of range")
	assert.Equal(t, 1, runCmdWith(env, []string{"nope"}, &out, &errOut))
	assert.Contains(t, errOut.String(), "unknown command")
}
