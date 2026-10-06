// Package brand is the single source of truth for the app identity.
//
// Every directory name, socket, pid file, env var, layer namespace and
// action id derives from these constants. The Legacy* values name the
// project this one was forked from; they are only used for migration and
// backwards compatibility (env var fallbacks, legacy action ids).
package brand

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

const (
	AppID           = "yozakura"
	DisplayName     = "Yozakura"
	EnvPrefix       = "YOZAKURA_"
	LegacyAppID     = "ambxst"
	LegacyName      = "Ambxst"
	LegacyEnvPrefix = "AMBXST_"
	// RepoURL is the project's source repository.
	RepoURL = "https://github.com/23iq/yozakura"
	// LegacyBaseVersion is the legacy release this project was forked from.
	LegacyBaseVersion = "1.3.9"

	// Daemon is the compositor IPC daemon's binary name. Its socket,
	// config file, env vars and log prefixes all derive from it (see the
	// Daemon* helpers below); renaming the daemon means changing this
	// constant plus the package/dir names.
	Daemon = "yozd"
	// LegacyDaemon is the external daemon yozd replaced; only used to
	// migrate its config and to resolve binds that still invoke it.
	LegacyDaemon = "axctl"
)

// DaemonEnv returns the name of a daemon env var: "<DAEMON>_<name>".
func DaemonEnv(name string) string { return strings.ToUpper(Daemon) + "_" + name }

// DaemonConfigFile is the daemon's TOML config file name inside the data dir.
func DaemonConfigFile() string { return Daemon + ".toml" }

// DaemonLog returns a log prefix for the daemon: "[<daemon>]" or
// "[<daemon>-<tag>]".
func DaemonLog(tag string) string {
	if tag == "" {
		return "[" + Daemon + "]"
	}
	return "[" + Daemon + "-" + tag + "]"
}

// DaemonSocketPath returns the daemon's per-user IPC socket:
// $<DAEMON>_SOCKET when set, else $XDG_RUNTIME_DIR/<daemon>.sock, else
// /tmp/<daemon>-<uid>.sock. The daemon and every client resolve it here.
func DaemonSocketPath() string {
	if p := os.Getenv(DaemonEnv("SOCKET")); p != "" {
		return p
	}
	if runtime := os.Getenv("XDG_RUNTIME_DIR"); runtime != "" {
		return filepath.Join(runtime, Daemon+".sock")
	}
	// A parent that cleared the env (Codex MCP servers) still has the
	// per-user runtime dir the daemon listens in.
	if runtime := fmt.Sprintf("/run/user/%d", os.Getuid()); fileExists(filepath.Join(runtime, Daemon+".sock")) {
		return filepath.Join(runtime, Daemon+".sock")
	}
	return fmt.Sprintf("/tmp/%s-%d.sock", Daemon, os.Getuid())
}

// DaemonCommand returns a shell command line invoking the daemon CLI.
func DaemonCommand(args ...string) string {
	return strings.TrimSpace(Daemon + " " + strings.Join(args, " "))
}

// Env returns $<EnvPrefix><name>, falling back to the legacy prefix.
func Env(name string) string {
	if v, ok := os.LookupEnv(EnvPrefix + name); ok {
		return v
	}
	return os.Getenv(LegacyEnvPrefix + name)
}

// Action returns the keybind/IPC action id for name ("<app>.<name>").
func Action(name string) string { return AppID + "." + name }

// Namespace returns the layer-shell namespace for suffix ("<app>:<suffix>").
func Namespace(suffix string) string {
	if suffix == "" {
		return AppID
	}
	return AppID + ":" + suffix
}

// Command returns a shell command line invoking the CLI with args.
func Command(args ...string) string {
	return strings.TrimSpace(AppID + " " + strings.Join(args, " "))
}

// NormalizeAction maps a legacy action id ("<legacy>.<x>") to the current
// one; any other id is returned unchanged.
func NormalizeAction(id string) string {
	if rest, ok := strings.CutPrefix(id, LegacyAppID+"."); ok {
		return Action(rest)
	}
	return id
}

// ConfigBlockMarker is the first line ("<comment> <Name>") of the block the
// installer appends to a compositor config. It is the block's stable
// identity for append detection, removal and the display conflict scan.
func ConfigBlockMarker(comment string) string { return comment + " " + DisplayName }

// ConfigOverridesNote is the last line of that block; user overrides follow.
func ConfigOverridesNote(comment, keyword string) string {
	return fmt.Sprintf("%s Down here you can write or %s anything that you want to override from %s's settings.", comment, keyword, DisplayName)
}

func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}
