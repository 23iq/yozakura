package main

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestPresetPreviewCommands(t *testing.T) {
	sandbox(t)
	code, _, errOut := run(t, preset, "apply", "Yozakura Night")
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
	assert.Equal(t, "Yozakura Night\n", out)

	code, out, _ = run(t, preset, "revert")
	assert.Equal(t, 0, code, "nothing to revert is fine")
	assert.Contains(t, out, "No preview")

	code, _, errOut = run(t, preset, "apply", "--preview")
	assert.Equal(t, 1, code)
	assert.Contains(t, errOut, "usage")
}

func TestPresetPartsCommands(t *testing.T) {
	sandbox(t)
	code, out, errOut := run(t, preset, "parts", "--json")
	assert.Equal(t, 0, code, errOut)
	for _, k := range []string{`"layouts"`, `"styles"`, `"palettes"`, `"current"`} {
		assert.Contains(t, out, k)
	}
	code, _, errOut = run(t, preset, "apply", "--part", "colour", "X")
	assert.Equal(t, 1, code)
	assert.Contains(t, errOut, "unknown part kind")
	code, _, errOut = run(t, preset, "apply", "--part", "style")
	assert.Equal(t, 1, code)
	assert.Contains(t, errOut, "usage")
}
