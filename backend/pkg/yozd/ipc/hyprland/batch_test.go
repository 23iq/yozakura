package hyprland

import (
	"errors"
	"reflect"
	"testing"
)

func TestCheckBatchReply(t *testing.T) {
	kw := []string{"keyword general:gaps_in 4", "keyword general:gaps_out 8", "keyword decoration:rounding 6"}
	cases := []struct {
		name   string
		cmds   []string
		reply  string
		failed []string // nil: success
	}{
		{"all ok, concatenated", kw, "okokok", nil},
		{"all ok, separated", kw, "ok\n\nok\n\nok\n", nil},
		{"second rejected", kw, "okconfig option <general:gaps_out> does not exist.ok", kw[1:]},
		{"first rejected", kw, "Invalid dispatcher", kw},
		{"reply too short", kw, "okok", kw[2:]},
		{"empty reply", kw, "", kw},
		{"error prefix", kw[:1], "error: bad value", kw[:1]},
		{"trailing empty command", append(append([]string{}, kw[:1]...), " "), "ok", nil},
		{"eval without error", []string{"eval hl.config({})"}, "", nil},
		{"eval error", []string{"keyword a 1", "eval x"}, "oklua error: boom", []string{"eval x"}},
	}
	for _, c := range cases {
		err := checkBatchReply(c.cmds, c.reply)
		if c.failed == nil {
			if err != nil {
				t.Errorf("%s: unexpected %v", c.name, err)
			}
			continue
		}
		var be *BatchError
		if !errors.As(err, &be) {
			t.Errorf("%s: want a BatchError, got %v", c.name, err)
			continue
		}
		if !reflect.DeepEqual(be.Failed, c.failed) {
			t.Errorf("%s: failed %q, want %q", c.name, be.Failed, c.failed)
		}
	}
}
