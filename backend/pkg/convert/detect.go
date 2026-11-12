package convert

import (
	"archive/zip"
	"bytes"
	"encoding/json"
	"io"
	"os"
	"strings"
)

// sniffLen is how much of a file the content sniff reads.
const sniffLen = 4096

// Detect returns the format of a file: by content when the bytes identify
// a format the extension does not match (a PNG named .jpg), by extension
// otherwise, by content when there is no known extension. ok is false when
// neither tells.
func Detect(path string) (Format, bool) {
	byName, named := ByExtension(path)
	sniffed, ok := sniffFile(path)
	if ok && (!named || !compatible(byName.ID, sniffed.ID)) {
		return sniffed, true
	}
	if named {
		return byName, true
	}
	return Format{}, false
}

// compatible: an extension the sniff cannot tell apart from what it saw
// (containers sharing a signature, text formats) is trusted.
func compatible(named, sniffed string) bool {
	if named == sniffed {
		return true
	}
	groups := [][]string{
		{"mp4", "mov", "m4a", "3gp"}, // ISO base media
		{"mkv", "webm"},              // Matroska
		{"ogg", "opus"},              // Ogg
		{"mp3", "aac"},               // bare audio frames
		{"doc", "xls", "ppt"},        // OLE compound file
		{"txt", "md", "html", "rst", "org", "tex", "csv", "json", "yaml", "toml", "svg"}, // text
	}
	for _, g := range groups {
		if contains(g, named) && contains(g, sniffed) {
			return true
		}
	}
	return false
}

func sniffFile(path string) (Format, bool) {
	f, err := os.Open(path)
	if err != nil {
		return Format{}, false
	}
	defer f.Close()
	head := make([]byte, sniffLen)
	n, _ := io.ReadFull(f, head)
	head = head[:n]
	id := Sniff(head)
	if id == "zip" {
		id = sniffZip(path)
	}
	if fm, ok := byID[id]; ok {
		return fm, true
	}
	return Format{}, false
}

// Sniff names the format of a file's first bytes ("" when unknown; "zip"
// for a zip container whose entries tell the rest).
func Sniff(b []byte) string {
	has := func(off int, sig string) bool {
		return len(b) >= off+len(sig) && string(b[off:off+len(sig)]) == sig
	}
	switch {
	case has(0, "\x89PNG\r\n\x1a\n"):
		return "png"
	case has(0, "\xff\xd8\xff"):
		return "jpg"
	case has(0, "GIF87a"), has(0, "GIF89a"):
		return "gif"
	case has(0, "RIFF") && has(8, "WEBP"):
		return "webp"
	case has(0, "RIFF") && has(8, "WAVE"):
		return "wav"
	case has(0, "RIFF") && has(8, "AVI "):
		return "avi"
	case has(0, "BM") && len(b) > 18 && has(6, "\x00\x00\x00\x00") && contains([]string{"\x0c", "\x28", "\x34", "\x38", "\x6c", "\x7c"}, string(b[14:15])):
		return "bmp"
	case has(0, "II*\x00"), has(0, "MM\x00*"):
		return "tiff"
	case has(0, "\x00\x00\x01\x00") && len(b) > 6:
		return "ico"
	case has(0, "\xff\x0a"), has(4, "JXL \r\n\x87\n"):
		return "jxl"
	case has(0, "8BPS"):
		return "psd"
	case has(4, "ftyp"):
		return sniffFtyp(b)
	case has(0, "%PDF-"):
		return "pdf"
	case has(0, "fLaC"):
		return "flac"
	case has(0, "OggS"):
		if bytes.Contains(b, []byte("OpusHead")) {
			return "opus"
		}
		return "ogg"
	case has(0, "ID3"):
		return "mp3"
	case has(0, "FORM") && (has(8, "AIFF") || has(8, "AIFC")):
		return "aiff"
	case has(0, "\x1a\x45\xdf\xa3"):
		if bytes.Contains(b, []byte("webm")) {
			return "webm"
		}
		return "mkv"
	case has(0, "FLV"):
		return "flv"
	case has(0, "\x30\x26\xb2\x75\x8e\x66\xcf\x11"):
		return "wma"
	case has(0, "\x00\x00\x01\xba"), has(0, "\x00\x00\x01\xb3"):
		return "mpeg"
	case has(0, "{\\rtf"):
		return "rtf"
	case has(0, "PK\x03\x04"):
		return "zip"
	case has(0, "\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1"):
		return "doc"
	case len(b) >= 2 && b[0] == 0xff && (b[1]&0xf6) == 0xf0:
		return "aac" // ADTS
	case len(b) >= 2 && b[0] == 0xff && (b[1]&0xe0) == 0xe0:
		return "mp3" // MPEG audio frame
	}
	return sniffText(b)
}

func sniffFtyp(b []byte) string {
	if len(b) < 12 {
		return ""
	}
	brand := string(b[8:12])
	switch brand {
	case "heic", "heix", "hevc", "heim", "heis", "mif1", "msf1":
		return "heic"
	case "avif", "avis":
		return "avif"
	case "qt  ":
		return "mov"
	case "M4A ", "M4B ":
		return "m4a"
	case "3gp4", "3gp5", "3gp6", "3g2a":
		return "3gp"
	}
	return "mp4"
}

// sniffZip tells the zip based formats apart by their entries.
func sniffZip(path string) string {
	r, err := zip.OpenReader(path)
	if err != nil {
		return ""
	}
	defer r.Close()
	for _, f := range r.File {
		if f.Name != "mimetype" {
			continue
		}
		rc, err := f.Open()
		if err != nil {
			break
		}
		mt, _ := io.ReadAll(io.LimitReader(rc, 128))
		rc.Close()
		switch strings.TrimSpace(string(mt)) {
		case "application/epub+zip":
			return "epub"
		case "application/vnd.oasis.opendocument.text":
			return "odt"
		case "application/vnd.oasis.opendocument.spreadsheet":
			return "ods"
		case "application/vnd.oasis.opendocument.presentation":
			return "odp"
		}
	}
	for _, f := range r.File {
		switch {
		case strings.HasPrefix(f.Name, "word/"):
			return "docx"
		case strings.HasPrefix(f.Name, "xl/"):
			return "xlsx"
		case strings.HasPrefix(f.Name, "ppt/"):
			return "pptx"
		}
	}
	return ""
}

// sniffText recognises the text formats a missing extension can hide:
// svg, html, json, an rtf-less plain text.
func sniffText(b []byte) string {
	if len(b) == 0 || !isText(b) {
		return ""
	}
	s := strings.TrimSpace(strings.TrimPrefix(string(b), "\ufeff"))
	low := strings.ToLower(s)
	switch {
	case strings.HasPrefix(low, "<svg"), strings.HasPrefix(low, "<?xml") && strings.Contains(low, "<svg"):
		return "svg"
	case strings.HasPrefix(low, "<!doctype html"), strings.HasPrefix(low, "<html"):
		return "html"
	case (strings.HasPrefix(s, "{") || strings.HasPrefix(s, "[")) && json.Valid([]byte(s)):
		return "json"
	}
	return "txt"
}

func isText(b []byte) bool {
	if bytes.IndexByte(b, 0) >= 0 {
		return false
	}
	ctrl := 0
	for _, c := range b {
		if c < 0x20 && c != '\n' && c != '\r' && c != '\t' && c != '\f' {
			ctrl++
		}
	}
	return ctrl*20 < len(b)+1
}
