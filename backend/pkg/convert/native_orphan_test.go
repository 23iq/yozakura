package convert

import (
	"context"
	"errors"
	"path/filepath"
	"testing"
	"time"
)

// A native step a cancel gave up on keeps its slot until it really ends:
// the plan reports when it settled, and no more than cap(nativeSlots)
// native steps ever run, so stop / start cycles cannot pile up decodes.
func TestNativeOrphansAreBounded(t *testing.T) {
	// earlier tests' hung steps may still be draining
	for i := 0; i < cap(nativeSlots); i++ {
		nativeSlots <- struct{}{}
	}
	for i := 0; i < cap(nativeSlots); i++ {
		<-nativeSlots
	}
	block := make(chan struct{})
	hang := func() error { <-block; return nil }
	var plans []*Plan
	for i := 0; i < cap(nativeSlots); i++ {
		work := t.TempDir()
		p := &Plan{Work: work, Out: filepath.Join(work, "out"), Steps: []Step{{Native: hang, Out: "out"}}}
		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Millisecond)
		if err := p.Run(ctx, nil); !errors.Is(err, context.DeadlineExceeded) {
			t.Fatalf("run %d: %v", i, err)
		}
		cancel()
		select {
		case <-p.Settled():
			t.Fatal("settled while its step still runs")
		default:
		}
		plans = append(plans, p)
	}
	// every slot is held by an orphan: the next native step waits
	ran := false
	work := t.TempDir()
	p := &Plan{Work: work, Out: filepath.Join(work, "out"), Steps: []Step{{Native: func() error { ran = true; return nil }, Out: "out"}}}
	ctx, cancel := context.WithTimeout(context.Background(), 50*time.Millisecond)
	defer cancel()
	if err := p.Run(ctx, nil); !errors.Is(err, context.DeadlineExceeded) || ran {
		t.Fatalf("a native step ran past the cap: %v ran=%v", err, ran)
	}
	close(block)
	for _, p := range plans {
		select {
		case <-p.Settled():
		case <-time.After(5 * time.Second):
			t.Fatal("an orphan never settled")
		}
	}
	var nilPlan *Plan
	<-nilPlan.Settled()
}
