package convert

import (
	"slices"
	"strings"
	"testing"
)

func plan(t *testing.T, from, to string, q Quality) *Plan {
	t.Helper()
	p, err := BuildPlan(Request{Src: "/in/file." + from, From: from, To: to, Quality: q}, allTools(), "/work", PlanOptions{OfficeProfile: "/prof"})
	if err != nil {
		t.Fatalf("%s->%s: %v", from, to, err)
	}
	return p
}

func argv(p *Plan, i int) string { return p.Steps[i].Prog + " " + strings.Join(p.Steps[i].Args, " ") }

func TestArgvBuilders(t *testing.T) {
	cases := []struct {
		from, to string
		q        Quality
		engine   Engine
		want     []string
	}{
		{"flac", "mp3", QualityBest, EngineFFmpeg, []string{"ffmpeg ", "-nostdin", "-progress pipe:1", "-i in.flac", "-vn", "-c:a libmp3lame -b:a 320k", "out.mp3"}},
		{"flac", "mp3", QualitySmall, EngineFFmpeg, []string{"-b:a 128k"}},
		{"wav", "ogg", QualityBalanced, EngineFFmpeg, []string{"-c:a libvorbis -q:a 5", "out.ogg"}},
		{"mp4", "mp3", QualityBalanced, EngineFFmpeg, []string{"-vn", "libmp3lame"}},
		{"mkv", "mp4", QualityBalanced, EngineFFmpeg, []string{"-c:v libx264", "-crf 23", "-movflags +faststart", "out.mp4"}},
		{"mp4", "webm", QualitySmall, EngineFFmpeg, []string{"libvpx-vp9", "-crf 40", "libopus"}},
		{"mp4", "gif", QualityBalanced, EngineFFmpeg, []string{"fps=15", "palettegen", "-loop 0", "out.gif"}},
		{"gif", "mp4", QualityBalanced, EngineFFmpeg, []string{"scale=trunc(iw/2)*2:trunc(ih/2)*2"}},
		{"jpg", "png", QualityBalanced, EngineMagick, []string{"magick in.jpg[0] out.png"}},
		{"png", "jpg", QualityBest, EngineMagick, []string{"-background white -alpha remove", "-quality 92", "out.jpg"}},
		{"gif", "webp", QualityBalanced, EngineMagick, []string{"magick in.gif -quality 80 out.webp"}},
		{"png", "ico", QualityBalanced, EngineMagick, []string{"icon:auto-resize"}},
		{"svg", "png", QualityBalanced, EngineRsvg, []string{"rsvg-convert -f png -o out.png in.svg"}},
		{"docx", "pdf", QualityBalanced, EngineSoffice, []string{"soffice --headless", "-env:UserInstallation=file:///prof", "--convert-to pdf --outdir office-out in.docx"}},
		{"pdf", "docx", QualityBalanced, EngineSoffice, []string{"--infilter=writer_pdf_import", "docx:MS Word 2007 XML"}},
		{"xlsx", "csv", QualityBalanced, EngineSoffice, []string{"csv:Text - txt - csv (StarCalc):44,34,76,1"}},
		{"md", "html", QualityBalanced, EnginePandoc, []string{"pandoc --sandbox -f markdown -t json -o doc.json in.md"}},
		{"docx", "md", QualityBalanced, EnginePandoc, []string{"pandoc --sandbox -f docx -t json -o doc.json --extract-media=media in.docx"}},
		{"pdf", "png", QualityBalanced, EnginePdftoppm, []string{"pdftoppm -png -r 150 -f 1 -l 1 -singlefile in.pdf pages/page"}},
		{"pdf", "txt", QualityBalanced, EnginePdftotext, []string{"pdftotext -layout -enc UTF-8 in.pdf out.txt"}},
	}
	for _, c := range cases {
		p := plan(t, c.from, c.to, c.q)
		if p.Engine != c.engine {
			t.Errorf("%s->%s: engine %s, want %s", c.from, c.to, p.Engine, c.engine)
			continue
		}
		got := argv(p, 0)
		for _, w := range c.want {
			if !strings.Contains(got, w) {
				t.Errorf("%s->%s: %q lacks %q", c.from, c.to, got, w)
			}
		}
	}
}

