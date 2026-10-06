package extras

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"

	"yozakura/backend/pkg/paths"
)

// Runner runs one command, streaming its merged output line by line.
type Runner interface {
	Run(ctx context.Context, argv []string, env []string, line func(string)) (exitCode int, err error)
}

// PostHook runs after a successful install for a post action
// "<prefix>:<arg>"; it receives arg.
type PostHook func(arg string) error

var (
	postMu    sync.RWMutex
	postHooks = map[string]PostHook{}
)

// RegisterPost registers fn for post actions "<prefix>:<arg>".
func RegisterPost(prefix string, fn PostHook) {
	postMu.Lock()
	defer postMu.Unlock()
	postHooks[prefix] = fn
}

func postHook(prefix string) PostHook {
	postMu.RLock()
	defer postMu.RUnlock()
	return postHooks[prefix]
}

// jobEnv keeps tool output parseable.
var jobEnv = []string{"LC_ALL=C", "LANG=C"}

// Cancel errors.
var (
	ErrUnknownJob     = errors.New("no such queued or running job")
	ErrNotCancellable = errors.New("can't stop a running system install")
)

type qjob struct {
	Job
	batch     int
	cancelled bool
	cancel    context.CancelFunc
	prog      Progress
}

// cancellable reports whether a running job of this kind may be
// interrupted: pacman/dnf (direct, via the AUR helper, multilib or
// upgrade) must never be killed mid-transaction.
func (j *qjob) cancellable() bool {
	switch j.Kind {
	case KindFlatpak, KindNpm, KindScript, KindShell, KindOllama:
		return true
	}
	return false
}

// Queue runs install jobs one at a time, in order. Safe for concurrent use.
type Queue struct {
	run    Runner
	emit   func(Progress)
	notify func(title, body string)

	mu       sync.Mutex
	emitMu   sync.Mutex
	pending  []*qjob
	current  *qjob
	working  bool
	batch    int
	outcome  map[int]map[string]string // batch -> job id -> failed|cancelled
	logDir   string
	post     func(entryID string) []string // entry id -> post actions
	after    func(Job, bool)
	fetch    func(ctx context.Context, url string) (string, error)
	idleDone chan struct{}
}

// NewQueue returns an idle queue. emit receives every state change, in
// order per job; notify is called once per finished (done or failed) job.
func NewQueue(run Runner, emit func(Progress), notify func(title, body string)) *Queue {
	return &Queue{run: run, emit: emit, notify: notify, outcome: map[int]map[string]string{},
		logDir: filepath.Join(paths.New().StateDir, "extras"), fetch: DownloadScript}
}

// SetPostActions sets the lookup of an entry's post actions ("apphook:<id>").
func (q *Queue) SetPostActions(fn func(entryID string) []string) {
	q.mu.Lock()
	q.post = fn
	q.mu.Unlock()
}

// SetAfterJob sets a callback run after each finished job and its post
// actions, before the final state is emitted (used to re-detect).
func (q *Queue) SetAfterJob(fn func(job Job, ok bool)) {
	q.mu.Lock()
	q.after = fn
	q.mu.Unlock()
}

// Enqueue appends one batch of jobs (as returned by Plan). The "queued"
// events are emitted before the jobs become runnable, so they always
// precede the jobs' later events.
func (q *Queue) Enqueue(jobs []Job) {
	if len(jobs) == 0 {
		return
	}
	q.mu.Lock()
	q.batch++
	b := q.batch
	q.mu.Unlock()
	batch := make([]*qjob, 0, len(jobs))
	for _, j := range jobs {
		qj := &qjob{Job: j, batch: b}
		qj.prog = Progress{Job: j.ID, Kind: j.Kind, Entries: j.Entries, State: JobQueued, Percent: -1}
		batch = append(batch, qj)
		q.send(qj.prog)
	}
	q.mu.Lock()
	q.pending = append(q.pending, batch...)
	start := !q.working
	if start {
		q.working = true
		q.idleDone = make(chan struct{})
	}
	q.mu.Unlock()
	if start {
		go q.loop()
	}
}

// Cancel cancels a queued job, or stops a running user-level job
// (flatpak, npm, scripts). A running system or AUR install cannot be
// stopped: ErrNotCancellable.
func (q *Queue) Cancel(jobID string) error {
	q.mu.Lock()
	if c := q.current; c != nil && c.ID == jobID {
		defer q.mu.Unlock()
		if !c.cancellable() {
			return ErrNotCancellable
		}
		c.cancelled = true
		if c.cancel != nil {
			c.cancel()
		}
		return nil
	}
	var gone *qjob
	for i, j := range q.pending {
		if j.ID == jobID {
			q.pending = append(q.pending[:i], q.pending[i+1:]...)
			gone = j
			break
		}
	}
	if gone == nil {
		q.mu.Unlock()
		return ErrUnknownJob
	}
	q.record(gone, JobCancelled)
	gone.prog.State = JobCancelled
	p := gone.prog
	q.pruneBatch(gone.batch)
	q.mu.Unlock()
	q.send(p)
	return nil
}

