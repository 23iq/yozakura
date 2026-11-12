package term

import (
	"context"
	"errors"
	"sync"
	"time"

	"yozakura/backend/pkg/termlook"
)

// errSuperseded: a newer preview of the same look (another palette) came
// in while this one waited or ran.
var errSuperseded = errors.New("term: preview superseded by a newer one")

// fetchRunner runs one greeting preview at a time (each is a fastfetch
// run): a request for a look already in flight with the same parameters
// shares its result, one with other parameters (a palette change)
// cancels the older; the rest wait their turn.
type fetchRunner struct {
	mu    sync.Mutex
	sem   chan struct{}
	calls map[string]*fetchCall
}

type fetchCall struct {
	params string
	cancel context.CancelCauseFunc
	done   chan struct{}
	res    termlook.FetchPreviewResult
	err    error
}

func newFetchRunner() *fetchRunner {
	return &fetchRunner{sem: make(chan struct{}, 1), calls: map[string]*fetchCall{}}
}

// do runs fn for look (params: everything else the result depends on)
// within budget, waiting for the runs before it.
func (r *fetchRunner) do(look, params string, budget time.Duration, fn func(context.Context) (termlook.FetchPreviewResult, error)) (termlook.FetchPreviewResult, error) {
	r.mu.Lock()
	if c := r.calls[look]; c != nil {
		if c.params == params {
			r.mu.Unlock()
			<-c.done
			return c.res, c.err
		}
		c.cancel(errSuperseded)
	}
	ctx, cancel := context.WithCancelCause(context.Background())
	ctx, stop := context.WithTimeout(ctx, budget)
	c := &fetchCall{params: params, cancel: cancel, done: make(chan struct{})}
	r.calls[look] = c
	r.mu.Unlock()

	defer func() {
		stop()
		cancel(nil)
		r.mu.Lock()
		if r.calls[look] == c {
			delete(r.calls, look)
		}
		r.mu.Unlock()
		close(c.done)
	}()
	select {
	case r.sem <- struct{}{}:
	case <-ctx.Done():
		c.err = context.Cause(ctx)
		return c.res, c.err
	}
	defer func() { <-r.sem }()
	if err := context.Cause(ctx); err != nil {
		c.err = err
		return c.res, c.err
	}
	c.res, c.err = fn(ctx)
	if cause := context.Cause(ctx); errors.Is(cause, errSuperseded) {
		c.res, c.err = termlook.FetchPreviewResult{}, cause
	}
	return c.res, c.err
}
