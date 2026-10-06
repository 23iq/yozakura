package transfers

import (
	"context"
	"sort"
	"sync"
)

// Options are user settings forwarded by the shell (notch.liveActivities.downloads).
type Options struct {
	// DownloadDir overrides XDG_DOWNLOAD_DIR (tests, unusual setups).
	DownloadDir string `json:"downloadDir"`
	// SteamRoots overrides the Steam installation roots (tests).
	SteamRoots []string `json:"steamRoots"`
	// Endpoints of local services, e.g. {"qbittorrent": "http://127.0.0.1:8080"}.
	Endpoints map[string]string `json:"endpoints"`
	// Secrets for those endpoints ({"aria2": "token", "deluge": "password"}).
	Secrets map[string]string `json:"secrets"`
}

// Endpoint returns the configured endpoint for name or def.
func (o Options) Endpoint(name, def string) string {
	if v, ok := o.Endpoints[name]; ok && v != "" {
		return v
	}
	return def
}

// Secret returns the configured secret for name or def.
func (o Options) Secret(name, def string) string {
	if v, ok := o.Secrets[name]; ok {
		return v
	}
	return def
}

// Env is what a running source gets from the service.
type Env struct {
	Options Options
	update  func(items []Transfer)
}

// Update replaces every item of the calling source. Safe from any goroutine.
func (e *Env) Update(items []Transfer) { e.update(items) }

// Source produces transfers until ctx is cancelled. Run must return soon
// after ctx is done and must not busy-poll: watch (inotify/D-Bus) or tick
// slowly, and tick only while there is something to watch.
type Source interface {
	Run(ctx context.Context, env *Env)
}

// Actor is implemented by sources that support Transfer.Actions.
type Actor interface {
	Action(key, action string) error
}

var (
	registryMu sync.Mutex
	registry   = map[string]func() Source{}
)

// register adds a source factory under its config key (notch.liveActivities.sources).
// Call it from the source file's init().
func register(name string, factory func() Source) {
	registryMu.Lock()
	defer registryMu.Unlock()
	registry[name] = factory
}

// SourceNames lists the registered sources, sorted.
func SourceNames() []string {
	registryMu.Lock()
	defer registryMu.Unlock()
	out := make([]string, 0, len(registry))
	for k := range registry {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}

func factory(name string) func() Source {
	registryMu.Lock()
	defer registryMu.Unlock()
	return registry[name]
}
