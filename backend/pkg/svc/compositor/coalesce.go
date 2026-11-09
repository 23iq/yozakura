package compositor

import "time"

// pushInterval caps compositor.state pushes to the shell at about one per
// frame. A burst of compositor events (a terminal title spinner, a window
// drag, a workspace switch that moves a dozen windows) collapses into the
// first snapshot, sent at once, plus the newest one at the end of the frame.
const pushInterval = 16 * time.Millisecond

// coalesce forwards states from in to send, at most one per interval. The
// first state after a quiet period is sent immediately (no added latency);
// states arriving within interval of the last send are held and only the
// newest one is sent when the interval ends (latest wins). It returns when
// in is closed or stop fires; a held state is flushed when in closes.
func coalesce(in <-chan State, stop <-chan struct{}, interval time.Duration, send func(State)) {
	var (
		last    time.Time
		pending *State
		timer   *time.Timer
		fire    <-chan time.Time
	)
	defer func() {
		if timer != nil {
			timer.Stop()
		}
	}()
	emit := func(st State) {
		send(st)
		last = time.Now()
	}
	for {
		select {
		case st, ok := <-in:
			if !ok {
				if pending != nil {
					emit(*pending)
				}
				return
			}
			if fire != nil { // a flush is already scheduled: replace what it sends
				pending = &st
				continue
			}
			wait := interval - time.Since(last)
			if wait <= 0 {
				emit(st)
				continue
			}
			pending = &st
			if timer == nil {
				timer = time.NewTimer(wait)
			} else {
				timer.Reset(wait)
			}
			fire = timer.C
		case <-fire:
			fire = nil
			if pending != nil {
				emit(*pending)
				pending = nil
			}
		case <-stop:
			return
		}
	}
}
