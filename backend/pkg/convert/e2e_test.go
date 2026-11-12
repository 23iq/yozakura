package convert

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"yozakura/backend/pkg/proc"
)

// End to end: real conversions with the engines installed here. Each case
// is skipped when its engine is missing; inputs are made by the test.

var realTools = DetectTools(nil)

func need(t *testing.T, e ...Engine) {
	t.Helper()
	for _, x := range e {
		if !realTools.Has(x) {
			t.Skipf("%s not installed", ToolName(x))
		}
	}
}

// convertFile runs a full conversion of src into a fresh work dir and
// returns the result path and its detected format.
func convertFile(t *testing.T, src, to string) string {
	t.Helper()
	from, ok := Detect(src)
	if !ok {
		t.Fatalf("cannot detect %s", src)
	}
	work := t.TempDir()
	p, err := BuildPlan(Request{Src: src, From: from.ID, To: to, Quality: QualitySmall}, realTools, work, PlanOptions{})
	if err != nil {
		t.Fatalf("%s->%s: %v", from.ID, to, err)
	}
	p.Duration = realTools.ProbeDuration(context.Background(), src)
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Minute)
	defer cancel()
	var last float64 = -2
	if err := p.Run(ctx, func(f float64) { last = f }); err != nil {
		t.Fatalf("%s->%s (%s): %v", from.ID, to, p.Engine, err)
	}
	if p.Engine == EngineFFmpeg && p.Duration > 0 && last < 0.99 {
		t.Errorf("%s->%s: progress ended at %v", from.ID, to, last)
	}
	got, ok := Detect(p.Out)
	if !ok {
		t.Fatalf("%s->%s: result not recognised", from.ID, to)
	}
	return got.ID
}

func ffmake(t *testing.T, dir, name string, args ...string) string {
	t.Helper()
	out := filepath.Join(dir, name)
	all := append([]string{"-hide_banner", "-loglevel", "error", "-nostdin", "-y"}, args...)
	if _, err := proc.Run(context.Background(), realTools.Prog(EngineFFmpeg), append(all, out)...); err != nil {
		t.Fatalf("making %s: %v", name, err)
	}
	return out
}

func TestE2EAudioVideo(t *testing.T) {
	need(t, EngineFFmpeg)
	dir := t.TempDir()
	wav := ffmake(t, dir, "tone.wav", "-f", "lavfi", "-i", "sine=frequency=440:duration=1")
	for to, want := range map[string]string{"mp3": "mp3", "flac": "flac", "ogg": "ogg", "opus": "opus"} {
		if got := convertFile(t, wav, to); got != want {
			t.Errorf("wav->%s gave %s", to, got)
		}
	}
	mp4 := ffmake(t, dir, "clip.mp4", "-f", "lavfi", "-i", "testsrc=size=64x48:rate=10:duration=1",
		"-f", "lavfi", "-i", "sine=duration=1", "-shortest", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "aac")
	for to, want := range map[string]string{"gif": "gif", "mp3": "mp3", "webm": "webm", "mkv": "mkv"} {
		if got := convertFile(t, mp4, to); got != want {
			t.Errorf("mp4->%s gave %s", to, got)
		}
	}
}

func TestE2EImages(t *testing.T) {
	need(t, EngineMagick)
	dir := t.TempDir()
	png := filepath.Join(dir, "pic.png")
	if _, err := proc.Run(context.Background(), realTools.Prog(EngineMagick), "-size", "32x24", "gradient:red-blue", png); err != nil {
		t.Fatal(err)
	}
	for _, to := range []string{"jpg", "webp", "gif", "bmp", "tiff", "ico", "pdf"} {
		tg, _ := Route("png", to, realTools)
		if !tg.Available {
			continue // a delegate this ImageMagick lacks
		}
		if got := convertFile(t, png, to); got != to {
			t.Errorf("png->%s gave %s", to, got)
		}
	}
	svg := write(t, dir, "logo.svg", []byte(`<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20"><circle cx="10" cy="10" r="8" fill="red"/></svg>`))
	if tg, _ := Route("svg", "png", realTools); !tg.Available {
		t.Logf("svg->png skipped: needs %s", tg.Needs)
	} else if got := convertFile(t, svg, "png"); got != "png" {
		t.Errorf("svg->png gave %s", got)
	}
}

