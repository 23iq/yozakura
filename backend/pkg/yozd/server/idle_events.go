package server

import "yozakura/backend/pkg/yozd/client"

// Idle monitor change events on the subscribe stream.
//
// Every idle/active flip of a monitor is broadcast as
// Event.IdleMonitorChanged {id, is_idle, seq}. Broadcasts are written by one
// goroutine per client and the flips can come from the Wayland dispatch
// goroutine and from a request handler (an update resets the monitor), so the
// lines can reach a subscriber out of order: seq is taken under the idle
// manager's lock when the state changes and only grows, and a subscriber
// keeps the event with the highest seq per monitor. The State.Dump that
// opens a subscription lists client.FeatureIdleEvents so a subscriber knows
// the events (with seq) will come and need not poll idle-monitor-get.

// SetIdleMonitorCallback sets the function called on every idle/active flip
// of a monitor, outside the manager's lock, with the flip's sequence number.
func (im *IdleManager) SetIdleMonitorCallback(cb func(id uint32, isIdle bool, seq uint64)) {
	im.mu.Lock()
	im.onIdleMonitorChanged = cb
	im.mu.Unlock()
}

func (im *IdleManager) setMonitorIdle(mon *idleMonitor, isIdle bool) {
	im.mu.Lock()
	if mon.deleted || mon.isIdle == isIdle {
		im.mu.Unlock()
		return
	}
	mon.isIdle = isIdle
	im.idleSeq++
	seq := im.idleSeq
	cb := im.onIdleMonitorChanged
	id := mon.id
	im.mu.Unlock()

	if cb != nil {
		cb(id, isIdle, seq)
	}
}

func (s *Server) handleIdleMonitorChanged(id uint32, isIdle bool, seq uint64) {
	s.broadcastEvent(client.IdleMonitorChangedEvent, map[string]interface{}{
		"id":      id,
		"is_idle": isIdle,
		"seq":     seq,
	})
}

// streamFeatures lists what a new subscription will receive besides the
// compositor events.
func (s *Server) streamFeatures() []string {
	if s.idleMgr == nil {
		return nil
	}
	return []string{client.FeatureIdleEvents}
}