// record stores a non-done outcome for dependents. Caller holds mu.
func (q *Queue) record(j *qjob, state string) {
	m := q.outcome[j.batch]
	if m == nil {
		m = map[string]string{}
		q.outcome[j.batch] = m
	}
	m[j.ID] = state
}

// pruneBatch drops outcomes of a batch with no queued or running job left.
// Caller holds mu.
func (q *Queue) pruneBatch(b int) {
	if q.current != nil && q.current.batch == b {
		return
	}
	for _, j := range q.pending {
		if j.batch == b {
			return
		}
	}
	delete(q.outcome, b)
}

// Jobs returns the state of the running and queued jobs.
func (q *Queue) Jobs() []Progress {
	q.mu.Lock()
	defer q.mu.Unlock()
	var out []Progress
	if q.current != nil {
		out = append(out, q.current.prog)
	}
	for _, j := range q.pending {
		out = append(out, j.prog)
	}
	return out
}

// Wait blocks until the queue is idle (tests, shutdown).
func (q *Queue) Wait() {
	q.mu.Lock()
	ch := q.idleDone
	q.mu.Unlock()
	if ch != nil {
		<-ch
	}
}

func (q *Queue) send(p Progress) {
	if q.emit == nil {
		return
	}
	q.emitMu.Lock()
	defer q.emitMu.Unlock()
	q.emit(p)
}

func (q *Queue) loop() {
	for {
		q.mu.Lock()
		if len(q.pending) == 0 {
			q.current = nil
			q.working = false
			close(q.idleDone)
			q.mu.Unlock()
			return
		}
		j := q.pending[0]
		q.pending = q.pending[1:]
		depState := ""
		for _, d := range j.Deps {
			switch q.outcome[j.batch][d] {
			case JobCancelled:
				depState = JobCancelled
			case JobFailed:
				if depState == "" {
					depState = JobFailed
				}
			}
		}
		ctx, cancel := context.WithCancel(context.Background())
		j.cancel = cancel
		q.current = j
		q.mu.Unlock()

		switch depState {
		case JobCancelled:
			q.finish(j, JobCancelled, "")
		case JobFailed:
			q.finish(j, JobFailed, ReasonDependency)
		default:
			state, reason := q.execute(ctx, j)
			q.finish(j, state, reason)
		}
		cancel()
	}
}

// finish records the outcome, runs post actions and callbacks, emits the
// final state and notifies. An auth cancel cancels the rest of the batch.
func (q *Queue) finish(j *qjob, state, reason string) {
	q.mu.Lock()
	post, after := q.post, q.after
	q.mu.Unlock()
	ok := state == JobDone
	if ok && post != nil {
		for _, id := range j.Entries {
			runPost(id, post(id))
		}
	}
	if after != nil {
		after(j.Job, ok)
	}
	var dropped []Progress
	q.mu.Lock()
	if !ok {
		q.record(j, state)
	}
	j.prog.State, j.prog.Reason = state, reason
	if ok {
		j.prog.Percent = 100
	}
	final := j.prog
	if reason == ReasonAuthCancelled {
		keep := q.pending[:0]
		for _, p := range q.pending {
			if p.batch != j.batch {
				keep = append(keep, p)
				continue
			}
			p.prog.State, p.prog.Reason = JobCancelled, ReasonAuthCancelled
			dropped = append(dropped, p.prog)
		}
		q.pending = keep
	}
	q.current = nil
	q.pruneBatch(j.batch)
	q.mu.Unlock()
	q.send(final)
	for _, p := range dropped {
		q.send(p)
	}
	if q.notify == nil || state == JobCancelled {
		return
	}
	names := strings.Join(j.Names, ", ")
	if names == "" {
		names = strings.Join(j.Entries, ", ")
	}
	if ok && j.Kind == KindLogin {
		q.notify("Login shell changed", "Log out and in again to use it.")
	} else if ok {
		q.notify(names+" installed", "")
	} else {
		q.notify("Installing "+names+" failed", reasonText(reason)+" Open Extras to retry.")
	}
}

func runPost(id string, actions []string) {
	for _, a := range actions {
		prefix, arg, found := strings.Cut(a, ":")
		fn := postHook(prefix)
		if !found || fn == nil {
			continue
		}
		if err := fn(arg); err != nil {
			fmt.Fprintf(os.Stderr, "extras: %s: post %s: %v\n", id, a, err)
		}
	}
}

func reasonText(r string) string {
	switch r {
	case ReasonAuthCancelled:
		return "Authentication was cancelled."
	case ReasonNeedsSync:
		return "Package databases are out of date; update the system and retry."
	case ReasonNetwork:
		return "No network connection."
	case ReasonDBLocked:
		return "The package database is locked by another program."
	case ReasonDiskFull:
		return "No space left on device."
	case ReasonDependency:
		return "A required component failed to install."
	}
	return "The installer reported an error."
}
