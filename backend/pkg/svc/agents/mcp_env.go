package agents

import "os"

// shellEnvVars are the session variables the built-in shell MCP server
// needs: the backend socket (XDG_RUNTIME_DIR), the compositor (Wayland,
// Hyprland, niri), D-Bus (Bluetooth, media, notifications) and the XDG
// dirs. Codex starts stdio MCP servers with a minimal environment, so they
// are forwarded explicitly; Claude passes them through unchanged.
var shellEnvVars = []string{
	"XDG_RUNTIME_DIR", "WAYLAND_DISPLAY", "DISPLAY", "HYPRLAND_INSTANCE_SIGNATURE", "NIRI_SOCKET",
	"DBUS_SESSION_BUS_ADDRESS", "XDG_CURRENT_DESKTOP", "XDG_SESSION_TYPE",
	"XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_CACHE_HOME", "XDG_STATE_HOME",
}

// withShellEnv adds the session variables that are set in the backend's
// environment to the server's env, keeping values it already has.
func withShellEnv(srv MCPServer) MCPServer {
	env := make(map[string]string, len(srv.Env)+len(shellEnvVars))
	for _, k := range shellEnvVars {
		if v := os.Getenv(k); v != "" {
			env[k] = v
		}
	}
	for k, v := range srv.Env {
		env[k] = v
	}
	if len(env) > 0 {
		srv.Env = env
	}
	return srv
}
