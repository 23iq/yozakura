package agents

import (
	"fmt"
	"time"

	"yozakura/backend/pkg/svc/usage"
)

// --- per-turn usage from running totals ---

// turnFrom turns running totals into this turn's usage. cum keeps the
// totals of the previous turn (one Cumulative per agent process).
func turnFrom(cum *usage.Cumulative, model string, in, out, cached int64, cost float64) *TurnUsage {
	if cum == nil {
		return nil
	}
	r := usage.Record{InputTokens: in, OutputTokens: out, CachedTokens: cached}
	if cost > 0 {
		r.CostUSD = &cost
	}
	d := cum.Delta(r)
	t := &TurnUsage{Model: model, InputTokens: d.InputTokens, OutputTokens: d.OutputTokens, CachedTokens: d.CachedTokens}
	if d.CostUSD != nil && *d.CostUSD > 0 {
		c := *d.CostUSD
		t.CostUSD = &c
	}
	return t
}

// claudeTotals sums the result's modelUsage (cumulative for the process):
// prompt tokens include cache reads and writes; the main model is the one
// that processed the most prompt tokens.
func claudeTotals(mu map[string]any) (model string, in, out, cached int64) {
	var best float64
	for id, v := range mu {
		e := asMap(v)
		read := num(e["cacheReadInputTokens"])
		prompt := num(e["inputTokens"]) + read + num(e["cacheCreationInputTokens"])
		in += int64(prompt)
		out += int64(num(e["outputTokens"]))
		cached += int64(read)
		if model == "" || prompt > best {
			model, best = id, prompt
		}
	}
	return model, in, out, cached
}

// --- subscription rate limits ---

// codexRateWindow is one app-server RateLimitWindow.
type codexRateWindow struct {
	UsedPercent        float64 `json:"usedPercent"`
	WindowDurationMins *int64  `json:"windowDurationMins"`
	ResetsAt           *int64  `json:"resetsAt"`
}

// codexRateSnapshot is the app-server RateLimitSnapshot.
type codexRateSnapshot struct {
	LimitID   *string          `json:"limitId"`
	Primary   *codexRateWindow `json:"primary"`
	Secondary *codexRateWindow `json:"secondary"`
}

// codexWindowID names a window by its duration (300 min = "5h", a week =
// "week"); without one, primary is the 5-hour and secondary the weekly one.
func codexWindowID(w *codexRateWindow, fallback string) string {
	if w.WindowDurationMins == nil || *w.WindowDurationMins <= 0 {
		return fallback
	}
	switch mins := *w.WindowDurationMins; {
	case mins == 300:
		return "5h"
	case mins == 7*24*60:
		return "week"
	case mins%(24*60) == 0:
		return fmt.Sprintf("%dd", mins/(24*60))
	case mins%60 == 0:
		return fmt.Sprintf("%dh", mins/60)
	default:
		return fmt.Sprintf("%dm", mins)
	}
}

// codexLimits converts a snapshot. Buckets other than the main "codex"
// one (model-specific quotas) get their limit id as a window suffix.
func codexLimits(s codexRateSnapshot) usage.Limits {
	l := usage.Limits{Provider: "codex", Source: "agent"}
	suffix := ""
	if s.LimitID != nil && *s.LimitID != "" && *s.LimitID != "codex" {
		suffix = "_" + *s.LimitID
	}
	for _, p := range []struct {
		w        *codexRateWindow
		fallback string
	}{{s.Primary, "5h"}, {s.Secondary, "week"}} {
		if p.w == nil {
			continue
		}
		win := usage.Window{ID: codexWindowID(p.w, p.fallback) + suffix, UsedPercent: p.w.UsedPercent}
		if p.w.ResetsAt != nil && *p.w.ResetsAt > 0 {
			win.ResetsAt = time.Unix(*p.w.ResetsAt, 0).UTC()
		}
		l.Windows = append(l.Windows, win)
	}
	return l
}

var claudeWindowIDs = map[string]string{
	"five_hour": "5h", "seven_day": "week", "seven_day_opus": "week_opus", "seven_day_sonnet": "week_sonnet",
}

func claudeWindow(kind string, e map[string]any) (usage.Window, bool) {
	util, ok := e["utilization"].(float64)
	if !ok {
		return usage.Window{}, false
	}
	id := claudeWindowIDs[kind]
	if id == "" {
		id = kind
	}
	w := usage.Window{ID: id, UsedPercent: util * 100}
	if r := num(e["resetsAt"]); r > 0 {
		w.ResetsAt = time.Unix(int64(r), 0).UTC()
	}
	return w, true
}

// claudeRateLimits converts a stream-json rate_limit_event's
// rate_limit_info: unifiedWindows {five_hour: {utilization 0-1, resetsAt}}
// or a single rateLimitType + utilization.
func claudeRateLimits(info map[string]any) usage.Limits {
	l := usage.Limits{Provider: "claude", Source: "agent"}
	seen := map[string]bool{}
	for kind, v := range asMap(info["unifiedWindows"]) {
		if w, ok := claudeWindow(kind, asMap(v)); ok {
			l.Windows = append(l.Windows, w)
			seen[kind] = true
		}
	}
	if kind, _ := info["rateLimitType"].(string); kind != "" && !seen[kind] {
		if w, ok := claudeWindow(kind, info); ok {
			l.Windows = append(l.Windows, w)
		}
	}
	return l
}
