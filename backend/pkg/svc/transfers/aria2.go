package transfers

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"reflect"
	"strconv"
	"strings"
	"sync"
	"time"
)

// aria2 through its JSON-RPC interface, for every running aria2c started
// with --enable-rpc (on the command line or in its aria2.conf). The port and
// secret come from the same place, else from the "aria2" endpoint/secret
// options. aria2c without RPC is covered by the "terminal" source.
func init() { register("aria2", func() Source { return newAria2Source() }) }

const (
	aria2DiscoverEvery = 5 * time.Second
	aria2PollEvery     = 2 * time.Second
	aria2DoneHold      = 10 * time.Second
)

var aria2Keys = []string{"gid", "status", "totalLength", "completedLength", "downloadSpeed", "files", "dir", "bittorrent", "errorMessage"}

type aria2RPC struct {
	URL    string
	Secret string
}

type aria2Source struct {
	mu       sync.Mutex
	opts     Options
	rpcs     []aria2RPC
	gidRPC   map[string]aria2RPC
	seen     map[string]time.Time // gid -> first seen unfinished
	doneAt   map[string]time.Time
	http     *http.Client
	listProc func() []Proc
	confDirs []string
	now      func() time.Time
	id       int
}

func newAria2Source() *aria2Source {
	home, _ := os.UserHomeDir()
	cfg := os.Getenv("XDG_CONFIG_HOME")
	if cfg == "" {
		cfg = filepath.Join(home, ".config")
	}
	return &aria2Source{
		gidRPC:   map[string]aria2RPC{},
		seen:     map[string]time.Time{},
		doneAt:   map[string]time.Time{},
		http:     &http.Client{Timeout: 2 * time.Second},
		listProc: func() []Proc { return ListProcs(func(c string) bool { return c == "aria2c" }) },
		confDirs: []string{filepath.Join(cfg, "aria2"), filepath.Join(home, ".aria2")},
		now:      time.Now,
	}
}

// aria2Settings reads option=value pairs from args (--opt=value or
// --opt value) and from the aria2.conf they point at (or the default one).
func (s *aria2Source) aria2Settings(args []string) map[string]string {
	cli := map[string]string{}
	for i := 1; i < len(args); i++ {
		a := args[i]
		if !strings.HasPrefix(a, "--") {
			continue
		}
		k, v, hasValue := strings.Cut(strings.TrimPrefix(a, "--"), "=")
		if !hasValue {
			v = "true"
			if i+1 < len(args) && !strings.HasPrefix(args[i+1], "-") && k != "enable-rpc" && k != "rpc-secure" {
				v = args[i+1]
				i++
			}
		}
		cli[k] = v
	}
	out := map[string]string{}
	var confs []string
	if p := cli["conf-path"]; p != "" {
		confs = []string{p}
	} else if cli["no-conf"] != "true" {
		for _, d := range s.confDirs {
			confs = append(confs, filepath.Join(d, "aria2.conf"))
		}
	}
	for _, c := range confs {
		if f, err := os.Open(c); err == nil {
			sc := bufio.NewScanner(f)
			for sc.Scan() {
				line := strings.TrimSpace(sc.Text())
				if line == "" || strings.HasPrefix(line, "#") {
					continue
				}
				if k, v, ok := strings.Cut(line, "="); ok {
					out[strings.TrimSpace(k)] = strings.TrimSpace(v)
				}
			}
			f.Close()
			break
		}
	}
	for k, v := range cli {
		out[k] = v // the command line overrides the config file
	}
	return out
}

func (s *aria2Source) discover() {
	var rpcs []aria2RPC
	seen := map[string]bool{}
	for _, p := range s.listProc() {
		set := s.aria2Settings(p.Args)
		if set["enable-rpc"] != "true" {
			continue
		}
		port := set["rpc-listen-port"]
		url := s.opts.Endpoint("aria2", "http://127.0.0.1:6800/jsonrpc")
		if port != "" {
			scheme := "http"
			if set["rpc-secure"] == "true" {
				scheme = "https"
			}
			url = scheme + "://127.0.0.1:" + port + "/jsonrpc"
		}
		secret := s.opts.Secret("aria2", "")
		if v, ok := set["rpc-secret"]; ok {
			secret = v
		}
		if !seen[url] {
			seen[url] = true
			rpcs = append(rpcs, aria2RPC{URL: url, Secret: secret})
		}
	}
	s.mu.Lock()
	s.rpcs = rpcs
	s.mu.Unlock()
}

func (s *aria2Source) Run(ctx context.Context, env *Env) {
	s.opts = env.Options
	var last []Transfer
	var lastDiscover time.Time
	for {
		if time.Since(lastDiscover) >= aria2DiscoverEvery {
			lastDiscover = time.Now()
			s.discover()
		}
		items := s.poll(ctx)
		if !reflect.DeepEqual(items, last) {
			last = items
			env.Update(items)
		}
		s.mu.Lock()
		wait := aria2DiscoverEvery
		if len(s.rpcs) > 0 {
			wait = aria2PollEvery
		}
		s.mu.Unlock()
		if !sleepOrWake(ctx, wait, nil) {
			return
		}
	}
}

type aria2File struct {
	Path string `json:"path"`
	URIs []struct {
		URI string `json:"uri"`
	} `json:"uris"`
}

type aria2Status struct {
	GID             string      `json:"gid"`
	Status          string      `json:"status"`
	TotalLength     string      `json:"totalLength"`
	CompletedLength string      `json:"completedLength"`
	DownloadSpeed   string      `json:"downloadSpeed"`
	Dir             string      `json:"dir"`
	Files           []aria2File `json:"files"`
	ErrorMessage    string      `json:"errorMessage"`
	Bittorrent      *struct {
		Info *struct {
			Name string `json:"name"`
		} `json:"info"`
	} `json:"bittorrent"`
}

