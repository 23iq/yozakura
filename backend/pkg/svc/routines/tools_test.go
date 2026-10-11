package routines

import (
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestToolsMethodServesTheCatalog(t *testing.T) {
	path := filepath.Join(t.TempDir(), FileName)
	s := NewService(Options{Path: path, Tools: func() any {
		return []map[string]any{{"name": "dnd_set", "category": "focus"}}
	}})
	res, err := call(t, s, "tools", nil)
	assert.NoError(t, err)
	tools, _ := res["tools"].([]any)
	assert.Len(t, tools, 1)
	cats, _ := res["categories"].([]any)
	assert.Contains(t, cats, "focus")

	empty := NewService(Options{Path: path})
	res, err = call(t, empty, "tools", nil)
	assert.NoError(t, err)
	assert.Empty(t, res["tools"])
}

func TestStepLabelsAreSentences(t *testing.T) {
	assert.Equal(t, "Turn on Do Not Disturb", StepLabel(Step{Kind: KindTool, Tool: "dnd_set", Args: map[string]any{"enabled": true}}))
	assert.Equal(t, "Tool custom_thing", StepLabel(Step{Kind: KindTool, Tool: "custom_thing"}))
	assert.Equal(t, "Switch Workspace · 3", StepLabel(Step{Kind: KindAction, Action: "workspace.switch", Args: map[string]any{"index": "3"}}))
	assert.Equal(t, "Close Window", StepLabel(Step{Kind: KindAction, Action: "window.close"}))
}
