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
	"path/filepath"
	"strings"
	"time"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/fsutil"
	"yozakura/backend/pkg/yozd/ipc"
)

var (
	ErrNotSupported = errors.New("exclusive mode is only supported on Hyprland")
	ErrHomeManager  = errors.New("the Hyprland config is managed by home-manager (a link into /nix/store); enable exclusive mode through the Nix module instead")
	ErrLinkedDir    = errors.New("~/.config/hypr is a symlink; exclusive mode only manages a real directory")
	ErrNoBackup     = errors.New("no exclusive-mode backup found")
	// ErrNoCompositor is what Reload returns when no Hyprland is running to
	// reload (fresh install from a TTY): Enable then validates offline.
	ErrNoCompositor = errors.New("no running Hyprland")
	ErrNotActive    = errors.New("exclusive mode is not active; name a backup to restore it anyway")
)

// Systemd manages user units (systemctl --user).
type Systemd interface {
	IsEnabled(unit string) bool
	IsActive(unit string) bool
	// Disable is `disable --now`: the unit is disabled and stopped.
	Disable(unit string) error
	// Enable is `enable`, or `enable --now` when start is set (the unit
	// was running before Disable stopped it).
	Enable(unit string, start bool) error
	ListUserUnits(pattern string) []string
}

// Status is the exclusive-mode state. Backup is the newest backup dir;
// DisabledUnits are the units that backup recorded (only while Active).
// Restore also reports Replaced (where the replaced tree was saved) and
// Previous (the config values Import overwrote; the imported ones are
// kept, these let the caller show or revert them).
type Status struct {
	Active        bool           `json:"active"`
	Backup        string         `json:"backup"`
	DisabledUnits []string       `json:"disabledUnits"`
	Compositor    string         `json:"compositor"`
	Reason        string         `json:"reason,omitempty"`
	Replaced      string         `json:"replaced,omitempty"`
	Previous      map[string]any `json:"previous,omitempty"`
}

// Options carries the environment.
//
// Import receives the parsed monitors and keyboard (kb is nil when the user
// config sets none), writes them into the app config and returns the values
// it overwrote, keyed by config key (stored in the manifest). On error it
// must leave the config unchanged. Unimport writes such values back; it is
// called when Enable fails after a successful Import. Reload reloads the
// running compositor (a no-op when it is not running) and returns its
// config errors.
type Options struct {
	Home, AppID, Compositor string
	// HyprDir is the Hyprland config dir; empty means <Home>/.config/hypr.
	HyprDir  string
	Now      func() time.Time
	Systemd  Systemd
	Import   func(monitors []ipc.OutputConfig, kb *ipc.KeyboardSettings) (previous map[string]any, err error)
	Unimport func(previous map[string]any) error
	Reload   func() error
	// Polkit is the command that starts the polkit agent ("" = none found);
	// the minimal entry runs it at Hyprland start.
	Polkit string
	// Offline checks the new entry file when Reload says ErrNoCompositor.
	// It returns config errors as err and a warning when it could not
	// check (no Hyprland binary, flag unsupported). Nil: nothing is checked.
	Offline func(entry string) (warning string, err error)
}

func (o Options) appID() string {
	if o.AppID != "" {
		return o.AppID
	}
	return brand.AppID
}

func (o Options) hyprDir() string {
	if o.HyprDir != "" {
		return o.HyprDir
	}
	return filepath.Join(o.Home, ".config", "hypr")
}

// HyprPath is the Hyprland config dir exclusive mode manages.
func HyprPath(o Options) string      { return o.hyprDir() }
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
// Any failure after the backup (import, write, units, reload with config
// errors) undoes what was done and reports the error.
func Enable(o Options) (Status, error) {
	if err := supported(o); err != nil {
		return GetStatus(o), err
	}
	if err := checkManaged(o.hyprDir()); err != nil {
		return GetStatus(o), err // before the lock: a refusal creates nothing
	}
	unlock, err := fsutil.Lock(filepath.Join(o.backupRoot(), ".lock"))
	if err != nil {
		return GetStatus(o), fmt.Errorf("lock: %w", err)
	}
	defer unlock()
	return enable(o)
}

