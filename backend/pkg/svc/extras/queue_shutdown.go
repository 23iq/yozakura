package extras

// Shutdown empties the queue for a daemon stop or reload without blocking:
// queued jobs are dropped (cancelled) and a running user-level job is
// stopped. A running system or AUR install (pacman/dnf must never be
// killed mid-transaction) is left running, detached: its context is never
// cancelled, it runs in its own process group and writes to a file, not a
// pipe, so it finishes after the daemon is gone. log gets one line per
// dropped or detached job.
func (q *Queue) Shutdown(log func(string)) {
	q.mu.Lock()
	dropped := q.pending
	q.pending = nil
	var out []Progress
	for _, j := range dropped {
		q.record(j, JobCancelled)
		j.prog.State = JobCancelled
		out = append(out, j.prog)
	}
	cur := q.current
	detach := cur != nil && !cur.cancellable()
	if cur != nil && !detach {
		cur.cancelled = true
		if cur.cancel != nil {
			cur.cancel()
		}
	}
	q.mu.Unlock()
	for _, p := range out {
		log("dropping queued " + p.Job)
		q.send(p)
	}
	if detach {
		log("leaving " + cur.ID + " running (a system install is never cut off)")
	}
}

// Quiet runs fn while no progress is emitted (a subscriber's snapshot).
func (q *Queue) Quiet(fn func()) {
	q.emitMu.Lock()
	defer q.emitMu.Unlock()
	fn()
}