func (s *aria2Source) call(ctx context.Context, rpc aria2RPC, method string, params []any, out any) error {
	s.mu.Lock()
	s.id++
	id := s.id
	s.mu.Unlock()
	if rpc.Secret != "" {
		params = append([]any{"token:" + rpc.Secret}, params...)
	}
	body, _ := json.Marshal(map[string]any{"jsonrpc": "2.0", "id": strconv.Itoa(id), "method": method, "params": params})
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, rpc.URL, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := s.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	var env struct {
		Result json.RawMessage `json:"result"`
		Error  *struct {
			Message string `json:"message"`
		} `json:"error"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&env); err != nil {
		return err
	}
	if env.Error != nil {
		return fmt.Errorf("aria2: %s", env.Error.Message)
	}
	if out == nil {
		return nil
	}
	return json.Unmarshal(env.Result, out)
}

func (s *aria2Source) poll(ctx context.Context) []Transfer {
	s.mu.Lock()
	rpcs := append([]aria2RPC(nil), s.rpcs...)
	s.mu.Unlock()
	now := s.now()
	var items []Transfer
	gidRPC := map[string]aria2RPC{}
	for _, rpc := range rpcs {
		var active, waiting, stopped []aria2Status
		if err := s.call(ctx, rpc, "aria2.tellActive", []any{aria2Keys}, &active); err != nil {
			continue // starting up, or a wrong secret: nothing to show
		}
		s.call(ctx, rpc, "aria2.tellWaiting", []any{0, 20, aria2Keys}, &waiting)
		s.call(ctx, rpc, "aria2.tellStopped", []any{-1, 5, aria2Keys}, &stopped)
		index := map[string]int{}
		for _, list := range [][]aria2Status{active, waiting, stopped} {
			for _, st := range list {
				it, ok := s.item(st, now)
				if !ok {
					continue
				}
				gidRPC[st.GID] = rpc
				if i, dup := index[st.GID]; dup {
					items[i] = it // moved between lists while we asked
					continue
				}
				index[st.GID] = len(items)
				items = append(items, it)
			}
		}
	}
	s.mu.Lock()
	s.gidRPC = gidRPC
	s.mu.Unlock()
	return items
}

func parseInt64(s string) int64 {
	v, err := strconv.ParseInt(s, 10, 64)
	if err != nil {
		return -1
	}
	return v
}

func (s *aria2Source) item(st aria2Status, now time.Time) (Transfer, bool) {
	it := Unknown()
	it.Key = st.GID
	it.App = "aria2"
	it.AppIcon = "aria2"
	switch st.Status {
	case "active":
		it.State = StateRunning
		it.Actions = []string{ActionSuspend, ActionCancel}
	case "waiting":
		it.State = StateQueued
		it.Actions = []string{ActionSuspend, ActionCancel}
	case "paused":
		it.State = StatePaused
		it.Actions = []string{ActionResume, ActionCancel}
	case "complete", "error":
		// Only jobs that ran while we watched; tellStopped also lists old ones
		if _, ok := s.seen[st.GID]; !ok {
			return Transfer{}, false
		}
		first, ok := s.doneAt[st.GID]
		if !ok {
			first = now
			s.doneAt[st.GID] = now
		}
		if now.Sub(first) > aria2DoneHold {
			delete(s.seen, st.GID)
			delete(s.doneAt, st.GID)
			return Transfer{}, false
		}
		it.State = StateDone
		if st.Status == "error" {
			it.State, it.Detail = StateFailed, st.ErrorMessage
		}
	default: // removed
		return Transfer{}, false
	}
	if it.State != StateDone && it.State != StateFailed {
		if _, ok := s.seen[st.GID]; !ok {
			s.seen[st.GID] = now
		}
	}
	it.StartedAt = s.seen[st.GID].UnixMilli()
	it.Total = parseInt64(st.TotalLength)
	if it.Total == 0 {
		it.Total = -1 // size not known yet
	}
	it.Processed = parseInt64(st.CompletedLength)
	if sp := parseInt64(st.DownloadSpeed); sp >= 0 && it.State == StateRunning {
		it.Rate = float64(sp)
	}
	it.Dir = st.Dir
	if len(st.Files) > 0 {
		it.Path = st.Files[0].Path
		if it.Path == "" && len(st.Files[0].URIs) > 0 {
			u := st.Files[0].URIs[0].URI
			it.Title = filepath.Base(strings.SplitN(u, "?", 2)[0])
		}
	}
	if st.Bittorrent != nil && st.Bittorrent.Info != nil && st.Bittorrent.Info.Name != "" {
		it.Title = st.Bittorrent.Info.Name
		if st.Dir != "" {
			it.Path = filepath.Join(st.Dir, it.Title)
		}
	}
	if it.Title == "" && it.Path != "" {
		it.Title = filepath.Base(it.Path)
	}
	if it.Title == "" {
		it.Title = "aria2 " + st.GID
	}
	if it.Dir == "" && it.Path != "" {
		it.Dir = filepath.Dir(it.Path)
	}
	return it, true
}

// Action pauses, resumes or removes one aria2 job (from the shell's UI).
func (s *aria2Source) Action(key, action string) error {
	s.mu.Lock()
	rpc, ok := s.gidRPC[key]
	s.mu.Unlock()
	if !ok {
		return fmt.Errorf("aria2: unknown job %q", key)
	}
	method := map[string]string{ActionCancel: "aria2.remove", ActionSuspend: "aria2.pause", ActionResume: "aria2.unpause"}[action]
	if method == "" {
		return fmt.Errorf("aria2: unsupported action %q", action)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	return s.call(ctx, rpc, method, []any{key}, nil)
}
