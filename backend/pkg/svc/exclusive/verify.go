package exclusive

import (
	"context"
	"errors"
	"fmt"
	"os/exec"
	"strings"
	"time"

	"yozakura/backend/pkg/brand"
)

const resultHeader = "Config parsing result:"

// hyprlandBin is the binary the offline check runs (replaced in tests).
var hyprlandBin = "Hyprland"

// verifyConfig checks entry with `Hyprland --verify-config -c <entry>`,
// which parses the config without starting a session. Config errors are
// returned as err; when the binary is missing or does not understand the
// flag the config is accepted with a warning (it is checked on the next
// Hyprland start).
func verifyConfig(entry string) (string, error) {
	warn := "config will be checked on next Hyprland start; restore with `" + brand.AppID + " install --restore`"
	bin, err := exec.LookPath(hyprlandBin)
	if err != nil {
		return "Hyprland not found: " + warn, nil
	}
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	out, runErr := exec.CommandContext(ctx, bin, "--verify-config", "-c", entry).CombinedOutput()
	errs, ok := parseVerify(string(out))
	if !ok {
		reason := "could not verify the config"
		var ee *exec.ExitError
		if runErr != nil && !errors.As(runErr, &ee) {
			reason += ": " + runErr.Error()
		}
		return reason + "; " + warn, nil
	}
	if len(errs) > 0 {
		return "", fmt.Errorf("%s", strings.Join(errs, "; "))
	}
	return "", nil
}

// parseVerify reads the "Config parsing result" block: "config ok" or the
// error lines. ok is false when the block is missing (flag unsupported).
func parseVerify(out string) (errs []string, ok bool) {
	_, after, found := strings.Cut(out, resultHeader)
	if !found {
		return nil, false
	}
	for _, l := range strings.Split(after, "\n") {
		l = strings.TrimSpace(l)
		if l == "" || strings.EqualFold(l, "config ok") {
			continue
		}
		errs = append(errs, l)
	}
	return errs, true
}
