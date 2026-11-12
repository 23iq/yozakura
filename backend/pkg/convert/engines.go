package convert

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
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
	// pandoc is installed but older than 2.15 (no --sandbox): not used
	pandocOld bool
	// what a real ImageMagick run showed for PDF (policy, Ghostscript)
	magickPDF *pdfAbility
}

type pdfAbility struct{ read, write bool }

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
		t.magickPDF = probeMagickPDF(m)
	}
	if p := t.progs[EnginePandoc]; p != "" {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		out, err := proc.Run(ctx, p, "--version")
		cancel()
		if err != nil || !PandocHasSandbox(string(out)) {
			delete(t.progs, EnginePandoc)
			t.pandocOld = true
		}
	}
	return t
}

// PandocHasSandbox reads `pandoc --version`: --sandbox exists from 2.15 on.
func PandocHasSandbox(version string) bool {
	f := strings.Fields(version)
	if len(f) < 2 {
		return false
	}
	var major, minor int
	if _, err := fmt.Sscanf(f[1], "%d.%d", &major, &minor); err != nil {
		return false
	}
	return major > 2 || (major == 2 && minor >= 15)
}

// probeMagickPDF writes and reads back a one-pixel PDF: a security policy
// or a missing Ghostscript makes ImageMagick list PDF yet fail on it.
func probeMagickPDF(prog string) *pdfAbility {
	dir, err := os.MkdirTemp("", "convert-probe-")
	if err != nil {
		return nil
	}
	defer os.RemoveAll(dir)
	pdf, png := filepath.Join(dir, "p.pdf"), filepath.Join(dir, "p.png")
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	a := &pdfAbility{}
	if _, err := proc.Run(ctx, prog, "-size", "1x1", "xc:white", pdf); err == nil {
		if st, err := os.Stat(pdf); err == nil && st.Size() > 0 {
			a.write = true
			if _, err := proc.Run(ctx, prog, pdf+"[0]", png); err == nil {
				if st, err := os.Stat(png); err == nil && st.Size() > 0 {
					a.read = true
				}
			}
		}
	}
	return a
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

// missing names what an unavailable engine still needs: for the two-step
// markup to PDF only the tool that is not installed.
func (t *Tools) missing(e Engine) string {
	if t != nil && t.pandocOld && (e == EnginePandoc || (e == EngineDocPDF && !t.Has(EnginePandoc))) {
		return "pandoc 2.15 or newer"
	}
	if e == EngineDocPDF {
		switch {
		case t.Has(EnginePandoc) && !t.Has(EngineSoffice):
			return ToolName(EngineSoffice)
		case !t.Has(EnginePandoc) && t.Has(EngineSoffice):
			return ToolName(EnginePandoc)
		}
	}
	return ToolName(e)
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
		if len(f) < 2 {
			continue
		}
		// "WEBP* WEBP rw+ ...", and in ImageMagick 6 "HEIC  r-- ..." with
		// an empty module column: the mode is the first field shaped like one
		name := strings.TrimRight(f[0], "*")
		for _, mode := range f[1:3] {
			if isMode(mode) {
				m[strings.ToUpper(name)] = mode
				break
			}
		}
	}
	return m
}

func isMode(s string) bool {
	return len(s) == 3 && strings.ContainsRune("r-", rune(s[0])) && strings.ContainsRune("w-", rune(s[1])) &&
		strings.ContainsRune("+-", rune(s[2]))
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
		if t.magickPDF != nil && ((from == "pdf" && !t.magickPDF.read) || (to == "pdf" && !t.magickPDF.write)) {
			return false
		}
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
