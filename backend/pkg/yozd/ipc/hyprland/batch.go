package hyprland

import (
	"fmt"
	"strings"
)

// checkBatchReply verifies the reply to a [[BATCH]] request of cmds:
// Hyprland concatenates the per-command replies ("okok"; some builds
// separate them with whitespace). A `keyword` succeeded only when its reply
// is "ok"; any other reply is an error message, and the replies after it
// cannot be told apart from it, so that command and every later one count
// as failed. Other commands (`eval`, `dispatch`) have no fixed success
// reply: from the first of them on, only an explicit error is detected.
func checkBatchReply(cmds []string, reply string) error {
	rest := reply
	for i, c := range cmds {
		c = strings.TrimSpace(c)
		if c == "" {
			continue
		}
		rest = strings.TrimLeft(rest, " \t\r\n")
		if !strings.HasPrefix(c, "keyword ") {
			if low := strings.ToLower(rest); strings.Contains(low, "error") || strings.Contains(low, "unknown request") {
				return &BatchError{Failed: trimAll(cmds[i:]), Reply: strings.TrimSpace(rest)}
			}
			return nil
		}
		if !strings.HasPrefix(rest, "ok") {
			return &BatchError{Failed: trimAll(cmds[i:]), Reply: strings.TrimSpace(rest)}
		}
		rest = rest[len("ok"):]
	}
	return nil
}

// BatchError reports the commands of a [[BATCH]] request that Hyprland
// did not confirm (the first rejected one and everything after it).
type BatchError struct {
	Failed []string
	Reply  string
}

func (e *BatchError) Error() string {
	reply := e.Reply
	if reply == "" {
		reply = "no reply"
	}
	return fmt.Sprintf("hyprland rejected %q (%d unconfirmed): %s", e.Failed[0], len(e.Failed), reply)
}

func trimAll(cmds []string) []string {
	out := make([]string, 0, len(cmds))
	for _, c := range cmds {
		if c = strings.TrimSpace(c); c != "" {
			out = append(out, c)
		}
	}
	return out
}
