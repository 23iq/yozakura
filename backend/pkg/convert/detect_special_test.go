package convert

import (
	"os"
	"path/filepath"
	"syscall"
	"testing"
	"time"
)

// A FIFO (or any non-regular file) is never opened for reading: detection
// returns at once instead of blocking on it.
func TestDetectRefusesSpecialFiles(t *testing.T) {
	dir := t.TempDir()
	fifo := filepath.Join(dir, "pipe.png")
	if err := syscall.Mkfifo(fifo, 0o644); err != nil {
		t.Skip("mkfifo:", err)
	}
	link := filepath.Join(dir, "link.jpg")
	_ = os.Symlink(fifo, link)
	done := make(chan bool, 1)
	go func() {
		_, ok1 := Detect(fifo)
		_, ok2 := Detect(link)
		_, ok3 := Detect(dir)
		_, ok4 := Detect("/dev/null")
		done <- ok1 || ok2 || ok3 || ok4
	}()
	select {
	case any := <-done:
		if any {
			t.Fatal("a special file was detected as convertible")
		}
	case <-time.After(5 * time.Second):
		t.Fatal("detection blocked on a FIFO")
	}
	if IsRegular(fifo) || IsRegular(dir) || !IsRegular(write(t, dir, "a.txt", []byte("x"))) {
		t.Fatal("IsRegular")
	}
	// a symlink to a regular file is fine
	real := write(t, dir, "real.png", []byte("\x89PNG\r\n\x1a\nxxxx"))
	sl := filepath.Join(dir, "sl.png")
	_ = os.Symlink(real, sl)
	if f, ok := Detect(sl); !ok || f.ID != "png" {
		t.Fatalf("symlink to png: %v %v", f.ID, ok)
	}
}

// Text with a byte order mark is text, and weak content guesses never
// override the extension.
func TestDetectTextBOMsAndWeakSniffs(t *testing.T) {
	dir := t.TempDir()
	utf16 := []byte("\xff\xfea\x00,\x00b\x00\n\x001\x00,\x002\x00\n\x00")
	for name, want := range map[string]string{"table.csv": "csv", "notes.txt": "txt", "page.md": "md"} {
		if f, _ := Detect(write(t, dir, name, utf16)); f.ID != want {
			t.Errorf("UTF-16 %s detected as %s", name, f.ID)
		}
	}
	if f, _ := Detect(write(t, dir, "bom.json", []byte("\xef\xbb\xbf{\"a\":1}"))); f.ID != "json" {
		t.Errorf("UTF-8 BOM json: %s", f.ID)
	}
	// an MPEG frame sync look-alike in a .wav stays wav
	if f, _ := Detect(write(t, dir, "x.wav", []byte("\xff\xfb\x90\x00junk"))); f.ID != "wav" {
		t.Errorf("weak mp3 sniff overrode .wav: %s", f.ID)
	}
	// without an extension the weak guess is still used
	if f, _ := Detect(write(t, dir, "noext", []byte("ID3\x04\x00"))); f.ID != "mp3" {
		t.Errorf("ID3 without extension: %s", f.ID)
	}
	// a strong sniff still corrects a wrong extension
	if f, _ := Detect(write(t, dir, "photo.mp3", []byte("\x89PNG\r\n\x1a\nxxxx"))); f.ID != "png" {
		t.Errorf("png named .mp3: %s", f.ID)
	}
}
