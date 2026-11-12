package compositor

import (
	"encoding/json"
	"slices"
	"sync"

	"yozakura/backend/pkg/yozd/client"
)

// Idle monitor flips, by event.
//
// The shell's IdleMonitor creates a monitor in the compositor daemon and
// needs its idle/active state. The daemon broadcasts every flip on the
// subscribe stream the Manager already reads (client.IdleMonitorChangedEvent),
// so the Manager forwards them to the "idlemon" IPC subscribers instead of
// the shell spawning `idle-monitor-get` every second.
//
// Wire (service "idlemon", subscribe only):
//   - idlemon.status {connected, events, epoch}: sent on subscribe and
//     whenever it changes. The shell may rely on events only while connected
//     and events are both true; otherwise it polls as before. epoch changes
//     whenever the shell must re-read its monitor: a new stream (the daemon
//     may have restarted and lost every monitor) or dropped events.
//   - idlemon.changed {id, is_idle}: one monitor flipped. Every monitor's
//     flips are sent; the shell keeps those of its own id.

// IdleStatus is the idlemon.status payload.
type IdleStatus struct {
	Connected bool   `json:"connected"`
	Events    bool   `json:"events"`
	Epoch     uint64 `json:"epoch"`
}

// IdleChange is the idlemon.changed payload.
type IdleChange struct {
	ID     uint32 `json:"id"`
	IsIdle bool   `json:"is_idle"`
}

// IdleUpdate carries one of the two payloads.
type IdleUpdate struct {
	Status *IdleStatus
	Change *IdleChange
}

// idleSubBuffer is the queue of one subscriber; a full queue is replaced
// by a status with a new epoch (the shell re-reads its monitor once).
const idleSubBuffer = 64

type idleHub struct {
	mu      sync.Mutex
	status  IdleStatus
	lastSeq map[uint32]uint64 // per monitor, for the current stream
	subs    map[chan IdleUpdate]struct{}
}

func newIdleHub() *idleHub {
	return &idleHub{lastSeq: map[uint32]uint64{}, subs: map[chan IdleUpdate]struct{}{}}
}

// streamUp records a new subscribe stream (its State.Dump features).
func (h *idleHub) streamUp(features []string) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.status.Connected = true
	h.status.Events = slices.Contains(features, client.FeatureIdleEvents)
	h.status.Epoch++
	h.sendStatusLocked()
}

// streamDown records the end of the subscribe stream. The seq bookkeeping
// is reset here and not in streamUp: the daemon writes every broadcast in
// its own goroutine and adds a subscriber before writing its State.Dump, so
// flips can reach a new stream before the dump, and clearing there would
// let a stale flip through. A restarted daemon numbers flips from 1 again,
// but its stream always starts after this call (the old one ended first).
func (h *idleHub) streamDown() {
	h.mu.Lock()
	defer h.mu.Unlock()
	clear(h.lastSeq)
	if !h.status.Connected {
		return
	}
	h.status.Connected = false
	h.status.Events = false
	h.sendStatusLocked()
}

// change forwards one Event.IdleMonitorChanged. A flip with a seq not newer
// than the last one seen for its monitor arrived out of order and is
// dropped; a daemon that sends no seq is trusted in arrival order.
func (h *idleHub) change(params json.RawMessage) {
	var p struct {
		ID     *uint32 `json:"id"`
		IsIdle *bool   `json:"is_idle"`
		Seq    *uint64 `json:"seq"`
	}
	if json.Unmarshal(params, &p) != nil || p.ID == nil || p.IsIdle == nil {
		return
	}
	h.mu.Lock()
	defer h.mu.Unlock()
	if p.Seq != nil {
		if *p.Seq <= h.lastSeq[*p.ID] {
			return
		}
		h.lastSeq[*p.ID] = *p.Seq
	}
	c := IdleChange{ID: *p.ID, IsIdle: *p.IsIdle}
	h.sendLocked(IdleUpdate{Change: &c})
}

func (h *idleHub) sendStatusLocked() {
	st := h.status
	h.sendLocked(IdleUpdate{Status: &st})
}

// sendLocked queues u on every subscriber without blocking. A full queue is
// emptied and replaced by a status with a new epoch, so a stalled
// subscriber re-reads its monitor instead of missing a flip for good.
func (h *idleHub) sendLocked(u IdleUpdate) {
	for c := range h.subs {
		select {
		case c <- u:
			continue
		default:
		}
		drainIdle(c)
		h.status.Epoch++
		st := h.status
		// Only producers (holding h.mu) send, and c was just drained: this
		// cannot block, but stay non-blocking all the same.
		select {
		case c <- IdleUpdate{Status: &st}:
		default:
		}
	}
}

// drainIdle empties c without ever blocking: its reader may take the last
// update between a length check and a receive.
func drainIdle(c <-chan IdleUpdate) {
	for {
		select {
		case <-c:
		default:
			return
		}
	}
}

// resync drops what is queued for c and returns the current status with a
// new epoch: the forwarder could not deliver an update, so its subscriber
// must re-read its monitor. Draining under h.mu keeps every update queued
// after the returned status newer than it.
func (h *idleHub) resync(c <-chan IdleUpdate) IdleStatus {
	h.mu.Lock()
	defer h.mu.Unlock()
	drainIdle(c)
	h.status.Epoch++
	return h.status
}

// subscribe returns the update channel, the status to start from and a
// cancel function.
func (h *idleHub) subscribe() (<-chan IdleUpdate, IdleStatus, func()) {
	c := make(chan IdleUpdate, idleSubBuffer)
	h.mu.Lock()
	h.subs[c] = struct{}{}
	st := h.status
	h.mu.Unlock()
	cancel := func() {
		h.mu.Lock()
		if _, ok := h.subs[c]; ok {
			delete(h.subs, c)
			close(c)
		}
		h.mu.Unlock()
	}
	return c, st, cancel
}

// closeAll ends every subscription (Manager shutdown).
func (h *idleHub) closeAll() {
	h.mu.Lock()
	defer h.mu.Unlock()
	for c := range h.subs {
		delete(h.subs, c)
		close(c)
	}
}

// SubscribeIdle returns the idle monitor updates, the current status and a
// cancel function. The channel is closed when the Manager shuts down.
func (m *Manager) SubscribeIdle() (<-chan IdleUpdate, IdleStatus, func()) {
	return m.idle.subscribe()
}
