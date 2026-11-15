package convert

import (
	"context"
	"os"
	"path/filepath"
	"testing"

	"yozakura/backend/pkg/proc"
)

// runPlan converts src (format from) to `to` in a fresh work dir and
// returns the result's bytes.
func runPlan(t *testing.T, src, from, to string) []byte {
	t.Helper()
	work := t.TempDir()
	p, err := BuildPlan(Request{Src: src, From: from, To: to, Quality: QualityBalanced}, realTools, work, PlanOptions{})
	if err != nil {
		t.Fatalf("%s->%s: %v", from, to, err)
	}
	if err := p.Run(context.Background(), nil); err != nil {
		t.Fatalf("%s->%s: %v", from, to, err)
	}
	b, _ := os.ReadFile(p.Out)
	return b
}

func TestMagickFormatListIM6(t *testing.T) {
	list := "   Format  Mode  Description\n" +
		"     HEIC  r--   High Efficiency Image Format (1.17.6)\n" +
		"     AVIF  r--   AV1 Image File Format (1.17.6)\n" +
		"      PNG* PNG       rw-   Portable Network Graphics\n"
	m := parseMagickFormats(list)
	if m["HEIC"] != "r--" || m["AVIF"] != "r--" || m["PNG"] != "rw-" {
		t.Fatalf("%v", m)
	}
	tools := NewTools(map[Engine]string{EngineMagick: "magick"}, m)
	if tg, _ := Route("heic", "png", tools); !tg.Available {
		t.Fatalf("heic readable by IM6: %+v", tg)
	}
}

// SVG through ImageMagick runs its MSVG (or RSVG) coder: an ImageMagick 6
// without its "extra" coders lists neither and offers no SVG route, while
// Ubuntu's full package lists MSVG next to SVG.
func TestMagickSVGNeedsItsCoder(t *testing.T) {
	core := "     JPEG* JPEG      rw-   Joint Photographic Experts Group JFIF format\n" +
		"      PNG* PNG       rw-   Portable Network Graphics (libpng 1.6.43)\n"
	extra := core + "     MSVG  SVG       rw+   ImageMagick's own SVG internal renderer\n" +
		"      SVG  SVG       rw+   Scalable Vector Graphics (XML 2.9.14)\n"
	for list, want := range map[string]bool{core: false, extra: true} {
		tools := NewTools(map[Engine]string{EngineMagick: "convert"}, parseMagickFormats(list))
		if tg, _ := Route("svg", "jpg", tools); tg.Available != want {
			t.Errorf("svg->jpg available=%v, want %v (MSVG listed: %v)", tg.Available, want, want)
		}
	}
	// only the generic SVG coder listed (the inkscape delegate): no route
	svgOnly := NewTools(map[Engine]string{EngineMagick: "convert"}, map[string]string{"SVG": "rw+", "JPEG": "rw-"})
	if tg, _ := Route("svg", "jpg", svgOnly); tg.Available {
		t.Errorf("svg->jpg without MSVG/RSVG: %+v", tg)
	}
}

func TestPandocVersionGate(t *testing.T) {
	for v, want := range map[string]bool{"pandoc 3.1.3\n": true, "pandoc 2.15": true, "pandoc 2.14.2": false, "pandoc 2.9": false, "garbage": false} {
		if PandocHasSandbox(v) != want {
			t.Errorf("%q", v)
		}
	}
	old := &Tools{progs: map[Engine]string{EngineSoffice: "soffice"}, pandocOld: true}
	if tg, _ := Route("md", "html", old); tg.Available || tg.Needs != "pandoc 2.15 or newer" {
		t.Errorf("old pandoc: %+v", tg)
	}
}

// ImageMagick's PDF ability comes from a real run, not from its list.
func TestMagickPDFProbe(t *testing.T) {
	blocked := NewTools(map[Engine]string{EngineMagick: "magick"}, nil)
	blocked.magickPDF = &pdfAbility{}
	if tg, _ := Route("png", "pdf", blocked); tg.Available {
		t.Errorf("png->pdf offered although ImageMagick cannot write PDF: %+v", tg)
	}
	if tg, _ := Route("pdf", "png", blocked); tg.Available {
		t.Errorf("pdf->png offered although ImageMagick cannot read PDF: %+v", tg)
	}
	if realTools.Has(EngineMagick) {
		t.Logf("this ImageMagick: %+v", *realTools.magickPDF)
		if tg, _ := Route("png", "pdf", realTools); tg.Available {
			// offered: it must work
			_ = runPlanWithTools(t, realTools, "png", "pdf")
		}
	}
}

func runPlanWithTools(t *testing.T, tools *Tools, from, to string) []byte {
	t.Helper()
	src := filepath.Join(t.TempDir(), "a."+from)
	if _, err := proc.Run(context.Background(), tools.Prog(EngineMagick), "-size", "2x2", "xc:red", src); err != nil {
		t.Fatal(err)
	}
	return runPlan(t, src, from, to)
}
