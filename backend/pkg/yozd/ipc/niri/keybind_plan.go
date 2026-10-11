package niri

import (
	"fmt"
	"sort"
	"strings"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/yozd/ipc"
)

// plannedBind is a bind GenerateKeybinds writes.
type plannedBind struct {
	kb      ipc.Keybind
	comment string
	combo   string
	isSpawn bool
	action  string
	arg     string
}

// keybindPlan splits the payload into the binds niri can express and the
// ones it cannot (with the reason), in a stable order: binds come from
// maps, so names are sorted; the first bind of a combo wins, because niri
// rejects a config that repeats a key combo.
func keybindPlan(config ipc.ConfigKeybinds) (planned []plannedBind, skipped []ipc.SkippedBind) {
	seen := map[string]string{}

	add := func(kb ipc.Keybind, comment string) {
		if !kb.Enabled || kb.Key == "" {
			return
		}
		skip := func(reason string) {
			skipped = append(skipped, ipc.SkippedBind{
				Name: comment, Modifiers: kb.Modifiers, Key: kb.Key,
				Dispatcher: kb.Dispatcher, Reason: reason,
			})
		}
		key, ok := niriMapKey(kb.Key)
		if !ok {
			skip(fmt.Sprintf("key %q has no niri equivalent", kb.Key))
			return
		}
		if ipc.ModifierSelfGroup(kb) != "" {
			// Handled by the keymon evdev monitor (fires on release alone).
			return
		}
		if reason, bad := niriModifierSelfBind(key, kb.Modifiers); bad {
			skip(reason)
			return
		}
		if strings.Contains(strings.ToLower(kb.Flags), "r") {
			skip("niri has no key-release binds, so a hold action cannot stop on release; use the toggle activation mode (voice.activation = toggle)")
			return
		}
		arg := ipc.ResolveBindArgument(kb)
		isSpawn := kb.Dispatcher == "" || kb.Dispatcher == "exec" || kb.Dispatcher == "spawn"
		var action string
		if !isSpawn {
			action, ok = niriMapDispatcher(kb.Dispatcher, arg)
			if !ok {
				skip("dispatcher not supported in niri")
				return
			}
		}
		combo := formatNiriModifiers(kb.Modifiers)
		if combo != "" {
			combo += "+"
		}
		combo += key
		id := strings.ToLower(combo)
		if first, dup := seen[id]; dup {
			skip(fmt.Sprintf("same key combo as %q (niri rejects duplicate combos)", first))
			return
		}
		seen[id] = comment
		planned = append(planned, plannedBind{kb: kb, comment: comment, combo: combo, isSpawn: isSpawn, action: action, arg: arg})
	}

	if config.Shell != nil {
		for _, name := range sortedKeys(config.Shell.System) {
			add(config.Shell.System[name], brand.DisplayName+" System: "+name)
		}
		for _, name := range sortedKeys(config.Shell.Binds) {
			add(config.Shell.Binds[name], brand.DisplayName+": "+name)
		}
	}
	for i, kb := range config.Custom {
		add(kb, fmt.Sprintf("Custom Bind %d", i))
	}
	return planned, skipped
}

func sortedKeys(m map[string]ipc.Keybind) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}

// SkippedKeybinds implements ipc.BindSkipper.
func (g *Generator) SkippedKeybinds(config ipc.ConfigKeybinds) []ipc.SkippedBind {
	_, skipped := keybindPlan(config)
	return skipped
}
