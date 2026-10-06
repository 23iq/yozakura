package niri

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
	main := filepath.Join(dir, "config.kdl")
	os.WriteFile(main, []byte(`// user config
input {
    keyboard {
        xkb {
            layout "us,ru"
            variant ",phonetic"
            options "grp:alt_shift_toggle" // comment
        }
        repeat-delay 175
        repeat-rate 111
    }
    /-keyboard { xkb { layout "de"; } }
    touchpad { tap; }
}
/* block comment input { keyboard { xkb { layout "fr"; } } } */
include "extra.kdl"
`), 0o644)
	os.WriteFile(filepath.Join(dir, "extra.kdl"), []byte(`input { keyboard { repeat-rate 40; } }`), 0o644)
	got, err := ReadKeyboard(main)
	if err != nil {
		t.Fatal(err)
	}
	want := ipc.KeyboardSettings{
		Layouts: []string{"us", "ru"}, Variants: []string{"", "phonetic"},
		Options: []string{"grp:alt_shift_toggle"}, RepeatRate: 40, RepeatDelay: 175,
	}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("got %+v\nwant %+v", got, want)
	}

	os.WriteFile(main, []byte("input { touchpad { tap; } }\n"), 0o644)
	if _, err := ReadKeyboard(main); !errors.Is(err, ipc.ErrNotSupported) {
		t.Fatalf("no layout configured: want ErrNotSupported, got %v", err)
	}
	if _, err := ReadKeyboard(filepath.Join(dir, "missing.kdl")); !errors.Is(err, ipc.ErrNotSupported) {
		t.Fatalf("missing file: want ErrNotSupported, got %v", err)
	}
}
