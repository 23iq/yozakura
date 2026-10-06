package exclusive

import (
	"errors"
	"reflect"
	"testing"
)

func TestExecSystemdArgv(t *testing.T) {
	var calls [][]string
	s := ExecSystemd{Run: func(args ...string) ([]byte, error) {
		calls = append(calls, args)
		switch args[2] {
		case "is-enabled", "is-active":
			return []byte(map[string]string{"is-enabled": "enabled\n", "is-active": "inactive\n"}[args[2]]), nil
		case "list-unit-files":
			return []byte("quickshell-a.service enabled enabled\nquickshell-b.service disabled enabled\n"), nil
		}
		return []byte("Failed: nope\n"), errors.New("exit 1")
	}}
	if !s.IsEnabled("waybar.service") || s.IsActive("waybar.service") {
		t.Fatal("is-enabled/is-active parsing")
	}
	if got := s.ListUserUnits("quickshell*"); !reflect.DeepEqual(got, []string{"quickshell-a.service", "quickshell-b.service"}) {
		t.Fatalf("units %v", got)
	}
	err := s.Disable("waybar.service")
	if err == nil || err.Error() != "Failed: nope" {
		t.Fatalf("disable error %v", err)
	}
	_ = s.Enable("mako.service", true)
	_ = s.Enable("dunst.service", false)
	last := calls[len(calls)-2:]
	want := [][]string{
		{"--user", "--no-pager", "enable", "--now", "mako.service"},
		{"--user", "--no-pager", "enable", "dunst.service"},
	}
	if !reflect.DeepEqual(last, want) {
		t.Fatalf("argv %v", last)
	}
	if !reflect.DeepEqual(calls[3], []string{"--user", "--no-pager", "disable", "--now", "waybar.service"}) {
		t.Fatalf("disable argv %v", calls[3])
	}
}
