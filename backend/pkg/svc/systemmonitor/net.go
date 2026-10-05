package systemmonitor

import (
	"bufio"
	"io"
	"os"
	"strconv"
	"strings"
	"time"
)

// Net is the throughput of every non-loopback interface since the previous
// sample, in bytes per second.
type Net struct {
	RxBps float64 `json:"rx_bps"`
	TxBps float64 `json:"tx_bps"`
}

// netSampler turns the cumulative /proc/net/dev counters into rates.
type netSampler struct {
	prevRx, prevTx int64
	prevAt         time.Time
}

// parseNetDev sums the receive/transmit byte counters of /proc/net/dev,
// skipping loopback and virtual bridges of containers.
func parseNetDev(r io.Reader) (rx, tx int64) {
	sc := bufio.NewScanner(r)
	for sc.Scan() {
		line := sc.Text()
		colon := strings.IndexByte(line, ':')
		if colon < 0 {
			continue
		}
		name := strings.TrimSpace(line[:colon])
		if name == "lo" || strings.HasPrefix(name, "veth") || strings.HasPrefix(name, "docker") || strings.HasPrefix(name, "virbr") {
			continue
		}
		f := strings.Fields(line[colon+1:])
		if len(f) < 9 {
			continue
		}
		r, err1 := strconv.ParseInt(f[0], 10, 64)
		t, err2 := strconv.ParseInt(f[8], 10, 64)
		if err1 != nil || err2 != nil {
			continue
		}
		rx += r
		tx += t
	}
	return rx, tx
}

// rate returns bytes/s for the counters read at `now`; 0 on the first call
// or after a counter reset.
func (n *netSampler) rate(rx, tx int64, now time.Time) Net {
	defer func() { n.prevRx, n.prevTx, n.prevAt = rx, tx, now }()
	if n.prevAt.IsZero() || rx < n.prevRx || tx < n.prevTx {
		return Net{}
	}
	secs := now.Sub(n.prevAt).Seconds()
	if secs <= 0 {
		return Net{}
	}
	return Net{RxBps: float64(rx-n.prevRx) / secs, TxBps: float64(tx-n.prevTx) / secs}
}

func (n *netSampler) sample() Net {
	f, err := os.Open("/proc/net/dev")
	if err != nil {
		return Net{}
	}
	defer f.Close()
	rx, tx := parseNetDev(f)
	return n.rate(rx, tx, time.Now())
}
