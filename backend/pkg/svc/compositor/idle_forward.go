package compositor

import (
	"time"

	"yozakura/backend/pkg/ipc"
)

// idleResyncRetry is how long the forwarder waits before trying again to
// deliver a resync status the subscriber's full buffer refused.
const idleResyncRetry = 250 * time.Millisecond

// idleForwarder copies the idle hub's updates of one subscription to its
// IPC subscriber. The subscriber's buffer drops what does not fit, so a
// dropped update is not lost silently: the next message delivered is a
// status with a new epoch (the shell re-reads its monitor), sent with the
// next update or, if none comes, after idleResyncRetry.
type idleForwarder struct {
	hub    *idleHub
	ch     <-chan IdleUpdate
	sub    *ipc.Subscriber
	resync bool // an update was dropped: the next message is a new epoch
}

// forward delivers u, or the pending resync status in its place (u is
// superseded by it and by the re-read it causes).
func (f *idleForwarder) forward(u IdleUpdate) {
	if f.resync {
		f.sendResync()
		return
	}
	if u.Status != nil && !f.sub.TrySend("idlemon.status", *u.Status) {
		f.resync = true
		return
	}
	if u.Change != nil && !f.sub.TrySend("idlemon.changed", *u.Change) {
		f.resync = true
	}
}

// sendResync tries to deliver the current status with a new epoch; what
// is still queued on the hub for this subscription is older and dropped.
func (f *idleForwarder) sendResync() {
	if f.sub.TrySend("idlemon.status", f.hub.resync(f.ch)) {
		f.resync = false
	}
}

func (f *idleForwarder) run(cancel func()) {
	defer cancel()
	for {
		var retry <-chan time.Time
		if f.resync {
			retry = time.After(idleResyncRetry)
		}
		select {
		case u, ok := <-f.ch:
			if !ok {
				return
			}
			f.forward(u)
		case <-retry:
			f.sendResync()
		case <-f.sub.StopCh():
			return
		}
	}
}

// subscribeIdle serves an "idlemon" IPC subscription.
func (s *Service) subscribeIdle(sub *ipc.Subscriber) {
	if s.mgr == nil {
		return
	}
	ch, st, cancel := s.mgr.SubscribeIdle()
	sub.Send("idlemon.status", st)
	f := &idleForwarder{hub: s.mgr.idle, ch: ch, sub: sub}
	go f.run(cancel)
}
