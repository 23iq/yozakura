// Package convert is the file converter's pure core: the format registry,
// detection (extension first, a content sniff when it is missing or wrong),
// the valid targets of every source format with the engine that converts
// it, the smart default target, the argv of each engine and the native Go
// conversions (data formats, common raster images). It runs nothing by
// itself except through Run; the daemon service (pkg/svc/convert) and the
// CLI (`yozakura convert`) drive it.
package convert

import (
	"path/filepath"
	"sort"
	"strings"
)

// Kind groups formats the way the converter window shows them.
type Kind string

const (
	KindImage    Kind = "image"
	KindAudio    Kind = "audio"
	KindVideo    Kind = "video"
	KindDocument Kind = "document"
	KindEbook    Kind = "ebook"
	KindData     Kind = "data"
)

// Format is one file format the converter knows.
type Format struct {
	ID    string   `json:"id"`
	Label string   `json:"label"`
	Kind  Kind     `json:"kind"`
	Exts  []string `json:"exts"`
	// Lossy targets take the quality setting (small / balanced / best).
	Lossy bool `json:"lossy"`
	// ReadOnly formats are sources only (never offered as a target).
	ReadOnly bool `json:"readOnly,omitempty"`
}

// Ext is the extension written for this format ("jpg", "tiff").
func (f Format) Ext() string { return f.Exts[0] }

