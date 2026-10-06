package usage

import "sync"

// Cumulative turns running totals into per-turn deltas. Agents that report
// usage cumulatively per thread (Codex thread/tokenUsage/updated, Claude's
// total_cost_usd in a long-lived stream session) feed it the totals of each
// done event and record what it returns.
type Cumulative struct {
	mu   sync.Mutex
	last map[string]Record
}

func NewCumulative() *Cumulative { return &Cumulative{last: map[string]Record{}} }

// Delta returns cur minus the previous totals of the same session. A total
// that went down (thread reset, new process) starts over from zero.
// CostUSD stays nil when cur has none.
func (c *Cumulative) Delta(cur Record) Record {
	c.mu.Lock()
	defer c.mu.Unlock()
	prev, ok := c.last[cur.SessionID]
	c.last[cur.SessionID] = cur
	if !ok || cur.InputTokens < prev.InputTokens || cur.OutputTokens < prev.OutputTokens {
		return cur
	}
	d := cur
	d.InputTokens -= prev.InputTokens
	d.OutputTokens -= prev.OutputTokens
	d.CachedTokens -= prev.CachedTokens
	if d.CachedTokens < 0 {
		d.CachedTokens = 0
	}
	if cur.CostUSD != nil && prev.CostUSD != nil && *cur.CostUSD >= *prev.CostUSD {
		d.CostUSD = ptr(*cur.CostUSD - *prev.CostUSD)
	}
	return d
}

// Forget drops a finished session.
func (c *Cumulative) Forget(sessionID string) {
	c.mu.Lock()
	delete(c.last, sessionID)
	c.mu.Unlock()
}
