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
// each only when it is graphical (Type wayland or x11) or is the user's
// display session; else the user's display session. A daemon (re)started
// from a TTY context (a tmux server first started on a TTY) would otherwise
// pin the match to the TTY session and ignore the graphical one's Lock.
// "" when none resolves (every session's Lock then counts).
func ownSession(conn *dbus.Conn) dbus.ObjectPath {
	if conn == nil {
		return ""
	}
	l := login1{conn}
	display := l.userDisplay()
	accept := func(p dbus.ObjectPath) bool {
		if p == "" {
			return false
		}
		if p == display {
			return true
		}
		t := l.sessionType(p)
		return t == "wayland" || t == "x11"
	}
	if id := os.Getenv("XDG_SESSION_ID"); id != "" {
		if p := l.managerPath("GetSession", id); accept(p) {
			return p
		}
	}
	if p := l.managerPath("GetSessionByPID", uint32(os.Getpid())); accept(p) {
		return p
	}
	return display
}

type login1 struct{ conn *dbus.Conn }

// managerPath calls a Manager method that returns an object path; "" on
// any error or for "/".
func (l login1) managerPath(method string, args ...any) dbus.ObjectPath {
	ctx, cancel := context.WithTimeout(context.Background(), lookupTimeout)
	defer cancel()
	var p dbus.ObjectPath
	if err := l.conn.Object(login1Dest, login1Path).CallWithContext(ctx, login1Manager+"."+method, 0, args...).Store(&p); err != nil || !p.IsValid() || p == "/" {
		return ""
	}
	return p
}

// property reads one property of the login1 object at path.
func (l login1) property(path dbus.ObjectPath, iface, name string) (dbus.Variant, bool) {
	ctx, cancel := context.WithTimeout(context.Background(), lookupTimeout)
	defer cancel()
	var v dbus.Variant
	if err := l.conn.Object(login1Dest, path).CallWithContext(ctx, "org.freedesktop.DBus.Properties.Get", 0,
		iface, name).Store(&v); err != nil {
		return dbus.Variant{}, false
	}
	return v, true
}

// sessionType is the session's Type (wayland, x11, tty, ...); "" unknown.
func (l login1) sessionType(p dbus.ObjectPath) string {
	v, ok := l.property(p, "org.freedesktop.login1.Session", "Type")
	if !ok {
		return ""
	}
	t, _ := v.Value().(string)
	return t
}

// userDisplay is the user's display session (User.Display); "" for none.
func (l login1) userDisplay() dbus.ObjectPath {
	user := l.managerPath("GetUser", uint32(os.Getuid()))
	if user == "" {
		return ""
	}
	v, ok := l.property(user, "org.freedesktop.login1.User", "Display")
	if !ok {
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
