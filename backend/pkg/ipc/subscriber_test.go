package ipc

import "testing"

// TryPush reports a drop on a full buffer; Push keeps dropping silently.
func TestSubscriberTryPushReportsDrop(t *testing.T) {
	s := NewSubscriber(1)
	if !s.TrySend("a", 1) {
		t.Fatal("first event refused by an empty buffer")
	}
	if s.TrySend("b", 2) {
		t.Fatal("second event reported queued in a full buffer")
	}
	s.Push(ServiceEvent{Service: "c"}) // must not block
	if ev := <-s.Events; ev.Service != "a" || len(s.Events) != 0 {
		t.Fatalf("buffer held %+v and %d more", ev, len(s.Events))
	}
}
