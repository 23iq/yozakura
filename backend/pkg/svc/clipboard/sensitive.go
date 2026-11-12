package clipboard

import (
	"bytes"
	"context"
	"strings"

	"yozakura/backend/pkg/proc"
)

// sensitiveHintMime is the offer password managers (KeePassXC, Bitwarden,
// KDE Wallet clients, ...) add to a copied secret; its content is
// sensitiveHintValue. Clipboard managers are expected not to record such
// copies.
const (
	sensitiveHintMime  = "x-kde-passwordManagerHint"
	sensitiveHintValue = "secret"
)

// isSensitiveOffer reports whether the offered types (wl-paste --list-types
// output) carry the password-manager hint set to "secret". Only the hint is
// read, never the secret itself.
func isSensitiveOffer(types string, read func(mime string) ([]byte, error)) bool {
	for _, line := range strings.Split(types, "\n") {
		if strings.TrimSpace(line) != sensitiveHintMime {
			continue
		}
		val, err := read(sensitiveHintMime)
		return err == nil && string(bytes.TrimSpace(val)) == sensitiveHintValue
	}
	return false
}

// readOffer reads one offered type of the current selection.
func readOffer(mime string) ([]byte, error) {
	return proc.Run(context.Background(), "wl-paste", "--type", mime)
}
