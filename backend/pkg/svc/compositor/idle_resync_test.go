package compositor

import (
	"encoding/json"
	"fmt"
	"testing"
	"time"
)

// A producer overflowing a subscriber's queue while its reader drains it
// concurrently must never block (it holds the hub lock and runs on the
// daemon stream's reader goroutine): the overflow drain is non-blocking.
func TestIdleHubOverflowWithConcurrentReader(t *testing.T) {
	for round := 0; round < 200; round++ {
		h := newIdleHub()
		ch, _, cancel := h.subscribe()
		for i := 1; i <= idleSubBuffer; i++ {
			h.change(json.RawMessage(fmt.Sprintf(`{"id":1,"is_idle":%t}`, i%2 == 0)))
		}
		stop := make(chan struct{})
		readerDone := make(chan struct{})
		go func() {
			defer close(readerDone)
			for {
				select {
				case <-ch:
				case <-stop:
					return
				}
			}
		}()
		done := make(chan struct{})
		go func() {
			defer close(done)
			for i := 0; i < 500; i++ {
				h.change(json.RawMessage(`{"id":1,"is_idle":true}`))
			}
		}()
		select {
		case <-done:
		case <-time.After(5 * time.Second):
			t.Fatalf("round %d: producer blocked while holding the hub lock", round)
		}
		close(stop)
		<-readerDone
		cancel()
	}
}
