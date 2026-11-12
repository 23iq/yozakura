package compositor

import (
	"encoding/json"
	"fmt"
	"sync"
)

// States of the shell's own polkit agent, as the shell reports them
// (modules/polkit/PolkitHost.qml, compositor.setPolkitState).
const (
	PolkitOff         = "off"         // system.polkitAgent is off
	PolkitUnavailable = "unavailable" // Quickshell has no Polkit module
	PolkitPending     = "pending"     // loaded, not registered (yet, or another agent holds the session)
	PolkitRegistered  = "registered"  // polkitd sends this session's prompts to the shell
)

// PolkitReport is the last state the shell reported, with the process that
// reported it (Quickshell's pid), so a reader can tell a report of a shell
// that is gone. The zero value is "no report".
type PolkitReport struct {
	State string `json:"state"`
	PID   int    `json:"pid"`
}

// polkitState holds the shell's last report.
type polkitState struct {
	mu   sync.Mutex
	last PolkitReport
}

func (p *polkitState) get(json.RawMessage) (any, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.last, nil
}

func (p *polkitState) set(params json.RawMessage) (any, error) {
	var r PolkitReport
	if err := json.Unmarshal(params, &r); err != nil {
		return nil, fmt.Errorf("compositor.setPolkitState: %w", err)
	}
	switch r.State {
	case PolkitOff, PolkitUnavailable, PolkitPending, PolkitRegistered:
	default:
		return nil, fmt.Errorf("compositor.setPolkitState: unknown state %q", r.State)
	}
	p.mu.Lock()
	p.last = r
	p.mu.Unlock()
	return true, nil
}