// Markup to PDF: read in pandoc's sandbox, clean the tree, write an ODT
// from the document's own folder, print it with LibreOffice.
func TestDocPDFSteps(t *testing.T) {
	p := plan(t, "md", "pdf", QualityBalanced)
	if p.Engine != EngineDocPDF || len(p.Steps) != 4 {
		t.Fatalf("%+v", p)
	}
	if argv(p, 0) != "pandoc --sandbox -f markdown -t json -o doc.json in.md" || p.Steps[1].Native == nil ||
		argv(p, 2) != "pandoc -f json -t odt -s -o /work/mid.odt /work/doc-safe.json" || p.Steps[2].Dir != "/in" ||
		!strings.Contains(argv(p, 3), "--convert-to pdf --outdir office-out mid.odt") || p.Steps[3].Out != "out.pdf" {
		t.Fatalf("%s | %s | %s", argv(p, 0), argv(p, 2), argv(p, 3))
	}
}

// Tools never see the user's file name: a "%d" in it would be a pattern
// to ImageMagick and ffmpeg. Every engine reads in.<ext> and writes
// out.<ext> inside the work dir; every external step has a timeout.
func TestArgvNeverCarriesTheSourceName(t *testing.T) {
	all := allTools()
	for _, f := range Formats() {
		for _, tg := range Targets(f.ID, all) {
			src := "/home/u/odd %d [0] name." + f.Ext()
			p, err := BuildPlan(Request{Src: src, From: f.ID, To: tg.ID}, all, "/w", PlanOptions{OfficeProfile: "/p"})
			if err != nil {
				t.Fatalf("%s->%s: %v", f.ID, tg.ID, err)
			}
			for i, st := range p.Steps {
				if st.Native != nil {
					continue
				}
				if a := strings.Join(st.Args, " "); strings.Contains(a, "odd") || strings.Contains(a, "%d") {
					t.Errorf("%s->%s step %d: %s", f.ID, tg.ID, i, a)
				}
				if st.Timeout <= 0 {
					t.Errorf("%s->%s step %d has no timeout", f.ID, tg.ID, i)
				}
			}
		}
	}
}

func TestBuildPlanRefuses(t *testing.T) {
	if _, err := BuildPlan(Request{Src: "/a.mp3", From: "mp3", To: "pdf"}, allTools(), "/w", PlanOptions{}); err == nil {
		t.Fatal("mp3->pdf accepted")
	}
	_, err := BuildPlan(Request{Src: "/a.flac", From: "flac", To: "mp3"}, noTools(), "/w", PlanOptions{})
	if err == nil || !strings.Contains(err.Error(), "needs ffmpeg") {
		t.Fatalf("missing engine: %v", err)
	}
}

func TestQualityOnlyChangesLossyArgs(t *testing.T) {
	a, b := argv(plan(t, "flac", "wav", QualitySmall), 0), argv(plan(t, "flac", "wav", QualityBest), 0)
	if a != b {
		t.Fatalf("wav differs by quality: %s / %s", a, b)
	}
	if ParseQuality("nonsense") != QualityBalanced || ParseQuality("best") != QualityBest {
		t.Fatal("ParseQuality")
	}
}

func TestProgressAndErrors(t *testing.T) {
	if f, ok := ParseProgressLine("out_time_us=5000000", 10); !ok || f != 0.5 {
		t.Fatalf("half: %v %v", f, ok)
	}
	if f, ok := ParseProgressLine("out_time_us=5000000", 0); !ok || f != -1 {
		t.Fatalf("unknown duration: %v", f)
	}
	if f, _ := ParseProgressLine("progress=end", 10); f != 1 {
		t.Fatal("end")
	}
	if _, ok := ParseProgressLine("bitrate=128k", 10); ok {
		t.Fatal("bitrate moved progress")
	}
	stderr := "[mp3 @ 0x55d0] Header missing\n[aist#0:0/mp3 @ 0x55] Error while decoding stream: Invalid data found when processing input\nConversion failed!\n"
	if got := ErrorLine(stderr); got != "Error while decoding stream: Invalid data found when processing input" {
		t.Fatalf("ErrorLine: %q", got)
	}
	if got := ErrorLine(strings.Repeat("x", 400)); len([]rune(got)) != 160 {
		t.Fatalf("long line: %d", len(got))
	}
	tb := &tailBuffer{max: 2}
	_, _ = tb.Write([]byte("a\nb\nc\nd"))
	if tb.String() != "b\nc\nd" {
		t.Fatalf("tail: %q", tb.String())
	}
	if !slices.Contains(IDs(), "heic") {
		t.Fatal("IDs")
	}
}
