package server

import (
	"bufio"
	"encoding/json"
	"net"
	"testing"
	"time"

	"yozakura/backend/pkg/yozd/ipc"
	"yozakura/backend/pkg/yozd/ipc/mock"
)

// chanComp feeds events from a test-owned channel.
type chanComp struct {
	*mock.Compositor
	ch chan ipc.Event
}

func (c chanComp) Subscribe() (<-chan ipc.Event, error) { return c.ch, nil }

func TestKeyboardLayoutEventCachedAndBroadcast(t *testing.T) {
	comp := chanComp{mock.NewCompositor(), make(chan ipc.Event, 1)}
	srv, client := net.Pipe()
	defer srv.Close()
	defer client.Close()
	s := &Server{compositor: comp, cache: ipc.NewStateCache(), clients: map[net.Conn]struct{}{srv: {}}}
	go s.watchEvents()

	comp.ch <- ipc.Event{Type: ipc.EventKeyboardLayout, Payload: map[string]interface{}{"name": "Russian"}}

	_ = client.SetReadDeadline(time.Now().Add(2 * time.Second))
	line, err := bufio.NewReader(client).ReadBytes('\n')
	if err != nil {
		t.Fatalf("no broadcast: %v", err)
	}
	var n struct {
		Method string `json:"method"`
		State  struct {
			KeyboardLayout map[string]interface{} `json:"keyboard_layout"`
		} `json:"state"`
	}
	if err := json.Unmarshal(line, &n); err != nil {
		t.Fatal(err)
	}
	if n.Method != "Event.KeyboardLayout" || n.State.KeyboardLayout["name"] != "Russian" {
		t.Fatalf("broadcast = %s", line)
	}
	if got := s.getKeyboardLayout(); got["name"] != "Russian" {
		t.Fatalf("cached layout = %v", got)
	}
}
