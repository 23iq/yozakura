package ipc

import (
	"reflect"
	"testing"
)

func TestKeyboardNormalizePadsAndDrops(t *testing.T) {
	got := KeyboardSettings{
		Layouts:  []string{" us ", "", "ru"},
		Variants: []string{"", "x", "phonetic", "extra"},
		Options:  []string{"grp:alt_shift_toggle", "", "caps:escape"},
	}.Normalize()
	if !reflect.DeepEqual(got.Layouts, []string{"us", "ru"}) || !reflect.DeepEqual(got.Variants, []string{"", "phonetic"}) ||
		!reflect.DeepEqual(got.Options, []string{"grp:alt_shift_toggle", "caps:escape"}) {
		t.Fatalf("%+v", got)
	}
	got = KeyboardSettings{Layouts: []string{"us", "de"}, Variants: []string{"nodeadkeys"}}.Normalize()
	if !reflect.DeepEqual(got.Variants, []string{"nodeadkeys", ""}) {
		t.Fatalf("%+v", got)
	}
	got = KeyboardSettings{Layouts: []string{"us(intl)", "cn+tib"}}.Normalize()
	if len(got.Layouts) != 2 {
		t.Fatalf("%+v", got)
	}
}

func TestKeyboardRejectsInjection(t *testing.T) {
	bad := []KeyboardSettings{
		{Layouts: []string{`us"; os.exit()`}},
		{Layouts: []string{"us"}, Variants: []string{"a b"}},
		{Layouts: []string{"us"}, Options: []string{"x,y"}},
		{Layouts: []string{"us"}, Model: "pc105;x"},
		{Layouts: []string{"us"}, RepeatRate: -1},
	}
	for _, s := range bad {
		if s.Validate() == nil {
			t.Errorf("accepted %+v", s)
		}
	}
	if got := bad[0].Normalize(); len(got.Layouts) != 0 {
		t.Fatalf("normalize kept %+v", got)
	}
	if err := (KeyboardSettings{Layouts: []string{"us", "ru"}, Variants: []string{""}}).Validate(); err != nil {
		t.Fatal(err)
	}
}
