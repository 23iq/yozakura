package term

import (
	"context"
	"errors"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"yozakura/backend/pkg/termlook"
)

// Previews run one at a time; the same request in flight is shared.
func TestFetchRunnerOneAtATimeAndCoalesces(t *testing.T) {
	r := newFetchRunner()
	var running, peak, calls atomic.Int32
	fn := func(ctx context.Context) (termlook.FetchPreviewResult, error) {
		calls.Add(1)
		n := running.Add(1)
		for {
			p := peak.Load()
			if n <= p || peak.CompareAndSwap(p, n) {
				break
			}
		}
		time.Sleep(30 * time.Millisecond)
		running.Add(-1)
		return termlook.FetchPreviewResult{Exact: true}, nil
	}
	var wg sync.WaitGroup
	for _, look := range []string{"a", "a", "a", "b", "c"} {
		wg.Add(1)
		go func() {
			defer wg.Done()
			res, err := r.do(look, "p", 5*time.Second, fn)
			if err != nil || !res.Exact {
				t.Errorf("%s: %+v %v", look, res, err)
			}
		}()
		time.Sleep(2 * time.Millisecond)
	}
	wg.Wait()
	if peak.Load() != 1 {
		t.Errorf("%d previews ran at once", peak.Load())
	}
	if calls.Load() != 3 {
		t.Errorf("fastfetch ran %d times for 3 looks", calls.Load())
	}
}

// A newer request for the same look with other parameters (a palette
// change) cancels the older one.
func TestFetchRunnerCancelsTheSupersededRun(t *testing.T) {
	r := newFetchRunner()
	started := make(chan struct{})
	var oldErr error
	done := make(chan struct{})
	go func() {
		defer close(done)
		_, oldErr = r.do("a", "old", 5*time.Second, func(ctx context.Context) (termlook.FetchPreviewResult, error) {
			close(started)
			<-ctx.Done()
			return termlook.FetchPreviewResult{Reason: "error"}, nil // the sample, like FetchPreview
		})
	}()
	<-started
	res, err := r.do("a", "new", 5*time.Second, func(context.Context) (termlook.FetchPreviewResult, error) {
		return termlook.FetchPreviewResult{Exact: true}, nil
	})
	<-done
	if !errors.Is(oldErr, errSuperseded) {
		t.Errorf("old run: %v", oldErr)
	}
	if err != nil || !res.Exact {
		t.Errorf("new run: %+v %v", res, err)
	}
}

// A request that waits longer than its budget gives up without running.
func TestFetchRunnerWaitIsBounded(t *testing.T) {
	r := newFetchRunner()
	release := make(chan struct{})
	go func() {
		_, _ = r.do("a", "p", 5*time.Second, func(context.Context) (termlook.FetchPreviewResult, error) {
			<-release
			return termlook.FetchPreviewResult{}, nil
		})
	}()
	time.Sleep(20 * time.Millisecond)
	ran := false
	_, err := r.do("b", "p", 50*time.Millisecond, func(context.Context) (termlook.FetchPreviewResult, error) {
		ran = true
		return termlook.FetchPreviewResult{}, nil
	})
	close(release)
	if ran || !errors.Is(err, context.DeadlineExceeded) {
		t.Errorf("ran %v err %v", ran, err)
	}
}
