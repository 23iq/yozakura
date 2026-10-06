package yozakura

import (
	"context"
	"encoding/json"
	"errors"

	"yozakura/backend/pkg/mcp"
	"yozakura/backend/pkg/svc/usage"
)

// AI usage: the ledger kept by pkg/svc/usage (same data as `yozakura usage`).

func usageTools(d Deps) []mcp.ToolDef {
	return []mcp.ToolDef{
		define("usage_summary", "AI usage summary",
			`Summarise the user's AI token usage and cost from the shell's usage ledger: totals plus one row per provider, model or day. Ranges are calendar based (today, week from Monday, month from the 1st). costUSD is in US dollars; estimated=true means part of it comes from the bundled price table, unpriced counts requests with an unknown price. With limits=true the subscription limit windows (Claude, Codex: usedPercent 0-100, resetsAt) reported to the running shell are included.`,
			`{"type":"object","properties":{"range":{"type":"string","enum":["today","week","month"],"description":"Default today."},"groupBy":{"type":"string","enum":["provider","model","day"],"description":"Default provider."},"limits":{"type":"boolean","description":"Also return subscription limits (needs the shell running)."}},"additionalProperties":false}`,
			toolOpts{readOnly: true}, d.usageSummary),
	}
}

func (d Deps) usageSummary(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct {
		Range   string `json:"range"`
		GroupBy string `json:"groupBy"`
		Limits  bool   `json:"limits"`
	}
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	if a.Range == usage.RangeCustom {
		return nil, errors.New("range must be today, week or month")
	}
	if d.UsageDir == "" {
		return nil, errors.New("usage ledger not configured")
	}
	sum, err := usage.NewLedger(d.UsageDir).Summary(usage.SummaryQuery{Range: a.Range, GroupBy: a.GroupBy}, d.now())
	if err != nil {
		return nil, err
	}
	out := map[string]any{"summary": sum}
	if a.Limits {
		var res struct {
			Limits []usage.Limits `json:"limits"`
		}
		raw, err := d.call("usage.limits.get", nil)
		if err == nil && json.Unmarshal(raw, &res) == nil {
			out["limits"] = res.Limits
		} else {
			out["limits"] = []usage.Limits{}
			out["limitsNote"] = "the shell is not running; limits unavailable"
		}
	}
	return mcp.JSONResult(out), nil
}
