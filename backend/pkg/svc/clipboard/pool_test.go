package clipboard

import (
	"fmt"
	"sync"
	"testing"
	"time"
)

// Each store holds at most one SQLite connection. Every store operation,
// run concurrently from many goroutines, must complete (a nested query on
// the single connection would deadlock) and the pool must never grow.
func TestStoreSingleConnectionUnderConcurrency(t *testing.T) {
	st, err := newStore(testPaths(t))
	if err != nil {
		t.Fatal(err)
	}
	defer st.close()
	for i := 0; i < 5; i++ {
		if ok, err := st.insertUnpinned("text/plain", []byte(fmt.Sprintf("seed-%d", i)), false, 6); !ok || err != nil {
			t.Fatalf("seed: %v %v", ok, err)
		}
	}
	if err := st.togglePin(itemID{id: 1}); err != nil {
		t.Fatal(err)
	}

	var wg sync.WaitGroup
	for g := 0; g < 8; g++ {
		wg.Add(1)
		go func(g int) {
			defer wg.Done()
			for i := 0; i < 15; i++ {
				_, _ = st.insertUnpinned("text/plain", []byte(fmt.Sprintf("g%d-%d", g, i)), false, 4)
				items := st.listItems()
				_ = st.reorder(itemID{id: 2}, i%3)
				_ = st.swap(itemID{id: 2}, itemID{id: 3})
				_, _ = st.getContent(itemID{id: 2})
				_ = st.setAlias(itemID{pinned: true, id: 1}, fmt.Sprintf("a%d", i))
				_, _, _ = st.copyRow(itemID{pinned: true, id: 1})
				if len(items) > 0 {
					if id, ok := parseID(items[len(items)-1]["id"].(string)); ok {
						_ = st.togglePin(id)
					}
				}
			}
		}(g)
	}
	done := make(chan struct{})
	go func() { wg.Wait(); close(done) }()
	select {
	case <-done:
	case <-time.After(60 * time.Second):
		t.Fatal("store operations deadlocked on the single connection")
	}

	if n := st.pinned.Stats().MaxOpenConnections; n != 1 {
		t.Fatalf("pinned pool limit = %d, want 1", n)
	}
	if n := st.unpinned.Stats().MaxOpenConnections; n != 1 {
		t.Fatalf("unpinned pool limit = %d, want 1", n)
	}
	if n := st.listItems(); len(n) == 0 {
		t.Fatal("history empty after concurrent use")
	}
}

// moveRowsTo reads one store while writing another; with one connection
// per store it must still complete.
func TestTmpModeMoveWithSingleConnection(t *testing.T) {
	t.Setenv("XDG_RUNTIME_DIR", t.TempDir())
	st, err := newStore(testPaths(t))
	if err != nil {
		t.Fatal(err)
	}
	defer st.close()
	for i := 0; i < 10; i++ {
		if ok, _ := st.insertUnpinned("text/plain", []byte(fmt.Sprintf("m%d", i)), false, 2); !ok {
			t.Fatal("insert failed")
		}
	}
	if err := st.setTmpMode(true); err != nil {
		t.Fatal(err)
	}
	if n := len(st.listItems()); n != 10 {
		t.Fatalf("items after move = %d, want 10", n)
	}
}

// An idle store gives its connection (and SQLite instance) back.
func TestStoreReleasesIdleConnection(t *testing.T) {
	old := dbIdleTimeout
	dbIdleTimeout = 50 * time.Millisecond
	t.Cleanup(func() { dbIdleTimeout = old })

	st, err := newStore(testPaths(t))
	if err != nil {
		t.Fatal(err)
	}
	defer st.close()
	if ok, _ := st.insertUnpinned("text/plain", []byte("x"), false, 1); !ok {
		t.Fatal("insert failed")
	}
	deadline := time.Now().Add(5 * time.Second)
	for st.unpinned.Stats().OpenConnections != 0 || st.pinned.Stats().OpenConnections != 0 {
		if time.Now().After(deadline) {
			t.Fatalf("idle connections kept: unpinned=%d pinned=%d",
				st.unpinned.Stats().OpenConnections, st.pinned.Stats().OpenConnections)
		}
		time.Sleep(20 * time.Millisecond)
	}
	// The next access reopens transparently.
	if items := st.listItems(); len(items) != 1 {
		t.Fatalf("items after reopen = %v", items)
	}
}
