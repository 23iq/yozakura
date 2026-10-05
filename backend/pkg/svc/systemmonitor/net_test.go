package systemmonitor

import (
	"strings"
	"testing"
	"time"
)

const netDev = `Inter-|   Receive                                                |  Transmit
 face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
    lo: 5000      10    0    0    0     0          0         0     5000      10    0    0    0     0       0          0
  eth0: 1000      20    0    0    0     0          0         0      400      12    0    0    0     0       0          0
 wlan0: 3000      20    0    0    0     0          0         0      600      12    0    0    0     0       0          0
veth12: 9999      20    0    0    0     0          0         0     9999      12    0    0    0     0       0          0
`

func TestParseNetDevSkipsLoopbackAndVirtual(t *testing.T) {
	rx, tx := parseNetDev(strings.NewReader(netDev))
	if rx != 4000 || tx != 1000 {
		t.Fatalf("rx=%d tx=%d, want 4000/1000", rx, tx)
	}
}

func TestNetRate(t *testing.T) {
	var n netSampler
	t0 := time.Unix(100, 0)
	if r := n.rate(1000, 500, t0); r.RxBps != 0 || r.TxBps != 0 {
		t.Fatalf("first sample must be zero, got %+v", r)
	}
	r := n.rate(3000, 1500, t0.Add(2*time.Second))
	if r.RxBps != 1000 || r.TxBps != 500 {
		t.Fatalf("got %+v, want 1000/500 B/s", r)
	}
	if r := n.rate(10, 10, t0.Add(3*time.Second)); r.RxBps != 0 {
		t.Fatalf("counter reset must give zero, got %+v", r)
	}
}
