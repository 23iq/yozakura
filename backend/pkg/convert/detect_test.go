package convert

import (
	"archive/zip"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func write(t *testing.T, dir, name string, data []byte) string {
	t.Helper()
	p := filepath.Join(dir, name)
	if err := os.WriteFile(p, data, 0o644); err != nil {
		t.Fatal(err)
	}
	return p
}

func TestSniff(t *testing.T) {
	cases := map[string]string{
		"\x89PNG\r\n\x1a\n....":               "png",
		"\xff\xd8\xff\xe0..JFIF":              "jpg",
		"GIF89a....":                          "gif",
		"RIFF\x00\x00\x00\x00WEBPVP8 ":        "webp",
		"RIFF\x00\x00\x00\x00WAVEfmt ":        "wav",
		"\x00\x00\x00\x18ftypheic\x00\x00":    "heic",
		"\x00\x00\x00\x18ftypavif\x00\x00":    "avif",
		"\x00\x00\x00\x18ftypisom\x00\x00":    "mp4",
		"\x00\x00\x00\x14ftypqt  \x00\x00":    "mov",
		"\x00\x00\x00\x18ftypM4A \x00\x00":    "m4a",
		"%PDF-1.7\n":                          "pdf",
		"fLaC\x00\x00":                        "flac",
		"OggS\x00\x02....OpusHead":            "opus",
		"OggS\x00\x02....\x01vorbis":          "ogg",
		"ID3\x04\x00":                         "mp3",
		"\x1a\x45\xdf\xa3....webm":            "webm",
		"\x1a\x45\xdf\xa3....matroska":        "mkv",
		"{\\rtf1\\ansi":                       "rtf",
		"PK\x03\x04":                          "zip",
		"<?xml version=\"1.0\"?>\n<svg xmlns": "svg",
		"<!DOCTYPE html><html>":               "html",
		"{\"a\": [1, 2]}":                     "json",
		"just some words\n":                   "txt",
		"BMW is a car brand, not a bitmap":    "txt",
	}
	for in, want := range cases {
		if got := Sniff([]byte(in)); got != want {
			t.Errorf("%q: %q, want %q", in, got, want)
		}
	}
}

func TestDetectExtensionAndContent(t *testing.T) {
	dir := t.TempDir()
	png := "\x89PNG\r\n\x1a\n\x00\x00\x00\x0dIHDR"
	// right extension
	if f, _ := Detect(write(t, dir, "a.png", []byte(png))); f.ID != "png" {
		t.Errorf("a.png: %s", f.ID)
	}
	// wrong extension: the content wins
	if f, _ := Detect(write(t, dir, "b.jpg", []byte(png))); f.ID != "png" {
		t.Errorf("png named .jpg: %s", f.ID)
	}
	// no extension
	if f, _ := Detect(write(t, dir, "c", []byte(png))); f.ID != "png" {
		t.Errorf("no extension: %s", f.ID)
	}
	// text formats trust their extension
	if f, _ := Detect(write(t, dir, "d.md", []byte("# title\n"))); f.ID != "md" {
		t.Errorf("md: %s", f.ID)
	}
	if f, _ := Detect(write(t, dir, "e.yaml", []byte("{\"a\":1}"))); f.ID != "yaml" {
		t.Errorf("json-looking yaml: %s", f.ID)
	}
	// unknown
	if _, ok := Detect(write(t, dir, "f.xyz", []byte{0, 1, 2, 3, 0, 9})); ok {
		t.Errorf("binary junk detected")
	}
	// zip containers by their entries
	docx := filepath.Join(dir, "g")
	zf, _ := os.Create(docx)
	zw := zip.NewWriter(zf)
	w, _ := zw.Create("word/document.xml")
	_, _ = w.Write([]byte("<w/>"))
	zw.Close()
	zf.Close()
	if f, _ := Detect(docx); f.ID != "docx" {
		t.Errorf("docx without extension: %s", f.ID)
	}
	epub := filepath.Join(dir, "h.zip")
	zf, _ = os.Create(epub)
	zw = zip.NewWriter(zf)
	w, _ = zw.Create("mimetype")
	_, _ = w.Write([]byte("application/epub+zip"))
	zw.Close()
	zf.Close()
	if f, _ := Detect(epub); f.ID != "epub" {
		t.Errorf("epub: %s", f.ID)
	}
}

func TestLookup(t *testing.T) {
	for in, want := range map[string]string{"jpeg": "jpg", ".JPG": "jpg", "tif": "tiff", "yml": "yaml", "mp4": "mp4"} {
		if f, ok := Lookup(in); !ok || f.ID != want {
			t.Errorf("%s: %v", in, f.ID)
		}
	}
	if _, ok := Lookup("nope"); ok {
		t.Error("nope found")
	}
}

func TestReserveNeverOverwrites(t *testing.T) {
	dir := t.TempDir()
	src := write(t, dir, "photo.jpg", []byte("x"))
	write(t, dir, "photo.png", []byte("keep"))
	p1, err := Reserve(src, "png", "")
	if err != nil || filepath.Base(p1) != "photo (1).png" {
		t.Fatalf("first: %s %v", p1, err)
	}
	p2, _ := Reserve(src, "png", "")
	if filepath.Base(p2) != "photo (2).png" {
		t.Fatalf("second: %s", p2)
	}
	if b, _ := os.ReadFile(filepath.Join(dir, "photo.png")); string(b) != "keep" {
		t.Fatal("existing file touched")
	}
	out := t.TempDir()
	p3, _ := Reserve(src, "webp", out)
	if p3 != filepath.Join(out, "photo.webp") {
		t.Fatalf("out dir: %s", p3)
	}
	if _, err := Reserve(src, "png", filepath.Join(dir, "missing")); err == nil || !strings.Contains(err.Error(), "cannot write") {
		t.Fatalf("missing dir: %v", err)
	}
	if OutputName("/x/archive.tar.gz", "zip") != "archive.tar.zip" || OutputName("/x/README", "pdf") != "README.pdf" ||
		OutputName("/x/.hidden", "json") != ".hidden.json" {
		t.Fatal("output names")
	}
}
