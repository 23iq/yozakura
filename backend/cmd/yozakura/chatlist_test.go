package main

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func writeChat(t *testing.T, dir, name, body string, mtime time.Time) {
	t.Helper()
	p := filepath.Join(dir, name)
	if err := os.WriteFile(p, []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.Chtimes(p, mtime, mtime); err != nil {
		t.Fatal(err)
	}
}

func TestListChatsFormatsAndOrder(t *testing.T) {
	dir := t.TempDir()
	now := time.Now()
	writeChat(t, dir, "1.json", `[{"role":"user","content":"Привет, как настроить панель?"},{"role":"assistant","content":"Откройте настройки."}]`, now.Add(-time.Hour))
	writeChat(t, dir, "2.json", `{"version":2,"title":"Pinned one","pinned":true,"mode":"shell","model":"gpt","updated":1,"messages":[{"role":"user","content":"x"}]}`, now.Add(-2*time.Hour))
	writeChat(t, dir, "3.json", `{"version":2,"updated":9999999999999,"messages":[{"role":"user","content":"Newest question"}]}`, now)
	writeChat(t, dir, "bad.json", `{oops`, now)

	chats := listChats(dir)
	if len(chats) != 3 {
		t.Fatalf("want 3 chats, got %d", len(chats))
	}
	if chats[0].ID != "2" || !chats[0].Pinned || chats[0].Mode != "shell" {
		t.Fatalf("pinned chat must come first: %+v", chats[0])
	}
	if chats[1].ID != "3" || chats[1].Title != "Newest question" {
		t.Fatalf("newest unpinned second: %+v", chats[1])
	}
	if chats[2].Title != "Привет, как настроить панель?" || chats[2].Preview != "Откройте настройки." {
		t.Fatalf("v1 chat parsed wrong: %+v", chats[2])
	}
	if chats[2].Search == "" || chats[2].Count != 2 {
		t.Fatalf("search/count missing: %+v", chats[2])
	}
}

func TestTruncateRunesKeepsUTF8(t *testing.T) {
	got := truncateRunes("ééééé", 3)
	if got != "ééé…" {
		t.Fatalf("got %q", got)
	}
}
