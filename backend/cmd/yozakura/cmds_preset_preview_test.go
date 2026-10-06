package main

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestPresetPreviewCommands(t *testing.T) {
	sandbox(t)
	code, _, errOut := run(t, preset, "apply", "Yozakura Default")
	assert.Equal(t, 0, code, errOut)

	code, out, errOut := run(t, preset, "apply", "--preview", "Neon Tokyo")
	assert.Equal(t, 0, code, errOut)
	assert.Contains(t, out, "Previewing Neon Tokyo")
	_, out, _ = run(t, preset, "active")
	assert.Equal(t, "Neon Tokyo\n", out)

	code, out, _ = run(t, preset, "revert")
	assert.Equal(t, 0, code)
	assert.Contains(t, out, "Reverted")
	_, out, _ = run(t, preset, "active")
	assert.Equal(t, "Yozakura Default\n", out)

	code, out, _ = run(t, preset, "revert")
	assert.Equal(t, 0, code, "nothing to revert is fine")
	assert.Contains(t, out, "No preview")

	code, _, errOut = run(t, preset, "apply", "--preview")
	assert.Equal(t, 1, code)
	assert.Contains(t, errOut, "usage")
}
