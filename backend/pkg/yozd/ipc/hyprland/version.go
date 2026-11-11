package hyprland

import (
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
)

// runningVersion returns the Hyprland version, queried once; a failed
// query is retried on the next call.
func (h *Hyprland) runningVersion() (string, bool) {
	h.versionMu.Lock()
	if h.versionKnown {
		version := h.version
		h.versionMu.Unlock()
		return version, true
	}
	h.versionMu.Unlock()

	resp, err := h.dispatch("j/version")
	if err != nil {
		return "", false
	}

	version, err := parseHyprlandVersion(resp)
	if err != nil {
		return "", false
	}

	h.versionMu.Lock()
	h.version = version
	h.versionKnown = true
	h.versionMu.Unlock()
	return version, true
}

func (h *Hyprland) supportsLuaDispatchers() bool {
	version, ok := h.runningVersion()
	return ok && isHyprlandVersionAtLeast(version, 0, 55)
}

// screencopyIsLogical reports whether screencopy frames arrive already in
// logical orientation: Hyprland 0.57 (901881c9f "render: always render in
// normal transform") sends the transformed size while wl_output keeps
// reporting the monitor transform.
func (h *Hyprland) screencopyIsLogical() bool {
	version, ok := h.runningVersion()
	return ok && isHyprlandVersionAtLeast(version, 0, 57)
}

// UsesLuaConfig reports whether the running Hyprland reads the Lua config
// (0.55+): runtime option changes then go through `eval hl.config(...)`
// instead of `keyword`.
func (h *Hyprland) UsesLuaConfig() bool { return h.supportsLuaDispatchers() }

func parseHyprlandVersion(resp string) (string, error) {
	trimmed := strings.TrimSpace(resp)
	if strings.HasPrefix(trimmed, "{") {
		var data struct {
			Version string `json:"version"`
			Tag     string `json:"tag"`
		}
		if err := json.Unmarshal([]byte(trimmed), &data); err != nil {
			return "", err
		}
		if data.Version != "" {
			return data.Version, nil
		}
		if data.Tag != "" {
			return data.Tag, nil
		}
		return "", fmt.Errorf("hyprland version response did not include version")
	}

	fields := strings.Fields(trimmed)
	for _, field := range fields {
		field = strings.TrimPrefix(field, "v")
		if _, err := parseVersionNumber(field); err == nil {
			return field, nil
		}
	}
	return "", fmt.Errorf("could not parse hyprland version from %q", trimmed)
}

func isHyprlandVersionAtLeast(version string, major, minor int) bool {
	parsed, err := parseVersionNumber(version)
	if err != nil {
		return false
	}
	if parsed.major != major {
		return parsed.major > major
	}
	return parsed.minor >= minor
}

type versionNumber struct {
	major int
	minor int
}

func parseVersionNumber(version string) (versionNumber, error) {
	clean := strings.TrimPrefix(strings.TrimSpace(version), "v")
	parts := strings.Split(clean, ".")
	if len(parts) < 2 {
		return versionNumber{}, fmt.Errorf("invalid version %q", version)
	}

	major, err := strconv.Atoi(versionDigits(parts[0]))
	if err != nil {
		return versionNumber{}, err
	}
	minor, err := strconv.Atoi(versionDigits(parts[1]))
	if err != nil {
		return versionNumber{}, err
	}
	return versionNumber{major: major, minor: minor}, nil
}

func versionDigits(value string) string {
	for i, r := range value {
		if r < '0' || r > '9' {
			return value[:i]
		}
	}
	return value
}
