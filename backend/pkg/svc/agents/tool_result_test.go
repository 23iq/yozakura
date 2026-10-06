package agents

import (
	"strings"
	"testing"
)

func TestToolResultKeepsUndoPastTruncation(t *testing.T) {
	big := `{"text":"` + strings.Repeat("x", maxOutput+100) + `","undo":{"tool":"volume_set","args":{"percent":40},"label":"Restore"}}`
	ev := toolResultEvent("t1", "mcp__"+YozakuraMCPName+"__volume_set", big, false)
	if len(ev.Output) > maxOutput+32 || !strings.HasSuffix(ev.Output, "(truncated)") {
		t.Fatalf("output not truncated: %d", len(ev.Output))
	}
	if ev.Undo == nil || ev.Undo["tool"] != "volume_set" || ev.Undo["label"] != "Restore" {
		t.Fatalf("undo = %v", ev.Undo)
	}
	for _, c := range []struct {
		tool, out string
		isErr     bool
	}{
		{"mcp__other__volume_set", big, false},                           // not our server
		{"mcp__" + YozakuraMCPName + "__volume_set", big, true},          // failed call
		{YozakuraMCPName + ".volume_set", `{"undo":{"args":{}}}`, false}, // no tool
		{YozakuraMCPName + ".volume_set", "plain text", false},
	} {
		if ev := toolResultEvent("t", c.tool, c.out, c.isErr); ev.Undo != nil {
			t.Errorf("%s: unexpected undo %v", c.tool, ev.Undo)
		}
	}
	if ev := toolResultEvent("t", YozakuraMCPName+".timer_start", `{"id":"t1","undo":{"tool":"timer_cancel","args":{"id":"t1"}}}`, false); ev.Undo == nil {
		t.Error("OpenCode-style names carry undo too")
	}
}
