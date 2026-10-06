package mango

import (
	"os"
	"path/filepath"
	"testing"
)

func TestParseBinds(t *testing.T) {
	src := "# comment\nbind=SUPER,Return,spawn,foot\nbindl=NONE,XF86AudioMute,spawn,wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle\n" +
		"bind=SUPER+SHIFT,q,killclient,\nmousebind=SUPER,btn_left,moveresize,curmove\nborderpx=2\n"
	binds := ParseBinds(src, "config.conf")
	if len(binds) != 4 {
		t.Fatalf("got %d: %+v", len(binds), binds)
	}
	if b := binds[0]; b.Key != "Return" || b.Modifiers[0] != "SUPER" || b.Dispatcher != "spawn" || b.Arg != "foot" {
		t.Fatalf("bind 0: %+v", b)
	}
	if b := binds[1]; !b.Locked || len(b.Modifiers) != 0 || b.Arg != "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle" {
		t.Fatalf("bind 1: %+v", b)
	}
	if b := binds[2]; len(b.Modifiers) != 2 || b.Key != "q" {
		t.Fatalf("bind 2: %+v", b)
	}
	if !binds[3].Mouse {
		t.Fatalf("mousebind: %+v", binds[3])
	}
}

func TestReadBindsFollowsSource(t *testing.T) {
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "config.conf"), []byte("source=./binds.conf\nbind=SUPER,a,spawn,a\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "binds.conf"), []byte("bind=SUPER,b,spawn,b\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if binds := ReadBinds(filepath.Join(dir, "config.conf")); len(binds) != 2 {
		t.Fatalf("got %+v", binds)
	}
}
