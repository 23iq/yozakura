package convert

import (
	"fmt"
	"net/url"
	"path/filepath"
	"time"
)

// Quality of a lossy target: "small", "balanced" (default) or "best".
type Quality string

const (
	QualitySmall    Quality = "small"
	QualityBalanced Quality = "balanced"
	QualityBest     Quality = "best"
)

// ParseQuality maps any other value to balanced.
func ParseQuality(s string) Quality {
	switch Quality(s) {
	case QualitySmall, QualityBest:
		return Quality(s)
	}
	return QualityBalanced
}

// pickQ returns the small / balanced / best value.
func pickQ[T any](q Quality, small, balanced, best T) T {
	switch q {
	case QualitySmall:
		return small
	case QualityBest:
		return best
	}
	return balanced
}

// Request is one conversion: the source file, its format and the target.
type Request struct {
	Src     string
	From    string
	To      string
	Quality Quality
}

// Step is one program run (or one native call) of a plan. Programs run
// inside the plan's work directory (Dir, else Plan.Work) and only ever see
// the neutral names below, never the user's file names: a name such as
// "photo%d.png" means a pattern to ImageMagick and ffmpeg.
type Step struct {
	Prog string
	Args []string
	// Dir overrides the working directory (pandoc reads a document's
	// images relative to the document's own folder).
	Dir string
	// Collect: the program writes its single output file into this
	// directory (relative to the work dir) under a name of its own
	// (LibreOffice, pdftoppm); the runner moves that file to Out.
	Collect string
	Out     string
	// Progress: ffmpeg reports -progress key=value lines on stdout.
	Progress bool
	// Timeout bounds the step (a password prompt or a stuck office).
	Timeout time.Duration
	Native  func() error
}

// Plan is everything a conversion runs, in order. Run first links the
// source into Work as Input; the last step leaves the result at Out.
type Plan struct {
	Engine Engine
	Steps  []Step
	Work   string
	Src    string
	Input  string
	Out    string
	// Duration of the source in seconds (ffmpeg progress), 0 = unknown.
	Duration float64
}

// PlanOptions: where LibreOffice keeps its profile (a private one, so a
// running LibreOffice never swallows the conversion); "" = inside work.
type PlanOptions struct {
	OfficeProfile string
}

// Work-directory names: the linked source, the result, intermediates.
const (
	outBase   = "out"
	officeOut = "office-out"
	pagesDir  = "pages"
	astRaw    = "doc.json"
	astSafe   = "doc-safe.json"
	midODT    = "mid.odt"
	mediaDir  = "media"
)

// Step timeouts per engine: generous for real work, finite for a hang.
var stepTimeouts = map[Engine]time.Duration{
	EngineFFmpeg:    12 * time.Hour,
	EngineMagick:    10 * time.Minute,
	EngineRsvg:      2 * time.Minute,
	EngineSoffice:   5 * time.Minute,
	EnginePandoc:    3 * time.Minute,
	EnginePdftoppm:  3 * time.Minute,
	EnginePdftotext: 3 * time.Minute,
}

// pandocContainers carry their own media inside the file (extracted into
// the work dir); every other pandoc source is text whose images and
// metadata point at other files (see SanitizeAST).
var pandocContainers = map[string]bool{"docx": true, "odt": true, "epub": true}

