package ipc

import (
	"testing"
	"time"
)

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

// The subscribe request's clientId names the stream for the services (the
// preview relay waits only for the main shell, "shell").
func TestSubscriberCarriesClientID(t *testing.T) {
	got := make(chan string, 1)
	conn, _ := startServer(t, &Service{
		Name: "t",
		Subscribe: func(sub *Subscriber) {
			got <- sub.ClientID
			<-sub.StopCh()
		},
	})
	_, _ = conn.Write([]byte(`{"id":1,"method":"subscribe","params":{"clientId":"shell","services":["t"]}}` + "\n"))
	select {
	case id := <-got:
		if id != "shell" {
			t.Fatalf("ClientID %q, want shell", id)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("not subscribed")
	}
}
