package extras

// Shutdown empties the queue for a daemon stop or reload: queued jobs are
// dropped (cancelled), a running user-level job is stopped, and a running
// system or AUR install (pacman/dnf must never be killed mid-transaction)
// is waited for. log receives one line per dropped or awaited job.
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
	wait := cur != nil && !cur.cancellable()
	if cur != nil && !wait {
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
	if wait {
		log("waiting for " + cur.ID + " to finish")
	}
	q.Wait()
}

// Quiet runs fn while no progress is emitted (a subscriber's snapshot).
func (q *Queue) Quiet(fn func()) {
	q.emitMu.Lock()
	defer q.emitMu.Unlock()
	fn()
}
