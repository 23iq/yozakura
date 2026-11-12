package server

import (
	"bufio"
	"encoding/json"
	"net"
	"testing"
	"time"

	"yozakura/backend/pkg/yozd/client"
	"yozakura/backend/pkg/yozd/ipc"
	"yozakura/backend/pkg/yozd/ipc/mock"
)

type idleFlip struct {
	id     uint32
	isIdle bool
	seq    uint64
}

func newTestIdleManager() (*IdleManager, *[]idleFlip) {
	im := &IdleManager{monitors: map[uint32]*idleMonitor{}, inhibitors: map[uint32]*idleInhibitor{}}
	var got []idleFlip
	im.SetIdleMonitorCallback(func(id uint32, isIdle bool, seq uint64) {
		got = append(got, idleFlip{id, isIdle, seq})
	})
	return im, &got
}

// Both transitions are reported, with a growing seq; a repeated state or a
// destroyed monitor reports nothing.
func TestSetMonitorIdleReportsBothTransitions(t *testing.T) {
	im, got := newTestIdleManager()
	a := &idleMonitor{id: 1}
	b := &idleMonitor{id: 2}
	im.monitors[1], im.monitors[2] = a, b

	im.setMonitorIdle(a, true)
	im.setMonitorIdle(a, true) // no change
	im.setMonitorIdle(b, true)
	im.setMonitorIdle(a, false)
	im.setMonitorIdle(a, false) // no change
	b.deleted = true
	im.setMonitorIdle(b, false) // destroyed

	want := []idleFlip{{1, true, 1}, {2, true, 2}, {1, false, 3}}
	if len(*got) != len(want) {
		t.Fatalf("flips = %+v, want %+v", *got, want)
	}
	for i, f := range want {
		if (*got)[i] != f {
			t.Fatalf("flip %d = %+v, want %+v", i, (*got)[i], f)
		}
	}
}

// A flip goes out to subscribers as Event.IdleMonitorChanged {id, is_idle, seq}.
func TestIdleMonitorChangeBroadcast(t *testing.T) {
	srv, cli := net.Pipe()
	defer srv.Close()
	defer cli.Close()
	im, _ := newTestIdleManager()
	s := &Server{compositor: mock.NewCompositor(), cache: ipc.NewStateCache(), clients: map[net.Conn]struct{}{srv: {}}, idleMgr: im}
	im.SetIdleMonitorCallback(s.handleIdleMonitorChanged)
	mon := &idleMonitor{id: 4}
	im.monitors[4] = mon

	r := bufio.NewReader(cli)
	for i, want := range []bool{true, false} {
		im.setMonitorIdle(mon, want)
		_ = cli.SetReadDeadline(time.Now().Add(2 * time.Second))
		line, err := r.ReadBytes('\n')
		if err != nil {
			t.Fatalf("no broadcast for is_idle=%v: %v", want, err)
		}
		var n struct {
			Method string `json:"method"`
			Params struct {
				ID     uint32 `json:"id"`
				IsIdle bool   `json:"is_idle"`
				Seq    uint64 `json:"seq"`
			} `json:"params"`
		}
		if err := json.Unmarshal(line, &n); err != nil {
			t.Fatal(err)
		}
		if n.Method != client.IdleMonitorChangedEvent || n.Params.ID != 4 || n.Params.IsIdle != want || n.Params.Seq != uint64(i+1) {
			t.Fatalf("broadcast = %s", line)
		}
	}
}

// The subscription's opening State.Dump advertises the idle events only when
// the idle manager is up.
func TestStreamFeatures(t *testing.T) {
	s := &Server{}
	if f := s.streamFeatures(); len(f) != 0 {
		t.Fatalf("features without idle manager = %v", f)
	}
	s.idleMgr, _ = newTestIdleManager()
	data, err := json.Marshal(Notification{JSONRPC: "2.0", Method: "State.Dump", Features: s.streamFeatures()})
	if err != nil {
		t.Fatal(err)
	}
	var n struct {
		Features []string `json:"features"`
	}
	if err := json.Unmarshal(data, &n); err != nil || len(n.Features) != 1 || n.Features[0] != client.FeatureIdleEvents {
		t.Fatalf("State.Dump = %s", data)
	}
}
