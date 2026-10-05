package migrate

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/paths"
)

// DaemonMove is one legacy compositor-daemon file and its new location.
type DaemonMove struct{ From, To string }

// DaemonMoves lists the files the external compositor daemon
// (brand.LegacyDaemon) kept that the built-in one (brand.Daemon) now owns:
// its config in the data dir and its saved brightness levels under the
// user config dir.
func DaemonMoves(p paths.Paths, userConfigDir string) []DaemonMove {
	moves := []DaemonMove{{
		From: filepath.Join(p.DataDir, brand.LegacyDaemon+".toml"),
		To:   p.DaemonToml(),
	}}
	if userConfigDir != "" {
		moves = append(moves, DaemonMove{
			From: filepath.Join(userConfigDir, brand.LegacyDaemon, "brightness.tsv"),
			To:   filepath.Join(userConfigDir, brand.Daemon, "brightness.tsv"),
		})
	}
	return moves
}

// MigrateDaemonFiles renames each legacy daemon file to its new name once.
// Idempotent: a move is skipped when the source is missing or the target
// already exists (the target always wins). Returns the moves performed.
func MigrateDaemonFiles(moves []DaemonMove) ([]DaemonMove, error) {
	var done []DaemonMove
	var errs []error
	for _, m := range moves {
		if !isRegular(m.From) || exists(m.To) {
			continue
		}
		if err := os.MkdirAll(filepath.Dir(m.To), 0o755); err != nil {
			errs = append(errs, err)
			continue
		}
		if err := os.Rename(m.From, m.To); err != nil {
			errs = append(errs, fmt.Errorf("rename %s: %w", m.From, err))
			continue
		}
		done = append(done, m)
	}
	return done, errors.Join(errs...)
}

// StopLegacyDaemon stops a leftover external compositor daemon (and its
// subscribe client) started by an older build; the built-in daemon uses its
// own socket, so the old one would only duplicate idle monitors and config
// generation.
func StopLegacyDaemon() {
	_ = exec.Command("pkill", "-f", brand.LegacyDaemon+".*daemon").Run()
	_ = exec.Command("pkill", "-f", brand.LegacyDaemon+" subscribe").Run()
}