// formats is the registry, in the order the picker groups them.
var formats = []Format{
	// raster and vector images
	{ID: "png", Label: "PNG", Kind: KindImage, Exts: []string{"png"}},
	{ID: "jpg", Label: "JPEG", Kind: KindImage, Exts: []string{"jpg", "jpeg", "jpe", "jfif"}, Lossy: true},
	{ID: "webp", Label: "WebP", Kind: KindImage, Exts: []string{"webp"}, Lossy: true},
	{ID: "avif", Label: "AVIF", Kind: KindImage, Exts: []string{"avif"}, Lossy: true},
	{ID: "heic", Label: "HEIC", Kind: KindImage, Exts: []string{"heic", "heif"}, ReadOnly: true},
	{ID: "jxl", Label: "JPEG XL", Kind: KindImage, Exts: []string{"jxl"}, Lossy: true},
	{ID: "gif", Label: "GIF", Kind: KindImage, Exts: []string{"gif"}},
	{ID: "bmp", Label: "BMP", Kind: KindImage, Exts: []string{"bmp"}},
	{ID: "tiff", Label: "TIFF", Kind: KindImage, Exts: []string{"tiff", "tif"}},
	{ID: "ico", Label: "ICO", Kind: KindImage, Exts: []string{"ico"}},
	{ID: "tga", Label: "TGA", Kind: KindImage, Exts: []string{"tga"}},
	{ID: "psd", Label: "PSD", Kind: KindImage, Exts: []string{"psd"}, ReadOnly: true},
	{ID: "svg", Label: "SVG", Kind: KindImage, Exts: []string{"svg"}, ReadOnly: true},
	// audio
	{ID: "mp3", Label: "MP3", Kind: KindAudio, Exts: []string{"mp3"}, Lossy: true},
	{ID: "wav", Label: "WAV", Kind: KindAudio, Exts: []string{"wav"}},
	{ID: "flac", Label: "FLAC", Kind: KindAudio, Exts: []string{"flac"}},
	{ID: "ogg", Label: "Ogg Vorbis", Kind: KindAudio, Exts: []string{"ogg", "oga"}, Lossy: true},
	{ID: "opus", Label: "Opus", Kind: KindAudio, Exts: []string{"opus"}, Lossy: true},
	{ID: "m4a", Label: "M4A", Kind: KindAudio, Exts: []string{"m4a"}, Lossy: true},
	{ID: "aac", Label: "AAC", Kind: KindAudio, Exts: []string{"aac"}, Lossy: true},
	{ID: "aiff", Label: "AIFF", Kind: KindAudio, Exts: []string{"aiff", "aif"}},
	{ID: "wma", Label: "WMA", Kind: KindAudio, Exts: []string{"wma"}, ReadOnly: true},
	// video
	{ID: "mp4", Label: "MP4", Kind: KindVideo, Exts: []string{"mp4", "m4v"}, Lossy: true},
	{ID: "mkv", Label: "MKV", Kind: KindVideo, Exts: []string{"mkv"}, Lossy: true},
	{ID: "webm", Label: "WebM", Kind: KindVideo, Exts: []string{"webm"}, Lossy: true},
	{ID: "mov", Label: "MOV", Kind: KindVideo, Exts: []string{"mov"}, Lossy: true},
	{ID: "avi", Label: "AVI", Kind: KindVideo, Exts: []string{"avi"}, Lossy: true},
	{ID: "wmv", Label: "WMV", Kind: KindVideo, Exts: []string{"wmv"}, ReadOnly: true},
	{ID: "flv", Label: "FLV", Kind: KindVideo, Exts: []string{"flv"}, ReadOnly: true},
	{ID: "mpeg", Label: "MPEG", Kind: KindVideo, Exts: []string{"mpeg", "mpg"}, ReadOnly: true},
	{ID: "3gp", Label: "3GP", Kind: KindVideo, Exts: []string{"3gp"}, ReadOnly: true},
	// office documents
	{ID: "pdf", Label: "PDF", Kind: KindDocument, Exts: []string{"pdf"}},
	{ID: "docx", Label: "Word", Kind: KindDocument, Exts: []string{"docx"}},
	{ID: "doc", Label: "Word 97", Kind: KindDocument, Exts: []string{"doc"}},
	{ID: "odt", Label: "ODT", Kind: KindDocument, Exts: []string{"odt"}},
	{ID: "rtf", Label: "RTF", Kind: KindDocument, Exts: []string{"rtf"}},
	{ID: "txt", Label: "Text", Kind: KindDocument, Exts: []string{"txt", "text"}},
	{ID: "xlsx", Label: "Excel", Kind: KindDocument, Exts: []string{"xlsx"}},
	{ID: "xls", Label: "Excel 97", Kind: KindDocument, Exts: []string{"xls"}, ReadOnly: true},
	{ID: "ods", Label: "ODS", Kind: KindDocument, Exts: []string{"ods"}},
	{ID: "pptx", Label: "PowerPoint", Kind: KindDocument, Exts: []string{"pptx"}},
	{ID: "ppt", Label: "PowerPoint 97", Kind: KindDocument, Exts: []string{"ppt"}, ReadOnly: true},
	{ID: "odp", Label: "ODP", Kind: KindDocument, Exts: []string{"odp"}},
	// markup and ebooks
	{ID: "md", Label: "Markdown", Kind: KindEbook, Exts: []string{"md", "markdown"}},
	{ID: "html", Label: "HTML", Kind: KindEbook, Exts: []string{"html", "htm"}},
	{ID: "epub", Label: "EPUB", Kind: KindEbook, Exts: []string{"epub"}},
	{ID: "rst", Label: "reStructuredText", Kind: KindEbook, Exts: []string{"rst"}},
	{ID: "org", Label: "Org", Kind: KindEbook, Exts: []string{"org"}},
	{ID: "tex", Label: "LaTeX", Kind: KindEbook, Exts: []string{"tex"}},
	// data
	{ID: "json", Label: "JSON", Kind: KindData, Exts: []string{"json"}},
	{ID: "yaml", Label: "YAML", Kind: KindData, Exts: []string{"yaml", "yml"}},
	{ID: "toml", Label: "TOML", Kind: KindData, Exts: []string{"toml"}},
	{ID: "csv", Label: "CSV", Kind: KindData, Exts: []string{"csv"}},
}

var (
	byID  = map[string]Format{}
	byExt = map[string]Format{}
)

func init() {
	for _, f := range formats {
		byID[f.ID] = f
		for _, e := range f.Exts {
			byExt[e] = f
		}
	}
}

// Formats returns a copy of the registry.
func Formats() []Format { return append([]Format(nil), formats...) }

// Lookup returns the format with this id or extension ("jpeg" -> jpg).
func Lookup(id string) (Format, bool) {
	id = strings.ToLower(strings.TrimPrefix(strings.TrimSpace(id), "."))
	if f, ok := byID[id]; ok {
		return f, true
	}
	f, ok := byExt[id]
	return f, ok
}

// ByExtension returns the format of a path's extension.
func ByExtension(path string) (Format, bool) {
	ext := strings.TrimPrefix(strings.ToLower(filepath.Ext(path)), ".")
	if ext == "" {
		return Format{}, false
	}
	f, ok := byExt[ext]
	return f, ok
}

// IDs returns every format id, sorted (completion).
func IDs() []string {
	out := make([]string, 0, len(formats))
	for _, f := range formats {
		out = append(out, f.ID)
	}
	sort.Strings(out)
	return out
}
