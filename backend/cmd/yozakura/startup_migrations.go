package main

// runStartupMigrations brings the user's files up to date before a command
// runs: the legacy import, the one-time key migrations and default shifts,
// and seeding a new install's config. Order matters: the legacy import runs
// before anything creates the config dir, and the onboarding mark before
// ensureConfigFiles can create a fresh general.json.
func runStartupMigrations(shellStart bool) {
	migrateLegacy()
	if shellStart {
		migrateDaemonFiles() // the shell start owns the daemon's files
	}
	markExistingInstallOnboarded()
	markLegacyKeyboard()
	migrateNotchStyle()
	markLegacyAppHooks()
	shiftDefaults()
	ensureConfigFiles()
}

// skipsStartupMigrations reports whether a command can run without
// runStartupMigrations. Keybinds start these commands many times a minute,
// and each run used to re-check every migration first.
//
//   - screen, suspend, brightness and ipc only talk to the daemon, yozd or
//     logind and read no config file; brightness' saved levels belong to
//     the daemon files only the shell start migrates.
//   - run, toggle and lock send a UI command to the shell. While a daemon
//     is up it ran every migration at its own start (the shell start never
//     skips), so there is nothing left to do. With no daemon they keep the
//     migrations: `run terminal` then reads general.json itself, and a
//     daemon they start migrates again anyway.
//
// Everything else (the shell start, wallpaper, thumbs, onboarding, reload,
// quit, ...) keeps them. Commands that read or write config or presets
// return before the migrations in main and are not affected.
func skipsStartupMigrations(args []string, alive func() bool) bool {
	if len(args) == 0 {
		return false
	}
	switch args[0] {
	case "screen", "suspend", "brightness", "ipc":
		return true
	case "run", "toggle", "lock":
		return alive()
	}
	return false
}
