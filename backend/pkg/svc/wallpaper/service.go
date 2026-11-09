// Package wallpaper implements the daemon-side "wallpaper" IPC service.
// The CLI (`yozakura wallpaper <file> ...`) calls the Set method, which
// pushes a one-shot ServiceEvent out to every QML subscriber. Subscribers
// (WallpaperCommandService.qml) translate that into the existing setWallpaper
// flow on the Wallpaper component. Wallpaper state remains owned by the
// Quickshell side; the service only makes screen-sized copies of video
// wallpapers (videoProxy, package videoproxy) and announces finished ones
// with a `wallpaper.videoProxy` event.
package wallpaper

import (
	"context"
	"encoding/json"
	"path/filepath"
	"sync"

	"yozakura/backend/pkg/ipc"
	"yozakura/backend/pkg/videoproxy"
)

type Service struct {
	mu    sync.Mutex
	subs  []*ipc.Subscriber
	proxy *videoproxy.Manager
}

// SetParams mirrors what the CLI sends. Only fields the caller set are
// forwarded to subscribers; an empty/missing field means "leave unchanged".
type SetParams struct {
	Path    string `json:"path"`
	Scheme  string `json:"scheme"`
	OLED    *bool  `json:"oled,omitempty"`
	Tint    *bool  `json:"tint,omitempty"`
	Monitor string `json:"monitor"`
}

// ProxyDir is where video wallpaper proxies are cached under the cache dir.
const ProxyDir = "video-wallpapers"

// NewService returns the service; video proxies go to <cacheDir>/ProxyDir.
func NewService(ctx context.Context, cacheDir string) *Service {
	s := &Service{proxy: videoproxy.New(ctx, filepath.Join(cacheDir, ProxyDir))}
	s.proxy.Notify = func(r videoproxy.Result) { s.broadcast("wallpaper.videoProxy", r) }
	return s
}

func (s *Service) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "wallpaper",
		Methods: map[string]ipc.HandlerFunc{
			"set":        s.set,
			"videoProxy": s.videoProxy,
		},
		Subscribe: s.subscribe,
		// ffprobe runs on the first request for a file.
		Async: map[string]bool{"videoProxy": true},
	})
}

// videoProxy: {path, width, height} (physical pixels) -> videoproxy.Result.
// A "pending" answer is followed by a `wallpaper.videoProxy` event.
func (s *Service) videoProxy(params json.RawMessage) (any, error) {
	var r videoproxy.Request
	if len(params) > 0 {
		if err := json.Unmarshal(params, &r); err != nil {
			return nil, err
		}
	}
	return s.proxy.Request(r), nil
}

func (s *Service) broadcast(event string, payload any) {
	s.mu.Lock()
	subs := append([]*ipc.Subscriber(nil), s.subs...)
	s.mu.Unlock()
	for _, sub := range subs {
		sub.Send(event, payload)
	}
}

func (s *Service) subscribe(sub *ipc.Subscriber) {
	s.mu.Lock()
	s.subs = append(s.subs, sub)
	s.mu.Unlock()

	go func() {
		<-sub.StopCh()
		s.mu.Lock()
		defer s.mu.Unlock()
		for i, x := range s.subs {
			if x == sub {
				s.subs = append(s.subs[:i], s.subs[i+1:]...)
				return
			}
		}
	}()
}

func (s *Service) set(params json.RawMessage) (any, error) {
	var p SetParams
	if len(params) > 0 {
		if err := json.Unmarshal(params, &p); err != nil {
			return nil, err
		}
	}
	if p.Path == "" {
		return map[string]any{"error": "missing path"}, nil
	}

	payload := map[string]any{
		"path":    p.Path,
		"scheme":  p.Scheme,
		"monitor": p.Monitor,
	}
	if p.OLED != nil {
		payload["oled"] = *p.OLED
	}
	if p.Tint != nil {
		payload["tint"] = *p.Tint
	}

	s.broadcast("wallpaper.set", payload)
	return map[string]any{"ok": true}, nil
}
