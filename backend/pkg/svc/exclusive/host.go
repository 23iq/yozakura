package exclusive

import (
	"fmt"
	"os"
	"strings"

	"yozakura/backend/pkg/binds"
	"yozakura/backend/pkg/catalog"
	"yozakura/backend/pkg/exclusive"
	"yozakura/backend/pkg/mcp/yozakura"
	"yozakura/backend/pkg/paths"
	"yozakura/backend/pkg/svc/yozdcli"
	"yozakura/backend/pkg/yozd/ipc"
)

// Store opens the config store the way `yozakura config` does.
func Store() (*catalog.Store, error) {
	cat, err := catalog.Load(paths.FindShellSource())
	if err != nil {
		return nil, err
	}
	return &catalog.Store{Cat: cat, File: paths.New().Config}, nil
}

// Host returns the real environment: the running compositor, systemctl,
// the config store for the import and a reload through yozd.
func Host() exclusive.Options {
	home, _ := os.UserHomeDir()
	return exclusive.Options{
		Home:       home,
		HyprDir:    paths.HyprDir(),
		Compositor: binds.DetectCompositor(),
		Systemd:    exclusive.ExecSystemd{},
		Import:     importSettings,
		Unimport:   unimportSettings,
		Reload:     reloadCompositor,
	}
}

var importedKeys = []string{"displays.monitors", "keyboard.layouts", "keyboard.options", "keyboard.repeatRate", "keyboard.repeatDelay"}

// importSettings writes the parsed monitors and keyboard into the config
// and returns the explicit values it replaced (nil = was default). On an
// error the config is put back.
func importSettings(monitors []ipc.OutputConfig, kb *ipc.KeyboardSettings) (map[string]any, error) {
	store, err := Store()
	if err != nil {
		return nil, err
	}
	previous := map[string]any{}
	for _, k := range importedKeys {
		v, explicit, err := store.Get(k)
		if err != nil {
			return nil, err
		}
		if explicit {
			previous[k] = v
		} else {
			previous[k] = nil
		}
	}
	if err := writeImport(store, monitors, kb); err != nil {
		if uerr := unimportWith(store, previous); uerr != nil {
			err = fmt.Errorf("%w (and reverting failed: %v)", err, uerr)
		}
		return nil, err
	}
	return previous, nil
}

func writeImport(store *catalog.Store, monitors []ipc.OutputConfig, kb *ipc.KeyboardSettings) error {
	if len(monitors) > 0 {
		if err := yozakura.PersistMonitors(store, monitors, nil); err != nil {
			return fmt.Errorf("displays.monitors: %w", err)
		}
	}
	if kb == nil {
		return nil
	}
	set := func(key string, v any) error {
		if _, err := store.Set(key, v, false); err != nil {
			return fmt.Errorf("%s: %w", key, err)
		}
		return nil
	}
	if len(kb.Layouts) > 0 {
		layouts := make([]any, len(kb.Layouts))
		for i, l := range kb.Layouts {
			v := ""
			if i < len(kb.Variants) {
				v = kb.Variants[i]
			}
			layouts[i] = map[string]any{"layout": l, "variant": v}
		}
		if err := set("keyboard.layouts", layouts); err != nil {
			return err
		}
	}
	if len(kb.Options) > 0 {
		opts := make([]any, len(kb.Options))
		for i, o := range kb.Options {
			opts[i] = o
		}
		if err := set("keyboard.options", opts); err != nil {
			return err
		}
	}
	if kb.RepeatRate > 0 {
		if err := set("keyboard.repeatRate", kb.RepeatRate); err != nil {
			return err
		}
	}
	if kb.RepeatDelay > 0 {
		if err := set("keyboard.repeatDelay", kb.RepeatDelay); err != nil {
			return err
		}
	}
	return nil
}

func unimportSettings(previous map[string]any) error {
	store, err := Store()
	if err != nil {
		return err
	}
	return unimportWith(store, previous)
}

func unimportWith(store *catalog.Store, previous map[string]any) error {
	var errs []string
	for k, v := range previous {
		var err error
		if v == nil {
			_, err = store.Reset(k)
		} else {
			_, err = store.Set(k, v, true)
		}
		if err != nil {
			errs = append(errs, k+": "+err.Error())
		}
	}
	if len(errs) > 0 {
		return fmt.Errorf("%s", strings.Join(errs, "; "))
	}
	return nil
}

// compositorAPI is the part of yozd the reload needs.
type compositorAPI interface {
	Compositor() (string, error)
	ReloadConfig() error
	ConfigErrors() ([]string, error)
}

// reloadCompositor reloads Hyprland through yozd and fails on any config
// error it reports. It asks yozd which compositor runs and refuses to go on
// when yozd cannot answer or it is not Hyprland: without the reload check
// there is no safety net, so Enable must not silently skip it.
func reloadCompositor() error { return reloadWith(yozdcli.New()) }

func reloadWith(y compositorAPI) error {
	name, err := y.Compositor()
	if err != nil {
		return fmt.Errorf("cannot ask the compositor daemon which compositor runs (is Hyprland running?): %w", err)
	}
	if name != "hyprland" {
		return fmt.Errorf("the compositor daemon reports %q, not hyprland", name)
	}
	if err := y.ReloadConfig(); err != nil {
		return err
	}
	errs, err := y.ConfigErrors()
	if err != nil {
		return fmt.Errorf("reading config errors: %w", err)
	}
	if len(errs) > 0 {
		return fmt.Errorf("config errors: %s", strings.Join(errs, "; "))
	}
	return nil
}