func TestE2EDocuments(t *testing.T) {
	need(t, EnginePandoc)
	dir := t.TempDir()
	md := write(t, dir, "notes.md", []byte("# Title\n\nSome *text*.\n"))
	for _, to := range []string{"html", "docx", "odt", "epub"} {
		if got := convertFile(t, md, to); got != to && !(to == "html" && got == "html") {
			t.Errorf("md->%s gave %s", to, got)
		}
	}
	html := convertFile(t, md, "html")
	_ = html
	if testing.Short() || !realTools.Has(EngineSoffice) {
		return
	}
	if got := convertFile(t, md, "pdf"); got != "pdf" {
		t.Errorf("md->pdf gave %s", got)
	}
	txt := write(t, dir, "plain.txt", []byte("hello\n"))
	docx := filepath.Join(dir, "plain.docx")
	if got := convertFile(t, txt, "docx"); got != "docx" {
		t.Errorf("txt->docx gave %s", got)
	}
	// a docx made by pandoc, printed by LibreOffice, read back by poppler
	if _, err := proc.Run(context.Background(), realTools.Prog(EnginePandoc), "-o", docx, md); err != nil {
		t.Fatal(err)
	}
	if got := convertFile(t, docx, "pdf"); got != "pdf" {
		t.Errorf("docx->pdf gave %s", got)
	}
	csv := write(t, dir, "table.csv", []byte("a,b\n1,2\n"))
	if got := convertFile(t, csv, "xlsx"); got != "xlsx" {
		t.Errorf("csv->xlsx gave %s", got)
	}
	pdf := filepath.Join(dir, "doc.pdf")
	work := t.TempDir()
	p, _ := BuildPlan(Request{Src: docx, From: "docx", To: "pdf"}, realTools, work, PlanOptions{})
	if err := p.Run(context.Background(), nil); err != nil {
		t.Fatal(err)
	}
	if err := os.Rename(p.Out, pdf); err != nil {
		t.Fatal(err)
	}
	for _, to := range []string{"txt", "png"} {
		if tg, _ := Route("pdf", to, realTools); tg.Available {
			if got := convertFile(t, pdf, to); got != to {
				t.Errorf("pdf->%s gave %s", to, got)
			}
		}
	}
}

func TestE2EFailureMessage(t *testing.T) {
	need(t, EngineFFmpeg)
	dir := t.TempDir()
	bad := write(t, dir, "broken.mp3", append([]byte("ID3\x04\x00\x00\x00\x00\x00\x00"), []byte(strings.Repeat("garbage", 50))...))
	p, err := BuildPlan(Request{Src: bad, From: "mp3", To: "wav"}, realTools, t.TempDir(), PlanOptions{})
	if err != nil {
		t.Fatal(err)
	}
	err = p.Run(context.Background(), nil)
	if err == nil {
		t.Fatal("garbage converted")
	}
	if strings.Contains(err.Error(), "\n") || len(err.Error()) > 200 {
		t.Fatalf("message is a dump: %q", err)
	}
}

func TestE2ECancel(t *testing.T) {
	need(t, EngineFFmpeg)
	dir := t.TempDir()
	wav := ffmake(t, dir, "long.wav", "-f", "lavfi", "-i", "sine=duration=600")
	p, _ := BuildPlan(Request{Src: wav, From: "wav", To: "flac"}, realTools, t.TempDir(), PlanOptions{})
	ctx, cancel := context.WithCancel(context.Background())
	go func() { time.Sleep(100 * time.Millisecond); cancel() }()
	start := time.Now()
	err := p.Run(ctx, nil)
	if err == nil || time.Since(start) > 10*time.Second {
		t.Fatalf("cancel: %v after %s", err, time.Since(start))
	}
	_ = os.Remove(wav)
}
