package transfers

import (
	"context"
	"crypto/tls"
	"encoding/json"
	"encoding/xml"
	"fmt"
	"net"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"time"
)

// Syncthing folders that are pulling changes, through the REST API (key and
// GUI address from Syncthing's config.xml, or the "syncthing" endpoint).
// One item per folder in a syncing state with bytes still needed.
func init() { register("syncthing", func() Source { return newSyncthingSource() }) }

const (
	syncthingPollEvery     = 3 * time.Second
	syncthingDiscoverEvery = 10 * time.Second
)

type syncthingConfig struct {
	XMLName xml.Name `xml:"configuration"`
	Folders []struct {
		ID     string `xml:"id,attr"`
		Label  string `xml:"label,attr"`
		Path   string `xml:"path,attr"`
		Paused bool   `xml:"paused"`
	} `xml:"folder"`
	GUI struct {
		TLS     bool   `xml:"tls,attr"`
		Address string `xml:"address"`
		APIKey  string `xml:"apikey"`
	} `xml:"gui"`
}

type syncthingSource struct {
	opts        Options
	configPaths func() []string
	running     func() bool
	http        *http.Client
	cfg         *syncthingConfig
	base        string
	rate        RateMeter
	started     map[string]time.Time
	now         func() time.Time
}

func newSyncthingSource() *syncthingSource {
	return &syncthingSource{
		configPaths: defaultSyncthingConfigs,
		running:     func() bool { return ProcRunning("syncthing") },
		started:     map[string]time.Time{},
		now:         time.Now,
	}
}

func defaultSyncthingConfigs() []string {
	home, _ := os.UserHomeDir()
	state := os.Getenv("XDG_STATE_HOME")
	if state == "" {
		state = filepath.Join(home, ".local/state")
	}
	cfg := os.Getenv("XDG_CONFIG_HOME")
	if cfg == "" {
		cfg = filepath.Join(home, ".config")
	}
	return []string{
		filepath.Join(state, "syncthing", "config.xml"),
		filepath.Join(cfg, "syncthing", "config.xml"),
		filepath.Join(home, ".var/app/me.kozec.syncthingtk/config/syncthing/config.xml"),
	}
}

func parseSyncthingConfig(data []byte) (*syncthingConfig, error) {
	var c syncthingConfig
	if err := xml.Unmarshal(data, &c); err != nil {
		return nil, err
	}
	return &c, nil
}

// syncthingBase turns the GUI address into a URL the shell can reach.
func syncthingBase(c *syncthingConfig) string {
	addr := strings.TrimSpace(c.GUI.Address)
	if addr == "" || strings.HasPrefix(addr, "/") || strings.HasPrefix(addr, "unix") {
		return "" // unix socket GUI: not supported
	}
	host, port, err := net.SplitHostPort(addr)
	if err != nil {
		return ""
	}
	if host == "" || host == "0.0.0.0" || host == "::" {
		host = "127.0.0.1"
	}
	scheme := "http"
	if c.GUI.TLS {
		scheme = "https"
	}
	return scheme + "://" + net.JoinHostPort(host, port)
}

func isLoopback(base string) bool {
	u, err := url.Parse(base)
	if err != nil {
		return false
	}
	h := u.Hostname()
	if h == "localhost" {
		return true
	}
	ip := net.ParseIP(h)
	return ip != nil && ip.IsLoopback()
}

func (s *syncthingSource) load() {
	s.cfg, s.base = nil, ""
	for _, p := range s.configPaths() {
		data, err := os.ReadFile(p)
		if err != nil {
			continue
		}
		c, err := parseSyncthingConfig(data)
		if err != nil || c.GUI.APIKey == "" {
			continue
		}
		s.cfg = c
		s.base = strings.TrimRight(s.opts.Endpoint("syncthing", syncthingBase(c)), "/")
		break
	}
	tr := &http.Transport{}
	if s.base != "" && isLoopback(s.base) {
		// Syncthing's self-signed certificate; only ever for loopback
		tr.TLSClientConfig = &tls.Config{InsecureSkipVerify: true}
	}
	s.http = &http.Client{Timeout: 2 * time.Second, Transport: tr}
}

func (s *syncthingSource) Run(ctx context.Context, env *Env) {
	s.opts = env.Options
	var last []Transfer
	var lastDiscover time.Time
	alive := false
	for {
		if time.Since(lastDiscover) >= syncthingDiscoverEvery {
			lastDiscover = time.Now()
			alive = s.running()
			if alive && s.cfg == nil {
				s.load()
			}
			if !alive {
				s.cfg = nil
			}
		}
		var items []Transfer
		if alive && s.cfg != nil && s.base != "" {
			items = s.poll(ctx)
		}
		if !reflect.DeepEqual(items, last) {
			last = items
			env.Update(items)
		}
		wait := syncthingDiscoverEvery
		if alive {
			wait = syncthingPollEvery
		}
		if !sleepOrWake(ctx, wait, nil) {
			return
		}
	}
}

func (s *syncthingSource) get(ctx context.Context, path string, out any) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, s.base+path, nil)
	if err != nil {
		return err
	}
	req.Header.Set("X-API-Key", s.cfg.GUI.APIKey)
	resp, err := s.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("syncthing %s: %s", path, resp.Status)
	}
	return json.NewDecoder(resp.Body).Decode(out)
}

type syncthingFolderStatus struct {
	State       string `json:"state"`
	GlobalBytes int64  `json:"globalBytes"`
	NeedBytes   int64  `json:"needBytes"`
	NeedFiles   int64  `json:"needFiles"`
	InSyncBytes int64  `json:"inSyncBytes"`
}

func (s *syncthingSource) poll(ctx context.Context) []Transfer {
	now := s.now()
	var items []Transfer
	for _, f := range s.cfg.Folders {
		if f.Paused {
			continue
		}
		var st syncthingFolderStatus
		if err := s.get(ctx, "/rest/db/status?folder="+url.QueryEscape(f.ID), &st); err != nil {
			continue
		}
		if st.NeedBytes <= 0 && st.NeedFiles <= 0 {
			delete(s.started, f.ID)
			continue
		}
		switch st.State {
		case "syncing", "sync-preparing", "sync-waiting":
		default:
			continue // idle with needs = a device is offline, not progress
		}
		if _, ok := s.started[f.ID]; !ok {
			s.started[f.ID] = now
		}
		it := Unknown()
		it.Key = f.ID
		it.App = "Syncthing"
		it.AppIcon = "syncthing"
		it.Kind = KindSync
		it.Title = f.Label
		if it.Title == "" {
			it.Title = f.ID
		}
		it.Path, it.Dir = f.Path, f.Path
		if st.GlobalBytes > 0 {
			it.Total = st.GlobalBytes
			it.Processed = st.GlobalBytes - st.NeedBytes
		}
		if st.NeedFiles > 0 {
			it.Detail = fmt.Sprintf("%d files", st.NeedFiles)
		}
		if st.State != "syncing" {
			it.State = StateQueued
		}
		it.StartedAt = s.started[f.ID].UnixMilli()
		items = append(items, it)
	}
	if len(items) > 0 {
		var conns struct {
			Total struct {
				InBytesTotal int64 `json:"inBytesTotal"`
			} `json:"total"`
		}
		if err := s.get(ctx, "/rest/system/connections", &conns); err == nil {
			rate := s.rate.Observe(conns.Total.InBytesTotal, now)
			for i := range items {
				if items[i].State == StateRunning {
					items[i].Rate = rate // shared link: report it on the first one
					break
				}
			}
		}
	}
	return items
}
