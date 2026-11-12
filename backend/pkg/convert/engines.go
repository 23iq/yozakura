package convert

import (
	"context"
	"os/exec"
	"strings"
	"time"

	"yozakura/backend/pkg/proc"
)

// Engine is a converter backend: an external tool found at runtime with
// exec.LookPath, or native Go.
type Engine string

const (
	EngineFFmpeg  Engine = "ffmpeg"
	EngineMagick  Engine = "magick"
	EngineRsvg    Engine = "rsvg"
	EngineSoffice Engine = "soffice"
	EnginePandoc  Engine = "pandoc"
	// EngineDocPDF renders markup to PDF in two steps: pandoc writes an
	// ODT, LibreOffice prints it (no LaTeX needed).
	EngineDocPDF    Engine = "pandoc+soffice"
	EnginePdftoppm  Engine = "pdftoppm"
	EnginePdftotext Engine = "pdftotext"
	EngineNative    Engine = "native"
)

// engineInfo: the programs an engine looks for (first found wins) and the
// tool name shown as "needs <tool>" while it is missing.
var engineInfo = map[Engine]struct {
	progs []string
	tool  string
}{
	EngineFFmpeg:    {[]string{"ffmpeg"}, "ffmpeg"},
	EngineMagick:    {[]string{"magick", "convert"}, "ImageMagick"},
	EngineRsvg:      {[]string{"rsvg-convert"}, "librsvg"},
	EngineSoffice:   {[]string{"soffice", "libreoffice"}, "LibreOffice"},
	EnginePandoc:    {[]string{"pandoc"}, "pandoc"},
	EnginePdftoppm:  {[]string{"pdftoppm"}, "poppler"},
	EnginePdftotext: {[]string{"pdftotext"}, "poppler"},
}

// ToolName is the user-facing name of what enables an engine.
func ToolName(e Engine) string {
	if e == EngineDocPDF {
		return "pandoc + LibreOffice"
	}
	if i, ok := engineInfo[e]; ok {
		return i.tool
	}
	return string(e)
}

// Tools is the set of engines found on this machine.
type Tools struct {
	progs map[Engine]string
	// magick: format name (upper case) -> mode ("rw+", "r--"); nil when
	// the list could not be read (every format is then assumed).
	magickFormats map[string]string
	// ffprobe for media durations ("" = progress is indeterminate)
	ffprobe string
}

// LookFunc resolves a program name like exec.LookPath.
type LookFunc func(string) (string, error)

// DetectTools looks every engine up with look (exec.LookPath when nil) and
// reads ImageMagick's format list once.
func DetectTools(look LookFunc) *Tools {
	if look == nil {
		look = exec.LookPath
	}
	t := &Tools{progs: map[Engine]string{}}
	for e, info := range engineInfo {
		for _, p := range info.progs {
			if path, err := look(p); err == nil {
				t.progs[e] = path
				break
			}
		}
	}
	if p, err := look("ffprobe"); err == nil {
		t.ffprobe = p
	}
	if m := t.progs[EngineMagick]; m != "" {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		out, err := proc.Run(ctx, m, "-list", "format")
		cancel()
		if err == nil {
			t.magickFormats = parseMagickFormats(string(out))
		}
	}
	return t
}

// NewTools builds a Tools from a fixed engine -> program map (tests, and
// callers that know what is installed).
func NewTools(progs map[Engine]string, magickFormats map[string]string) *Tools {
	t := &Tools{progs: map[Engine]string{}, magickFormats: magickFormats}
	for k, v := range progs {
		t.progs[k] = v
	}
	return t
}

// Prog returns the program of an engine ("" when missing).
func (t *Tools) Prog(e Engine) string {
	if t == nil {
		return ""
	}
	return t.progs[e]
}

// Has reports whether the engine can run here.
func (t *Tools) Has(e Engine) bool {
	switch e {
	case EngineNative:
		return true
	case EngineDocPDF:
		return t.Prog(EnginePandoc) != "" && t.Prog(EngineSoffice) != ""
	}
	return t.Prog(e) != ""
}

// Installed lists the engines found (for `convert formats`).
func (t *Tools) Installed() []Engine {
	var out []Engine
	for _, e := range []Engine{EngineFFmpeg, EngineMagick, EngineRsvg, EngineSoffice, EnginePandoc, EnginePdftoppm, EnginePdftotext} {
		if t.Has(e) {
			out = append(out, e)
		}
	}
	return out
}

// magickName maps a format id to ImageMagick's coder name.
func magickName(id string) string {
	switch id {
	case "jpg":
		return "JPEG"
	case "tiff":
		return "TIFF"
	case "heic":
		return "HEIC"
	}
	return strings.ToUpper(id)
}

// magickCan reports whether ImageMagick reads (write=false) or writes the
// format. An unreadable list assumes yes (the conversion then reports).
func (t *Tools) magickCan(id string, write bool) bool {
	if t.magickFormats == nil {
		return true
	}
	mode, ok := t.magickFormats[magickName(id)]
	if !ok {
		return false
	}
	if write {
		return len(mode) > 1 && mode[1] == 'w'
	}
	return len(mode) > 0 && mode[0] == 'r'
}

// parseMagickFormats reads `magick -list format` lines such as
// "     WEBP* WEBP      rw+   WebP Image Format (libwebp 1.4.0)".
func parseMagickFormats(out string) map[string]string {
	m := map[string]string{}
	for _, line := range strings.Split(out, "\n") {
		f := strings.Fields(line)
		if len(f) < 3 {
			continue
		}
		name := strings.TrimRight(f[0], "*")
		mode := f[2]
		if len(mode) != 3 || !strings.ContainsAny(mode[:1], "r-") || !strings.ContainsAny(mode[1:2], "w-") {
			continue
		}
		m[strings.ToUpper(name)] = mode
	}
	return m
}

// engineReads / engineWrites: the formats an image engine handles beyond
// "any" (native Go and ffmpeg's image codecs). Other engines are chosen by
// the route table alone.
var (
	nativeReads  = set("png", "jpg", "gif", "bmp", "tiff", "webp")
	nativeWrites = set("png", "jpg", "gif", "bmp", "tiff")
	ffImgReads   = set("png", "jpg", "webp", "bmp", "tiff", "gif", "tga", "avif", "jxl")
	ffImgWrites  = set("png", "jpg", "webp", "bmp", "tiff", "gif", "tga", "avif")
)

func set(ids ...string) map[string]bool {
	m := map[string]bool{}
	for _, id := range ids {
		m[id] = true
	}
	return m
}

// supports reports whether engine e can convert from -> to on this machine,
// apart from being installed.
func (t *Tools) supports(e Engine, from, to string) bool {
	switch e {
	case EngineMagick:
		return t.magickCan(from, false) && (to == "pdf" || t.magickCan(to, true))
	case EngineNative:
		if byID[from].Kind == KindData {
			return true
		}
		return nativeReads[from] && nativeWrites[to]
	case EngineFFmpeg:
		if byID[from].Kind == KindImage && byID[to].Kind == KindImage {
			return ffImgReads[from] && ffImgWrites[to]
		}
	}
	return true
}
