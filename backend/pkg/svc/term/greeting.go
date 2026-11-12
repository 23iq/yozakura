package term

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"yozakura/backend/pkg/paths"
	"yozakura/backend/pkg/termlook"
)

var hexColor = regexp.MustCompile(`^#[0-9a-fA-F]{6}$`)

func (s *Service) fetchDir() string {
	if s.o.FetchDir != "" {
		return s.o.FetchDir
	}
	return filepath.Join(paths.FindShellSource(), "assets", "terminal", "fastfetch")
}

func (s *Service) sakuraLogo() string { return termlook.SakuraLogoFile(s.fetchDir()) }

func (s *Service) loadFetchPresets() ([]termlook.FetchPreset, error) {
	return termlook.LoadFetchPresets(s.fetchDir())
}

// greeting is the greeting subset of terminal.json; missing keys keep the
// defaults of config/defaults/terminal.js.
func (s *Service) greeting() termlook.GreetingConfig {
	g := termlook.GreetingConfig{Preset: termlook.FetchOwn, Logo: termlook.LogoSakura}
	if data, err := os.ReadFile(s.o.ConfigFile); err == nil {
		var raw struct {
			Greeting *string `json:"greeting"`
			Preset   *string `json:"fastfetchPreset"`
			Logo     *string `json:"fastfetchLogo"`
			LogoPath *string `json:"fastfetchLogoPath"`
		}
		if json.Unmarshal(data, &raw) == nil {
			g.On = raw.Greeting != nil && *raw.Greeting == "fastfetch"
			if raw.Preset != nil {
				g.Preset = *raw.Preset
			}
			if raw.Logo != nil {
				g.Logo = *raw.Logo
			}
			if raw.LogoPath != nil {
				g.LogoPath = *raw.LogoPath
			}
		}
	}
	g.LoginShell = s.loginShell()
	g.FishOnly = !termlook.GreetingAllShells(s.o.Env)
	return g
}

// fetchAllow is the user switching the greeting on in this version
// (Settings, the setup wizard, `term greeting on`): from now on it may
// edit ~/.bashrc and ~/.zshrc. Until then a greeting that was on before
// the update stays in fish, where it was.
func (s *Service) fetchAllow(json.RawMessage) (any, error) {
	s.mu.Lock()
	err := termlook.AllowGreetingShells(s.o.Env)
	if err == nil {
		err = s.applyGreeting()
	}
	s.mu.Unlock()
	if err != nil {
		return nil, err
	}
	return s.currentStatus(), nil
}

// applyGreeting writes or removes the greeting (under s.mu).
func (s *Service) applyGreeting() error {
	g := s.greeting()
	var pal termlook.Palette
	var ps []termlook.FetchPreset
	if g.On {
		var err error
		if ps, err = s.loadFetchPresets(); err != nil {
			return err
		}
		// no palette yet (first start): the terminal's own colours until
		// colors.json appears and the watcher applies again
		pal, _ = s.palette()
	}
	_, err := termlook.ApplyGreeting(g, pal, ps, s.sakuraLogo(), s.o.Env)
	return err
}

func (s *Service) fetchPresets(json.RawMessage) (any, error) {
	ps, err := s.loadFetchPresets()
	if err != nil {
		return nil, err
	}
	return ps, nil
}

type fetchPreviewJSON struct {
	Lines     [][]spanJSON `json:"lines"`
	Exact     bool         `json:"exact"`
	Reason    string       `json:"reason,omitempty"`
	ImageLogo bool         `json:"imageLogo,omitempty"`
}

// fetchPreview reads (and has fastfetch print) the logoPath it is given:
// fine for the user's own shell and CLI on their own socket. It must not
// be exposed to AI tools (MCP) without restricting that path, or a prompt
// could read any file of the user's through the preview.
func (s *Service) fetchPreview(params json.RawMessage) (any, error) {
	var p struct {
		Preset   *string  `json:"preset"`
		Logo     *string  `json:"logo"`
		LogoPath *string  `json:"logoPath"`
		ANSI     []string `json:"ansi"`
	}
	if len(params) > 0 {
		if err := json.Unmarshal(params, &p); err != nil {
			return nil, err
		}
	}
	g := s.greeting()
	if p.Preset != nil {
		g.Preset = *p.Preset
	}
	if p.Logo != nil {
		g.Logo = *p.Logo
	}
	if p.LogoPath != nil {
		g.LogoPath = *p.LogoPath
	}
	if !presetID.MatchString(g.Preset) {
		return nil, fmt.Errorf("invalid fastfetch preset id %q", g.Preset)
	}
	if !validLogo(g.Logo) {
		return nil, fmt.Errorf("unknown logo %q (distro, sakura, custom or none)", g.Logo)
	}
	table := termlook.ANSI16
	if len(p.ANSI) > 0 {
		if len(p.ANSI) != 16 {
			return nil, fmt.Errorf("ansi needs 16 colours")
		}
		for i, c := range p.ANSI {
			if !hexColor.MatchString(c) {
				return nil, fmt.Errorf("ansi[%d] %q is not #rrggbb", i, c)
			}
			table[i] = c
		}
	}
	ps, err := s.loadFetchPresets()
	if err != nil {
		return nil, err
	}
	look := g.Preset + "|" + g.Logo + "|" + g.LogoPath
	res, err := s.fetchRuns.do(look, strings.Join(table[:], ","), 20*time.Second, func(ctx context.Context) (termlook.FetchPreviewResult, error) {
		pal, _ := s.palette() // nil: the terminal's own colours
		return termlook.FetchPreview(ctx, g, ps, pal, s.fetchDir(), s.o.Env, table)
	})
	if err != nil {
		return nil, err
	}
	out := fetchPreviewJSON{Lines: [][]spanJSON{}, Exact: res.Exact, Reason: res.Reason, ImageLogo: res.ImageLogo}
	for _, line := range res.Lines {
		out.Lines = append(out.Lines, spans(line))
	}
	return out, nil
}

func validLogo(l string) bool {
	for _, v := range termlook.FetchLogos {
		if v == l {
			return true
		}
	}
	return false
}
