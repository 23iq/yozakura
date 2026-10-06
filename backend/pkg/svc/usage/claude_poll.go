package usage

import (
	"context"
	"errors"
	"sync"
	"time"
)

// ClaudePollInterval is the minimum time between two usage requests.
const ClaudePollInterval = 5 * time.Minute

// maxPollFailures halts polling after this many transient errors in a row.
const maxPollFailures = 3

// claudePoller runs the fetcher only while it is enabled (the shell's
// setting, usage.claudeLimits.enable) and someone is subscribed. Errors
// stop it silently: missing/expired credentials and 401/403 at once,
// network errors after maxPollFailures. A later enable call re-arms it.
type claudePoller struct {
	mu       sync.Mutex
	fetch    func(context.Context) (Limits, error)
	publish  func(Limits)
	interval time.Duration
	now      func() time.Time

	enabled  bool
	subs     int
	halted   bool
	failures int
	last     time.Time
	cancel   context.CancelFunc
	done     chan struct{}
}

func newClaudePoller(fetch func(context.Context) (Limits, error), publish func(Limits)) *claudePoller {
	return &claudePoller{fetch: fetch, publish: publish, interval: ClaudePollInterval, now: time.Now}
}

// SetEnabled applies the shell setting; enabling re-arms a halted poller.
func (p *claudePoller) SetEnabled(on bool) {
	p.mu.Lock()
	p.enabled = on
	if on {
		p.halted = false
		p.failures = 0
	}
	p.mu.Unlock()
	p.reconcile()
}

// AddSubscriber / RemoveSubscriber track live subscriptions.
func (p *claudePoller) AddSubscriber() {
	p.mu.Lock()
	p.subs++
	p.mu.Unlock()
	p.reconcile()
}

func (p *claudePoller) RemoveSubscriber() {
	p.mu.Lock()
	if p.subs > 0 {
		p.subs--
	}
	p.mu.Unlock()
	p.reconcile()
}

// Running reports whether the poll loop is active.
func (p *claudePoller) Running() bool {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.cancel != nil
}

// Stop ends the loop and waits for it.
func (p *claudePoller) Stop() {
	p.mu.Lock()
	p.enabled = false
	p.mu.Unlock()
	p.reconcile()
}

func (p *claudePoller) reconcile() {
	p.mu.Lock()
	want := p.enabled && p.subs > 0 && !p.halted
	switch {
	case want && p.cancel == nil:
		ctx, cancel := context.WithCancel(context.Background())
		p.cancel = cancel
		p.done = make(chan struct{})
		go p.loop(ctx, p.done)
		p.mu.Unlock()
	case !want && p.cancel != nil:
		cancel, done := p.cancel, p.done
		p.cancel, p.done = nil, nil
		p.mu.Unlock()
		cancel()
		<-done
	default:
		p.mu.Unlock()
	}
}

func (p *claudePoller) loop(ctx context.Context, done chan struct{}) {
	defer close(done)
	for {
		p.mu.Lock()
		wait := p.interval - p.now().Sub(p.last)
		p.mu.Unlock()
		if wait > 0 {
			select {
			case <-ctx.Done():
				return
			case <-time.After(wait):
			}
		}
		if !p.poll(ctx) {
			return
		}
	}
}

// poll fetches once; false means the poller halted itself.
func (p *claudePoller) poll(ctx context.Context) bool {
	l, err := p.fetch(ctx)
	if ctx.Err() != nil {
		return false
	}
	p.mu.Lock()
	p.last = p.now()
	if err == nil {
		p.failures = 0
		p.mu.Unlock()
		p.publish(l)
		return true
	}
	p.failures++
	halt := errors.Is(err, ErrNoCredentials) || errors.Is(err, ErrUnauthorized) || p.failures >= maxPollFailures
	var cancel context.CancelFunc
	if halt {
		p.halted = true
		cancel = p.cancel // the loop exits on its own; reconcile must not wait
		p.cancel, p.done = nil, nil
	}
	p.mu.Unlock()
	if cancel != nil {
		cancel()
	}
	return !halt
}
