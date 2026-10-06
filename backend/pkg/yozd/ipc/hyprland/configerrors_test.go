package hyprland

import (
	"reflect"
	"testing"
)

func TestParseConfigErrors(t *testing.T) {
	if got := parseConfigErrors("\n"); got == nil || len(got) != 0 {
		t.Fatalf("clean must be empty non-nil: %#v", got)
	}
	got := parseConfigErrors("Config error in file x line 3: bad\n\nConfig error in file x line 9: worse\n")
	if !reflect.DeepEqual(got, []string{"Config error in file x line 3: bad", "Config error in file x line 9: worse"}) {
		t.Fatalf("%#v", got)
	}
}
