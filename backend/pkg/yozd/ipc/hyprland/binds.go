package hyprland

import (
	"encoding/json"
	"fmt"
	"strings"

	"yozakura/backend/pkg/yozd/ipc"
)

// ListBinds returns every live bind (`hyprctl binds -j`).
func (h *Hyprland) ListBinds() ([]ipc.Bind, error) {
	resp, err := h.dispatch("j/binds")
	if err != nil {
		return nil, err
	}
	return ParseBinds([]byte(resp))
}

// ParseBinds decodes `hyprctl binds -j`.
func ParseBinds(data []byte) ([]ipc.Bind, error) {
	var raw []struct {
		Modmask        int    `json:"modmask"`
		Key            string `json:"key"`
		Dispatcher     string `json:"dispatcher"`
		Arg            string `json:"arg"`
		Description    string `json:"description"`
		HasDescription bool   `json:"has_description"`
		Submap         string `json:"submap"`
		Release        bool   `json:"release"`
		Locked         bool   `json:"locked"`
		Mouse          bool   `json:"mouse"`
	}
	if err := json.Unmarshal(data, &raw); err != nil {
		return nil, fmt.Errorf("hyprland binds: %w", err)
	}
	out := make([]ipc.Bind, 0, len(raw))
	for _, b := range raw {
		desc := ""
		if b.HasDescription {
			desc = b.Description
		}
		out = append(out, ipc.Bind{
			Modifiers: ipc.ModsFromMask(b.Modmask), Key: b.Key, Dispatcher: b.Dispatcher, Arg: b.Arg,
			Description: desc, Submap: b.Submap, Release: b.Release, Locked: b.Locked, Mouse: b.Mouse, Source: "ipc",
		})
	}
	return out, nil
}

// ConfigErrors lists the errors of the last config load (empty when it was
// clean).
func (h *Hyprland) ConfigErrors() ([]string, error) {
	out, err := h.dispatch("configerrors")
	if err != nil {
		return nil, err
	}
	return parseConfigErrors(out), nil
}

func parseConfigErrors(out string) []string {
	errs := []string{}
	for _, l := range strings.Split(out, "\n") {
		l = strings.TrimSpace(l)
		if l != "" && !strings.EqualFold(l, "no errors") {
			errs = append(errs, l)
		}
	}
	return errs
}
