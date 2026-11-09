package server

import (
	"fmt"
	"os"
	"strings"
	"sync"

	"yozakura/backend/pkg/yozd/ipc"
)

// luaConfigurer is implemented by the Hyprland client: true when the
// running Hyprland reads the Lua config (runtime changes go through
// `eval`), false for hyprlang (`keyword`).
type luaConfigurer interface {
	UsesLuaConfig() bool
}

// appliedConfig is what the handler last wrote for one generated path.
type appliedConfig struct {
	conf, lua string
	sections  configSections
}

// Handlers are created per apply, so the last applied state lives here,
// keyed by the generated file path.
var (
	appliedMu sync.Mutex
	applied   = map[string]appliedConfig{}
)

// hyprSections renders the generated config per section (both languages)
// for the reload decision. The appearance is split into the option blocks
// (live) and the animation block (reload).
func (h *ConfigHandler) hyprSections(payload ipc.ConfigUniversal) configSections {
	opts := payload.Appearance
	opts.Animations = nil
	anim := ipc.ConfigAppearance{Animations: payload.Appearance.Animations}
	g := h.generator
	s := configSections{
		secEnv:        {conf: g.GenerateEnv(payload.Env)},
		secOutputs:    {conf: g.GenerateOutputs(payload.Monitors)},
		secKeyboard:   {conf: g.GenerateKeyboard(payload.Keyboard)},
		secStartup:    {conf: g.GenerateStartup(payload.Exec, ipc.StartupOnce(payload, false))},
		secAppearance: {conf: g.GenerateAppearance(opts)},
		secAnimations: {conf: g.GenerateAppearance(anim)},
		secBinds:      {conf: g.GenerateKeybinds(payload.Keybinds)},
		secRules:      {conf: g.GenerateWindowRules(payload.WindowRules)},
		secLayers:     {conf: g.GenerateLayerRules(payload.LayerRules)},
	}
	if h.luaGen == nil || h.paths.alt == "" {
		return s
	}
	lg := h.luaGen
	withLua := func(name, lua string) {
		sec := s[name]
		sec.lua = lua
		s[name] = sec
	}
	withLua(secEnv, lg.GenerateEnvLua(payload.Env))
	withLua(secOutputs, lg.GenerateOutputsLua(payload.Monitors))
	withLua(secKeyboard, lg.GenerateKeyboardLua(payload.Keyboard))
	withLua(secStartup, lg.GenerateStartupLua(payload.Exec, payload.ExecOnce))
	withLua(secAppearance, lg.GenerateAppearanceLua(opts))
	withLua(secAnimations, lg.GenerateAppearanceLua(anim))
	withLua(secBinds, lg.GenerateKeybindsLua(payload.Keybinds))
	withLua(secRules, lg.GenerateWindowRulesLua(payload.WindowRules))
	withLua(secLayers, lg.GenerateLayerRulesLua(payload.LayerRules))
	return s
}

// applyHyprland writes the generated files only when they changed and
// reloads Hyprland only when a runtime command cannot carry the change:
// a slider drag in the settings pushes `keyword`/`eval` updates instead of
// re-parsing the config and re-applying the monitor rules each step.
func (h *ConfigHandler) applyHyprland(payload ipc.ConfigUniversal, confPath, conf, luaPath, lua string) error {
	diskConf, _ := os.ReadFile(confPath)
	diskLua := []byte(nil)
	if luaPath != "" {
		diskLua, _ = os.ReadFile(luaPath)
	}
	next := h.hyprSections(payload)

	appliedMu.Lock()
	defer appliedMu.Unlock()
	var prev configSections
	if last, ok := applied[confPath]; ok && last.conf == string(diskConf) && last.lua == string(diskLua) {
		prev = last.sections
	}
	diskSame := string(diskConf) == conf && (luaPath == "" || string(diskLua) == lua)
	plan := planApply(prev, next, diskSame)

	if plan.Write {
		if err := writeGenerated(confPath, conf); err != nil {
			return err
		}
		if luaPath != "" {
			if err := writeGenerated(luaPath, lua); err != nil {
				return err
			}
		}
	}
	applied[confPath] = appliedConfig{conf: conf, lua: lua, sections: next}

	switch {
	case !plan.Write:
		fmt.Printf("Config unchanged: %s (no reload)\n", confPath)
		return nil
	case plan.Reload:
		fmt.Printf("Config changed (%s): reloading\n", strings.Join(plan.Changed, ", "))
		return h.loadGeneratedConfig(confPath)
	}
	if err := h.applyLive(prev, next, plan.Live); err != nil {
		fmt.Printf("Live config update failed (%v): reloading\n", err)
		return h.loadGeneratedConfig(confPath)
	}
	return nil
}

// applyLive sends the changed live sections as one batch request.
func (h *ConfigHandler) applyLive(prev, next configSections, live []string) error {
	lua := false
	if lc, ok := h.compositor.(luaConfigurer); ok {
		lua = lc.UsesLuaConfig() && h.luaGen != nil && h.paths.alt != ""
	}
	cmds, ok := liveCommands(prev, next, live, lua)
	if !ok {
		return fmt.Errorf("sections %s cannot be applied at runtime", strings.Join(live, ", "))
	}
	if len(cmds) == 0 {
		return nil
	}
	fmt.Printf("Config changed (%s): applied live, no reload\n", strings.Join(live, ", "))
	return h.compositor.RawBatch(strings.Join(cmds, ";"))
}
