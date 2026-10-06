package termlook

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"yozakura/backend/pkg/brand"
)

// Engine ids as stored in the terminal.engine setting.
const (
	EngineStarship = "starship"
	EngineOMP      = "ohmyposh"
)

// Config is the terminal domain subset the writer needs.
type Config struct {
	Enabled  bool
	Engine   string // starship | ohmyposh
	Prompt   string // preset id
	Greeting string // none | fastfetch
}

// Env locates the files and binaries. LookPath reports whether a binary is
// installed (nil means "not installed"). CacheHome defaults to Home/.cache.
type Env struct {
	Home, ConfigHome, CacheHome, AppID string
	LookPath                           func(string) (string, bool)
}

func (e Env) look(bin string) (string, bool) {
	if e.LookPath == nil {
		return "", false
	}
	return e.LookPath(bin)
}

func (e Env) cacheHome() string {
	if e.CacheHome != "" {
		return e.CacheHome
	}
	return filepath.Join(e.Home, ".cache")
}

// ConfigFile is the engine config path for the config's engine.
func ConfigFile(cfg Config, env Env) string {
	name := "starship.toml"
	if cfg.Engine == EngineOMP {
		name = "prompt.omp.json"
	}
	return filepath.Join(env.ConfigHome, env.AppID, name)
}

// HookFile is the owned fish conf.d file.
func HookFile(env Env) string {
	return filepath.Join(env.ConfigHome, "fish", "conf.d", env.AppID+".fish")
}

// Render renders the engine config of a preset.
func Render(cfg Config, p Preset, pal Palette) string {
	if cfg.Engine == EngineOMP {
		return RenderOMP(p, pal)
	}
	return RenderStarship(p, pal)
}

// Apply writes the engine config and the fish hook when cfg.Enabled, else
// removes the hook (the engine config stays so re-enabling is cheap).
func Apply(cfg Config, pal Palette, presets []Preset, env Env) error {
	if env.AppID == "" || env.ConfigHome == "" {
		return fmt.Errorf("termlook: env needs AppID and ConfigHome")
	}
	hook := HookFile(env)
	exists, ours := hookOwned(hook)
	if !cfg.Enabled {
		if !exists || !ours {
			return nil // nothing of ours there
		}
		return os.Remove(hook)
	}
	if exists && !ours {
		return fmt.Errorf("termlook: %s was not written by %s; move it away to use the prompt", hook, brand.DisplayName)
	}
	if cfg.Engine != EngineStarship && cfg.Engine != EngineOMP {
		return fmt.Errorf("termlook: unknown engine %q", cfg.Engine)
	}
	if cfg.Greeting != "" && cfg.Greeting != "none" && cfg.Greeting != "fastfetch" {
		return fmt.Errorf("termlook: unknown greeting %q", cfg.Greeting)
	}
	p, ok := findPreset(presets, cfg.Prompt)
	if !ok {
		return fmt.Errorf("termlook: unknown prompt preset %q", cfg.Prompt)
	}
	file := ConfigFile(cfg, env)
	if strings.ContainsAny(file, "\n\r\x00") {
		return fmt.Errorf("termlook: config path contains control characters")
	}
	if err := writeAtomic(file, []byte(Render(cfg, p, pal))); err != nil {
		return err
	}
	return writeAtomic(hook, []byte(FishHook(cfg, file)))
}

// hookOwned reports whether path exists and carries our header.
func hookOwned(path string) (exists, ours bool) {
	data, err := os.ReadFile(path)
	if err != nil {
		return !os.IsNotExist(err), false
	}
	return true, strings.HasPrefix(string(data), "# Managed by "+brand.DisplayName+".")
}

func findPreset(presets []Preset, id string) (Preset, bool) {
	for _, p := range presets {
		if p.ID == id {
			return p, true
		}
	}
	return Preset{}, false
}

func writeAtomic(path string, data []byte) error {
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}
	tmp, err := os.CreateTemp(dir, ".tmp-*")
	if err != nil {
		return err
	}
	name := tmp.Name()
	_, err = tmp.Write(data)
	if cerr := tmp.Close(); err == nil {
		err = cerr
	}
	if err == nil {
		err = os.Chmod(name, 0o644)
	}
	if err == nil {
		err = os.Rename(name, path)
	}
	if err != nil {
		_ = os.Remove(name)
	}
	return err
}