// BuildPlan builds the argv of req with the engine the table picks on this
// machine. work is an empty private directory; the result is written to
// work/out.<ext>.
func BuildPlan(req Request, t *Tools, work string, o PlanOptions) (*Plan, error) {
	tg, ok := Route(req.From, req.To, t)
	if !ok {
		return nil, fmt.Errorf("%s cannot be converted to %s", label(req.From), label(req.To))
	}
	if !tg.Available {
		return nil, fmt.Errorf("converting to %s needs %s", tg.Label, tg.Needs)
	}
	from, to := byID[req.From], byID[req.To]
	in := "in." + from.Ext()
	out := outBase + "." + to.Ext()
	p := &Plan{Engine: tg.Engine, Work: work, Src: req.Src, Input: in, Out: filepath.Join(work, out)}
	prog := t.Prog(tg.Engine)
	profile := o.OfficeProfile
	if profile == "" {
		profile = filepath.Join(work, "office-profile")
	}
	r := req
	r.Src = in
	timeout := stepTimeouts[tg.Engine]
	switch tg.Engine {
	case EngineFFmpeg:
		p.Steps = []Step{{Prog: prog, Args: ffmpegArgs(r, out), Progress: true, Out: out, Timeout: timeout}}
	case EngineMagick:
		p.Steps = []Step{{Prog: prog, Args: magickArgs(r, out), Out: out, Timeout: timeout}}
	case EngineRsvg:
		p.Steps = []Step{{Prog: prog, Args: []string{"-f", req.To, "-o", out, in}, Out: out, Timeout: timeout}}
	case EngineSoffice:
		p.Steps = []Step{sofficeStep(prog, profile, req.From, req.To, in, out)}
	case EnginePandoc:
		p.Steps = pandocSteps(t.Prog(EnginePandoc), req.From, req.To, in, out, req.Src, work)
	case EngineDocPDF:
		p.Steps = append(pandocSteps(t.Prog(EnginePandoc), req.From, "odt", in, midODT, req.Src, work),
			sofficeStep(t.Prog(EngineSoffice), profile, "odt", "pdf", midODT, out))
	case EnginePdftoppm:
		args := []string{"-png"}
		if req.To == "jpg" {
			args = []string{"-jpeg", "-jpegopt", "quality=" + pickQ(req.Quality, "60", "82", "92")}
		}
		args = append(args, "-r", "150", "-f", "1", "-l", "1", "-singlefile", in, pagesDir+"/page")
		p.Steps = []Step{{Prog: prog, Args: args, Collect: pagesDir, Out: out, Timeout: timeout}}
	case EnginePdftotext:
		p.Steps = []Step{{Prog: prog, Args: []string{"-layout", "-enc", "UTF-8", in, out}, Out: out, Timeout: timeout}}
	case EngineNative:
		src, dst, f, q := filepath.Join(work, in), p.Out, req.From, req.Quality
		p.Steps = []Step{{Out: out, Native: func() error { return ConvertNative(src, f, dst, req.To, q) }}}
	default:
		return nil, fmt.Errorf("no engine for %s to %s", label(req.From), label(req.To))
	}
	return p, nil
}

// pandocSteps: pandoc reads the document in its sandbox (nothing but the
// input; a container's own media is extracted into the work dir) into its
// document tree, SanitizeAST cleans it (images only from the document's
// own folder tree or its extracted media, no remote or absolute paths, no
// raw HTML that loads files, no metadata naming files), and the writer
// runs from that folder so relative images resolve there. The writer runs
// outside the sandbox: pandoc 3.1's sandbox also hides its own data files
// (the EPUB stylesheet).
func pandocSteps(prog, from, to, in, out, src, work string) []Step {
	timeout := stepTimeouts[EnginePandoc]
	read := []string{"--sandbox", "-f", pandocReaders[from], "-t", "json", "-o", astRaw}
	root := filepath.Dir(src)
	if pandocContainers[from] {
		read = append(read, "--extract-media="+mediaDir)
		root = work
	}
	rawPath, safePath := filepath.Join(work, astRaw), filepath.Join(work, astSafe)
	return []Step{
		{Prog: prog, Args: append(read, in), Out: astRaw, Timeout: timeout},
		{Out: astSafe, Native: func() error { return SanitizeAST(rawPath, safePath, root) }},
		{Prog: prog, Dir: root, Args: []string{"-f", "json", "-t", pandocWriters[to], "-s", "-o", filepath.Join(work, out), safePath},
			Out: out, Timeout: timeout},
	}
}

func label(id string) string {
	if f, ok := byID[id]; ok {
		return f.Label
	}
	return id
}

// ffmpegArgs: quiet except errors, progress on stdout, never reads stdin.
func ffmpegArgs(req Request, out string) []string {
	args := []string{"-hide_banner", "-nostdin", "-loglevel", "error", "-nostats", "-progress", "pipe:1", "-y", "-i", req.Src}
	q := req.Quality
	to := byID[req.To]
	switch {
	case to.Kind == KindAudio:
		args = append(args, "-vn", "-map_metadata", "0")
		args = append(args, audioCodec(req.To, q)...)
	case req.To == "gif":
		fps, width := pickQ(q, "10", "15", "20"), pickQ(q, "480", "640", "960")
		args = append(args, "-an", "-vf", "fps="+fps+",scale='min("+width+",iw)':-2:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse", "-loop", "0")
	case to.Kind == KindVideo:
		args = append(args, videoCodec(req.To, q)...)
	default: // a still image
		args = append(args, "-frames:v", "1", "-update", "1")
		switch req.To {
		case "jpg":
			args = append(args, "-q:v", pickQ(q, "8", "4", "2"))
		case "webp":
			args = append(args, "-quality", pickQ(q, "60", "80", "92"))
		}
	}
	return append(args, out)
}

