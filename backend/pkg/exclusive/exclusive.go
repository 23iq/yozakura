// Package exclusive turns Yozakura into the only shell on a Hyprland
// session: it backs up ~/.config/hypr, imports the user's monitor and
// keyboard settings, replaces the entry file with a minimal one that loads
// the generated config plus a user.lua/user.conf for personal tweaks, and
// disables other shells' and daemons' systemd user units. Restore brings
// the backed-up tree and the units back exactly.
//
// Nothing outside ~/.config/hypr is touched except the backup dir
// (~/.local/share/<app>/backups/) and the units, through the injected
// Systemd; config import and the compositor reload are injected too.
package exclusive

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/yozd/ipc"
)

var (
	ErrNotSupported = errors.New("exclusive mode is only supported on Hyprland")
	ErrHomeManager  = errors.New("the Hyprland config is managed by home-manager (a link into /nix/store); enable exclusive mode through the Nix module instead")
	ErrLinkedDir    = errors.New("~/.config/hypr is a symlink; exclusive mode only manages a real directory")
	ErrNoBackup     = errors.New("no exclusive-mode backup found")
)

// Systemd manages user units (systemctl --user).
type Systemd interface {
	IsEnabled(unit string) bool
	Disable(unit string) error // disable --now
	Enable(unit string) error
	ListUserUnits(pattern string) []string
}

// Status is the exclusive-mode state. Backup is the newest backup dir;
// DisabledUnits are the units that backup recorded (only while Active).
type Status struct {
	Active        bool     `json:"active"`
	Backup        string   `json:"backup"`
	DisabledUnits []string `json:"disabledUnits"`
	Compositor    string   `json:"compositor"`
	Reason        string   `json:"reason,omitempty"`
}

// Options carries the environment. Import receives the parsed monitors and
// keyboard (nil when the user config sets none) and writes them into the
// app config; Reload reloads the running compositor (a no-op when it is
// not running) and returns its config errors.
type Options struct {
	Home, AppID, Compositor string
	Now                     func() time.Time
	Systemd                 Systemd
	Import                  func(monitors []ipc.OutputConfig, kb *ipc.KeyboardSettings) error
	Reload                  func() error
}

func (o Options) appID() string {
	if o.AppID != "" {
		return o.AppID
	}
	return brand.AppID
}

func (o Options) hyprDir() string    { return filepath.Join(o.Home, ".config", "hypr") }
func (o Options) dataDir() string    { return filepath.Join(o.Home, ".local", "share", o.appID()) }
func (o Options) backupRoot() string { return filepath.Join(o.dataDir(), "backups") }

func (o Options) now() time.Time {
	if o.Now != nil {
		return o.Now()
	}
	return time.Now()
}

func (o Options) reload() error {
	if o.Reload == nil {
		return nil
	}
	return o.Reload()
}

func supported(o Options) error {
	if !strings.EqualFold(o.Compositor, "hyprland") {
		return fmt.Errorf("%w (current compositor: %s)", ErrNotSupported, o.Compositor)
	}
	return nil
}

// GetStatus reports the state without changing anything.
func GetStatus(o Options) Status {
	st := Status{Compositor: o.Compositor, DisabledUnits: []string{}}
	if err := supported(o); err != nil {
		st.Reason = err.Error()
	} else if err := checkManaged(o.hyprDir()); err != nil {
		st.Reason = err.Error()
	}
	st.Active = activeEntry(o.hyprDir()) != ""
	if dir, m, err := latestBackup(o); err == nil {
		st.Backup = dir
		if st.Active && m.DisabledUnits != nil {
			st.DisabledUnits = m.DisabledUnits
		}
	}
	return st
}

// Enable switches to exclusive mode. It is a no-op while already active.
// Any failure after the backup (import, write, reload with config errors)
// restores the backup and reports the error.
func Enable(o Options) (Status, error) {
	if err := supported(o); err != nil {
		return GetStatus(o), err
	}
	hypr := o.hyprDir()
	if err := checkManaged(hypr); err != nil {
		return GetStatus(o), err
	}
	if activeEntry(hypr) != "" {
		return GetStatus(o), nil
	}
	entry := entryName(hypr)
	monitors, kb := ScanImports(hypr, o.dataDir())

	dir, err := createBackup(o)
	if err != nil {
		return GetStatus(o), err
	}
	m := manifest{Version: 1, Created: o.now().Format(time.RFC3339), Entry: entry,
		DisabledUnits: []string{}, ImportedDisplays: len(monitors), ImportedKeyboard: kb != nil}
	if err := writeManifest(dir, m); err != nil {
		return rollback(o, dir, nil, err)
	}
	if o.Import != nil && (len(monitors) > 0 || kb != nil) {
		if err := o.Import(monitors, kb); err != nil {
			return rollback(o, dir, nil, fmt.Errorf("import settings: %w", err))
		}
	}
	if err := writeMinimal(hypr, entry, dir); err != nil {
		return rollback(o, dir, nil, err)
	}
	disabled, unitErrs := disableUnits(o)
	m.DisabledUnits = disabled
	if err := writeManifest(dir, m); err != nil {
		return rollback(o, dir, disabled, err)
	}
	if err := o.reload(); err != nil {
		return rollback(o, dir, disabled, fmt.Errorf("hyprland reload: %w", err))
	}
	st := GetStatus(o)
	st.Reason = strings.Join(unitErrs, "; ")
	return st, nil
}

// rollback undoes a failed Enable: the hypr tree comes back from dir,
// units are re-enabled, the compositor reloads the original config and the
// now redundant backup is removed. If the restore itself fails the backup
// is kept and named in the error.
func rollback(o Options, dir string, units []string, cause error) (Status, error) {
	if err := restoreTree(o, dir, false); err != nil {
		return GetStatus(o), fmt.Errorf("%w; restoring the backup failed: %v (backup kept in %s)", cause, err, dir)
	}
	enableUnits(o, units)
	_ = o.reload() // best effort: the original config was working before
	if err := os.RemoveAll(dir); err != nil {
		return GetStatus(o), fmt.Errorf("%w (backup kept in %s: %v)", cause, dir, err)
	}
	return GetStatus(o), cause
}

// Restore brings back the hypr tree from a backup (the newest unless from
// names one, as a path or a dir name under the backup root), re-enables the
// units it recorded and reloads the compositor. The backup is kept, and the
// replaced tree is saved inside it as replaced-<time>/.
func Restore(o Options, from string) (Status, error) {
	dir, m, err := resolveBackup(o, from)
	if err != nil {
		return GetStatus(o), err
	}
	if err := restoreTree(o, dir, true); err != nil {
		return GetStatus(o), err
	}
	errs := enableUnits(o, m.DisabledUnits)
	if err := o.reload(); err != nil {
		errs = append(errs, "hyprland reload: "+err.Error())
	}
	st := GetStatus(o)
	if len(errs) > 0 {
		return st, fmt.Errorf("restored %s, but: %s", dir, strings.Join(errs, "; "))
	}
	return st, nil
}
