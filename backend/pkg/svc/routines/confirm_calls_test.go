package routines

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

// The cases are shared with tests/ai-confirm-tools.test.cjs, so the chat
// policy (Permissions.js) and the agents/routines policy decide alike.
func TestConfirmCallSharedCases(t *testing.T) {
	data, err := os.ReadFile(filepath.Join("..", "..", "..", "..", "tests", "fixtures", "ai-confirm-calls.json"))
	if err != nil {
		t.Fatal(err)
	}
	var cases []struct {
		Tool    string         `json:"tool"`
		Args    map[string]any `json:"args"`
		Confirm bool           `json:"confirm"`
	}
	if err := json.Unmarshal(data, &cases); err != nil {
		t.Fatal(err)
	}
	if len(cases) < 20 {
		t.Fatalf("parsed %d cases", len(cases))
	}
	for _, c := range cases {
		if got := ConfirmCall(c.Tool, c.Args); got != c.Confirm {
			raw, _ := json.Marshal(c.Args)
			t.Errorf("ConfirmCall(%s, %s) = %v, want %v", c.Tool, raw, got, c.Confirm)
		}
	}
}

func TestConfirmStepsCommandConfig(t *testing.T) {
	r := Routine{ID: "r", Steps: []Step{
		{Kind: KindTool, Tool: "config_set", Args: map[string]any{"key": "bar.position", "value": "top"}},
	}}
	if got := ConfirmSteps(r, nil); len(got) != 0 {
		t.Fatalf("harmless config_set step asks: %v", got)
	}
	r.Steps = append(r.Steps, Step{Kind: KindTool, Tool: "config_set", Args: map[string]any{"key": "general.terminalCommand", "value": "sh"}})
	if got := ConfirmSteps(r, nil); len(got) != 1 || got[0] != "config_set" {
		t.Fatalf("command config_set step: %v", got)
	}
}
