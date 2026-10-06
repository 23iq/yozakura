package mango

import (
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"testing"

	"yozakura/backend/pkg/yozd/ipc"
)

func TestReadKeyboardFromConfig(t *testing.T) {
	dir := t.TempDir()
	main := filepath.Join(dir, "config.conf")
	os.WriteFile(main, []byte(`# user config
xkb_rules_layout=us,ru
xkb_rules_variant=,phonetic
xkb_rules_options=grp:alt_shift_toggle # switch
# repeat_rate=99
repeat_rate=111
source=./keyboard.conf
`), 0o644)
	os.WriteFile(filepath.Join(dir, "keyboard.conf"), []byte("repeat_delay=175\n"), 0o644)
	got, err := ReadKeyboard(main)
	if err != nil {
		t.Fatal(err)
	}
	want := ipc.KeyboardSettings{
		Layouts: []string{"us", "ru"}, Variants: []string{"", "phonetic"},
		Options: []string{"grp:alt_shift_toggle"}, RepeatRate: 111, RepeatDelay: 175,
	}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("got %+v\nwant %+v", got, want)
	}
	os.WriteFile(main, []byte("repeat_rate=30\n"), 0o644)
	if _, err := ReadKeyboard(main); !errors.Is(err, ipc.ErrNotSupported) {
		t.Fatalf("no layout configured: want ErrNotSupported, got %v", err)
	}
}