func audioCodec(to string, q Quality) []string {
	switch to {
	case "mp3":
		return []string{"-c:a", "libmp3lame", "-b:a", pickQ(q, "128k", "192k", "320k")}
	case "wav":
		return []string{"-c:a", "pcm_s16le"}
	case "flac":
		return []string{"-c:a", "flac"}
	case "ogg":
		return []string{"-c:a", "libvorbis", "-q:a", pickQ(q, "3", "5", "8")}
	case "opus":
		return []string{"-c:a", "libopus", "-b:a", pickQ(q, "64k", "128k", "192k")}
	case "m4a":
		return []string{"-c:a", "aac", "-b:a", pickQ(q, "128k", "192k", "256k")}
	case "aac":
		return []string{"-c:a", "aac", "-b:a", pickQ(q, "128k", "192k", "256k"), "-f", "adts"}
	case "aiff":
		return []string{"-c:a", "pcm_s16be"}
	}
	return nil
}

// even: yuv420p needs even dimensions (a gif or a cropped phone video
// may have odd ones).
const even = "scale=trunc(iw/2)*2:trunc(ih/2)*2"

func videoCodec(to string, q Quality) []string {
	h264 := []string{"-c:v", "libx264", "-preset", "medium", "-crf", pickQ(q, "28", "23", "18"), "-pix_fmt", "yuv420p", "-vf", even,
		"-c:a", "aac", "-b:a", pickQ(q, "128k", "160k", "192k")}
	switch to {
	case "mp4", "mov":
		return append(h264, "-movflags", "+faststart")
	case "mkv":
		return h264
	case "webm":
		return []string{"-c:v", "libvpx-vp9", "-crf", pickQ(q, "40", "32", "24"), "-b:v", "0", "-row-mt", "1", "-deadline", "good", "-cpu-used", "4",
			"-pix_fmt", "yuv420p", "-c:a", "libopus", "-b:a", pickQ(q, "96k", "128k", "160k")}
	case "avi":
		return []string{"-c:v", "mpeg4", "-q:v", pickQ(q, "8", "5", "2"), "-c:a", "libmp3lame", "-q:a", "4"}
	}
	return nil
}

// magickArgs: the first frame unless the target keeps several (animated
// gif / webp, multi-page tiff / pdf); jpg and bmp get a white background
// instead of transparency.
func magickArgs(req Request, out string) []string {
	var args []string
	src := req.Src
	if req.From == "pdf" {
		args = append(args, "-density", "150")
	}
	if !contains([]string{"gif", "webp", "tiff", "pdf"}, req.To) {
		src += "[0]"
	}
	args = append(args, src)
	switch req.To {
	case "jpg", "bmp":
		args = append(args, "-background", "white", "-alpha", "remove", "-alpha", "off")
	case "ico":
		args = append(args, "-define", "icon:auto-resize=256,128,64,48,32,16")
	}
	switch req.To {
	case "jpg":
		args = append(args, "-quality", pickQ(req.Quality, "60", "82", "92"))
	case "webp":
		args = append(args, "-quality", pickQ(req.Quality, "60", "80", "92"))
	case "avif":
		args = append(args, "-quality", pickQ(req.Quality, "45", "60", "80"))
	case "jxl":
		args = append(args, "-quality", pickQ(req.Quality, "70", "85", "95"))
	}
	return append(args, out)
}

// officeFilters: LibreOffice's --convert-to value per target.
var officeFilters = map[string]string{
	"pdf":  "pdf",
	"docx": "docx:MS Word 2007 XML",
	"doc":  "doc:MS Word 97",
	"odt":  "odt",
	"rtf":  "rtf",
	"txt":  "txt:Text (encoded):UTF8",
	"html": "html",
	"xlsx": "xlsx:Calc MS Excel 2007 XML",
	"ods":  "ods",
	"csv":  "csv:Text - txt - csv (StarCalc):44,34,76,1",
	"pptx": "pptx:Impress MS PowerPoint 2007 XML",
	"odp":  "odp",
}

func sofficeStep(prog, profile, from, to, src, out string) Step {
	profileURL := url.URL{Scheme: "file", Path: profile}
	args := []string{"--headless", "--norestore", "--nolockcheck", "--nologo", "--nodefault",
		"-env:UserInstallation=" + profileURL.String()}
	if from == "pdf" {
		args = append(args, "--infilter=writer_pdf_import")
	}
	args = append(args, "--convert-to", officeFilters[to], "--outdir", officeOut, src)
	return Step{Prog: prog, Args: args, Collect: officeOut, Out: out, Timeout: stepTimeouts[EngineSoffice]}
}

// pandoc reader / writer names per format.
var (
	pandocReaders = map[string]string{"md": "markdown", "html": "html", "rst": "rst", "org": "org", "tex": "latex",
		"epub": "epub", "docx": "docx", "odt": "odt", "txt": "markdown"}
	pandocWriters = map[string]string{"md": "markdown", "html": "html5", "rst": "rst", "org": "org", "tex": "latex",
		"epub": "epub3", "docx": "docx", "odt": "odt", "txt": "plain"}
)