func enable(o Options) (Status, error) {
	hypr := o.hyprDir()
	if err := checkManaged(hypr); err != nil {
		return GetStatus(o), err
	}
	if activeEntry(hypr) != "" {
		return GetStatus(o), nil
	}
	entry := entryName(hypr)
	monitors, kb := ScanImports(hypr, o.dataDir())

	now := o.now()
	dir, missing, err := createBackup(o, now)
	if err != nil {
		return GetStatus(o), err
	}
	if activeEntry(filepath.Join(dir, "hypr")) != "" {
		_ = removeTree(dir)
		return GetStatus(o), errors.New("the Hyprland config already carries the exclusive-mode entry; not backing it up again")
	}
	r := &run{o: o, dir: dir, m: manifest{Version: 1, Created: now.Format(time.RFC3339), Entry: entry,
		HyprMissing: missing, DisabledUnits: []string{}, Units: []unitRecord{},
		ImportedDisplays: len(monitors), ImportedKeyboard: kb != nil}}
	if err := writeManifest(dir, r.m); err != nil {
		return r.rollback(err)
	}
	if o.Import != nil && (len(monitors) > 0 || kb != nil) {
		prev, err := o.Import(monitors, kb)
		if err != nil {
			return r.rollback(fmt.Errorf("import settings: %w", err))
		}
		r.imported, r.m.Previous = true, prev
		if err := writeManifest(dir, r.m); err != nil {
			return r.rollback(err)
		}
	}
	r.treeTouched = true
	if err := writeMinimal(hypr, entry, dir, o.Polkit); err != nil {
		return r.rollback(err)
	}
	unitErrs, err := disableUnits(o, dir, &r.m)
	if err != nil {
		return r.rollback(err)
	}
	var warns []string
	if err := o.reload(); errors.Is(err, ErrNoCompositor) {
		if o.Offline != nil {
			warn, oerr := o.Offline(filepath.Join(hypr, entry))
			if oerr != nil {
				return r.rollback(fmt.Errorf("config check: %w", oerr))
			}
			if warn != "" {
				warns = append(warns, warn)
			}
		}
	} else if err != nil {
		return r.rollback(fmt.Errorf("hyprland reload: %w", err))
	}
	st := GetStatus(o)
	st.Reason = strings.Join(append(unitErrs, warns...), "; ")
	return st, nil
}

// run is one Enable attempt, for rollback.
type run struct {
	o           Options
	dir         string
	m           manifest
	imported    bool
	treeTouched bool
}

// rollback undoes a failed Enable: the hypr tree comes back from the
// backup (when it was touched), recorded units are re-enabled (and started
// if they were running), imported settings are written back, the
// compositor reloads the original config and the now redundant backup is
// removed. If the tree restore fails the backup is kept and named.
func (r *run) rollback(cause error) (Status, error) {
	o := r.o
	var errs []string
	treeBack := true
	if r.treeTouched {
		if _, err := restoreTree(o, r.dir, r.m, o.now(), false); err != nil {
			treeBack = false
			errs = append(errs, "restoring the backup failed: "+err.Error())
		}
	}
	errs = append(errs, enableUnits(o, r.m.Units)...)
	if r.imported && o.Unimport != nil {
		if err := o.Unimport(r.m.Previous); err != nil {
			errs = append(errs, "could not revert imported settings: "+err.Error())
		}
	}
	if r.treeTouched && treeBack {
		_ = o.reload() // best effort: the original config was working before
	}
	if len(errs) > 0 {
		return GetStatus(o), fmt.Errorf("%w; rollback: %s (backup kept in %s)", cause, strings.Join(errs, "; "), r.dir)
	}
	if err := removeTree(r.dir); err != nil {
		return GetStatus(o), fmt.Errorf("%w (backup kept in %s: %v)", cause, r.dir, err)
	}
	return GetStatus(o), cause
}

// Restore brings back the hypr tree from a backup (the newest unless from
// names one, as a path or a dir name under the backup root), re-enables the
// units it recorded (starting the ones that were running) and reloads the
// compositor. Without from it refuses unless exclusive mode is active. The
// backup is kept, the replaced tree is saved inside it as replaced-<time>/
// and the imported settings stay (Status.Previous holds the old values).
func Restore(o Options, from string) (Status, error) {
	unlock, err := fsutil.Lock(filepath.Join(o.backupRoot(), ".lock"))
	if err != nil {
		return GetStatus(o), fmt.Errorf("lock: %w", err)
	}
	defer unlock()
	if from == "" && activeEntry(o.hyprDir()) == "" {
		return GetStatus(o), ErrNotActive
	}
	dir, m, err := resolveBackup(o, from)
	if err != nil {
		return GetStatus(o), err
	}
	replaced, err := restoreTree(o, dir, m, o.now(), true)
	if err != nil {
		return GetStatus(o), err
	}
	errs := enableUnits(o, m.Units)
	if err := o.reload(); err != nil && !errors.Is(err, ErrNoCompositor) {
		errs = append(errs, "hyprland reload: "+err.Error())
	}
	st := GetStatus(o)
	st.Replaced, st.Previous = replaced, m.Previous
	if len(errs) > 0 {
		return st, fmt.Errorf("restored %s, but: %s", dir, strings.Join(errs, "; "))
	}
	return st, nil
}
