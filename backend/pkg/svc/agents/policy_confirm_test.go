package agents

import "testing"

func TestConfirmToolsAlwaysAsk(t *testing.T) {
	p := Policy{AutoApprove: []string{CatRead, CatMCP}}
	tool := "mcp__" + YozakuraMCPName + "__binds_set"
	req := PermissionRequest{Tool: tool, Category: Classify(tool, nil), RuleKey: ruleKey(tool, CatMCP, nil)}
	if req.RuleKey != "" {
		t.Fatalf("confirm tools offer no session rule, got %q", req.RuleKey)
	}
	if d := p.Decide(req, false, map[string]bool{tool: true}); d != "" {
		t.Fatalf("binds_set must ask, got %q", d)
	}
	if d := p.Decide(req, true, nil); d != "" {
		t.Fatalf("confirm tools ask even in yolo, got %q", d)
	}
	if d := p.Decide(PermissionRequest{Tool: "x", Category: CatRead, Confirm: true}, true, nil); d != "" {
		t.Fatalf("a Confirm request asks, got %q", d)
	}
	other := "mcp__" + YozakuraMCPName + "__routine_save"
	if d := p.Decide(PermissionRequest{Tool: other, Category: CatMCP, RuleKey: other}, false, nil); d != DecisionAllow {
		t.Fatalf("routine_save follows the policy, got %q", d)
	}
	for _, ro := range []string{"system_info", "notes_search", "binds_search", "timer_list"} {
		if c := Classify("mcp__"+YozakuraMCPName+"__"+ro, nil); c != CatRead {
			t.Errorf("%s: %s", ro, c)
		}
	}
	if c := Classify("mcp__"+YozakuraMCPName+"__screen_look", nil); c != CatMCP {
		t.Errorf("screen_look reads private pixels and asks: %s", c)
	}
}
