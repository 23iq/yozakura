package transfers

import (
	"context"
	"errors"
	"net/http"
	"net/http/cookiejar"
	"reflect"
	"sort"
	"strconv"
	"strings"
	"time"
)

// Torrent clients: qBittorrent (WebUI API), Transmission (RPC) and Deluge
// (deluge-web JSON-RPC). A client is only polled while its process runs,
// and only incomplete torrents are reported. Read-only: no actions.
func init() { register("torrents", func() Source { return newTorrentsSource() }) }

const (
	torrentDiscoverEvery = 5 * time.Second
	torrentPollEvery     = 2 * time.Second
	torrentHTTPTimeout   = 2 * time.Second
)

// errTorrentGiveUp stops polling a client until its process restarts
// (wrong credentials: retrying would only trip the client's ban list).
var errTorrentGiveUp = errors.New("torrent client: giving up until restart")

type torrentClient interface {
	// procs are the process names (comm) that expose this client's API.
	procs() []string
	// poll returns the incomplete torrents.
	poll(ctx context.Context) ([]Transfer, error)
	// reset forgets sessions/cookies (process restarted).
	reset()
}

type torrentState struct {
	client  torrentClient
	pids    string // sorted pid list, to notice restarts
	running bool
	gaveUp  bool
	items   []Transfer
}

type torrentsSource struct {
	clients []*torrentState
	listPID func(names []string) map[string][]int
}

func newTorrentsSource() *torrentsSource {
	return &torrentsSource{listPID: pidsByComm}
}

// pidsByComm maps each running comm in names to its pids.
func pidsByComm(names []string) map[string][]int {
	set := map[string]bool{}
	for _, n := range names {
		set[n] = true
	}
	out := map[string][]int{}
	for _, p := range ListProcs(func(c string) bool { return set[c] }) {
		out[p.Comm] = append(out[p.Comm], p.PID)
	}
	return out
}

func newTorrentHTTP() *http.Client {
	jar, _ := cookiejar.New(nil)
	return &http.Client{Timeout: torrentHTTPTimeout, Jar: jar}
}

func (s *torrentsSource) Run(ctx context.Context, env *Env) {
	if s.clients == nil {
		s.clients = []*torrentState{
			{client: newQBittorrent(env.Options)},
			{client: newTransmission(env.Options)},
			{client: newDeluge(env.Options)},
		}
	}
	var last []Transfer
	var lastDiscover time.Time
	for {
		if time.Since(lastDiscover) >= torrentDiscoverEvery {
			lastDiscover = time.Now()
			s.discover()
		}
		items := s.pollAll(ctx)
		if !reflect.DeepEqual(items, last) {
			last = items
			env.Update(items)
		}
		wait := torrentDiscoverEvery
		for _, c := range s.clients {
			if c.running && !c.gaveUp {
				wait = torrentPollEvery
			}
		}
		if !sleepOrWake(ctx, wait, nil) {
			return
		}
	}
}

func (s *torrentsSource) discover() {
	var names []string
	for _, c := range s.clients {
		names = append(names, c.client.procs()...)
	}
	found := s.listPID(names)
	for _, c := range s.clients {
		var pids []string
		for _, n := range c.client.procs() {
			for _, pid := range found[n] {
				pids = append(pids, strconv.Itoa(pid))
			}
		}
		sort.Strings(pids)
		key := strings.Join(pids, ",")
		c.running = key != ""
		if key != c.pids {
			c.pids = key
			c.gaveUp = false
			c.client.reset()
		}
		if !c.running {
			c.items = nil
		}
	}
}

func (s *torrentsSource) pollAll(ctx context.Context) []Transfer {
	var out []Transfer
	for _, c := range s.clients {
		if !c.running || c.gaveUp {
			c.items = nil
			continue
		}
		items, err := c.client.poll(ctx)
		if errors.Is(err, errTorrentGiveUp) {
			c.gaveUp = true
			c.items = nil
			continue
		}
		if err != nil {
			// Starting up, WebUI disabled, wrong port: quietly try again
			c.items = nil
			continue
		}
		c.items = items
		out = append(out, items...)
	}
	return out
}

// torrentItem fills the fields shared by every client.
func torrentItem(client, icon, key, name, dir string) Transfer {
	it := Unknown()
	it.Key = key
	it.App = client
	it.AppIcon = icon
	it.Title = name
	it.Kind = KindDownload
	if dir != "" {
		it.Dir = dir
		if name != "" {
			it.Path = strings.TrimRight(dir, "/") + "/" + name
		}
	}
	return it
}
