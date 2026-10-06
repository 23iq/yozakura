package yozdcli

import (
	"errors"
	"reflect"
	"testing"

	"yozakura/backend/pkg/yozd/ipc"
)

func fake(out string, got *[]string) *Client {
	return &Client{Run: func(args ...string) ([]byte, error) {
		*got = args
		return []byte(out), nil
	}}
}

func TestApplyOutputPassesJSONAsOneArg(t *testing.T) {
	var args []string
	c := fake("Success\n", &args)
	if err := c.ApplyOutput(ipc.OutputConfig{Name: "DP-1", Enabled: true}); err != nil {
		t.Fatal(err)
	}
	if len(args) != 3 || args[0] != "monitor" || args[1] != "apply" || args[2][0] != '{' {
		t.Fatalf("args = %q", args)
	}
	if err := c.ApplyOutput(ipc.OutputConfig{Name: "DP-1; rm -rf"}); err == nil {
		t.Fatal("invalid name must be rejected before exec")
	}
}

func TestErrorLines(t *testing.T) {
	var args []string
	c := fake("Error: feature not supported on this compositor\n", &args)
	if err := c.ApplyOutput(ipc.OutputConfig{Name: "DP-1"}); !errors.Is(err, ipc.ErrNotSupported) {
		t.Fatalf("want ErrNotSupported, got %v", err)
	}
	c = fake("Error: boom\n", &args)
	if _, err := c.Outputs(); err == nil || err.Error() != "boom" {
		t.Fatalf("want boom, got %v", err)
	}
	// a dead daemon must not look like success
	c = fake("Error connecting to daemon: dial unix /run/user/1000/yozd.sock: connect: no such file or directory\n", &args)
	if err := c.ApplyOutput(ipc.OutputConfig{Name: "DP-1"}); err == nil {
		t.Fatal("connection error must fail")
	}
	if err := c.NextLayout(); err == nil {
		t.Fatal("connection error must fail")
	}
}

func TestActiveLayoutAndNext(t *testing.T) {
	var args []string
	c := fake(`{"names":["us","ru"],"index":0,"name":"Russian"}`, &args)
	st, err := c.ActiveLayout()
	if err != nil || st.Name != "Russian" || len(st.Names) != 2 {
		t.Fatalf("state = %+v, %v", st, err)
	}
	if err := c.NextLayout(); err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(args, []string{"system", "switch-keyboard-layout", "next"}) {
		t.Fatalf("args = %q", args)
	}
}
