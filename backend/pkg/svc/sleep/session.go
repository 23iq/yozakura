package sleep

import (
	"context"
	"os"
	"time"

	"github.com/godbus/dbus/v5"
)

const (
	login1Dest    = "org.freedesktop.login1"
	login1Path    = dbus.ObjectPath("/org/freedesktop/login1")
	login1Manager = "org.freedesktop.login1.Manager"
)

// lookupTimeout bounds each login1 call: without logind the call fails at
// once, a hung logind must not hold the daemon's start.
const lookupTimeout = 2 * time.Second

// ownSession resolves the login1 session this process belongs to, so a
// Lock of another session (another seat, a TTY login, another user) does
// not lock this one: $XDG_SESSION_ID, else the session of this process,
// else the user's display session. "" when none resolves.
func ownSession(conn *dbus.Conn) dbus.ObjectPath {
	if conn == nil {
		return ""
	}
	mgr := conn.Object(login1Dest, login1Path)
	call := func(method string, args ...any) dbus.ObjectPath {
		ctx, cancel := context.WithTimeout(context.Background(), lookupTimeout)
		defer cancel()
		var p dbus.ObjectPath
		if err := mgr.CallWithContext(ctx, login1Manager+"."+method, 0, args...).Store(&p); err != nil || !p.IsValid() || p == "/" {
			return ""
		}
		return p
	}
	if id := os.Getenv("XDG_SESSION_ID"); id != "" {
		if p := call("GetSession", id); p != "" {
			return p
		}
	}
	if p := call("GetSessionByPID", uint32(os.Getpid())); p != "" {
		return p
	}
	user := call("GetUser", uint32(os.Getuid()))
	if user == "" {
		return ""
	}
	ctx, cancel := context.WithTimeout(context.Background(), lookupTimeout)
	defer cancel()
	var v dbus.Variant
	if err := conn.Object(login1Dest, user).CallWithContext(ctx, "org.freedesktop.DBus.Properties.Get", 0,
		"org.freedesktop.login1.User", "Display").Store(&v); err != nil {
		return ""
	}
	// Display is (so): the session id and its object path, "/" for none
	if fields, ok := v.Value().([]any); ok && len(fields) == 2 {
		if p, ok := fields[1].(dbus.ObjectPath); ok && p.IsValid() && p != "/" {
			return p
		}
	}
	return ""
}
