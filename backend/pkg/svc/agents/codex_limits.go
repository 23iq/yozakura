package agents

import (
	"encoding/json"
	"time"
)

// codexLimitsEvery is how often a live Codex session re-reads its
// subscription limits (the app-server only pushes
// account/rateLimits/updated during turns).
var codexLimitsEvery = 10 * time.Minute

// readLimits asks the app-server for the account's rate limits
// (account/rateLimits/read) so they show before the first turn. Errors
// (an API-key login has no limits) are ignored.
func (c *codexConn) readLimits() {
	_ = c.rpc.Call("account/rateLimits/read", nil, func(res json.RawMessage, e *rpcError) {
		if e != nil {
			return
		}
		var r struct {
			RateLimits *codexRateSnapshot `json:"rateLimits"`
		}
		if json.Unmarshal(res, &r) == nil && r.RateLimits != nil {
			reportLimits(c.sink, codexLimits(*r.RateLimits))
		}
	})
}

// pollLimits re-reads the limits every codexLimitsEvery until the process
// exits.
func (c *codexConn) pollLimits() {
	t := time.NewTicker(codexLimitsEvery)
	defer t.Stop()
	for {
		select {
		case <-c.p.done:
			return
		case <-t.C:
			c.readLimits()
		}
	}
}
