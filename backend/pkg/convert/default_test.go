package convert

import "testing"

// The preferred default needs a missing tool but another target works:
// propose a working one; only a file nothing can convert keeps the
// unavailable default (and says what to install).
func TestDefaultFallsBackToAnAvailableTarget(t *testing.T) {
	// pdf without LibreOffice or poppler: docx needs LibreOffice, but
	// ImageMagick renders png
	magick := NewTools(map[Engine]string{EngineMagick: "magick"}, nil)
	if got := Default("pdf", magick); got != "png" {
		t.Errorf("pdf with magick only: %s", got)
	}
	// mp4 without ffmpeg: every target needs it, the preferred one stays
	if got := Default("mp4", noTools()); got != "webm" {
		t.Errorf("mp4 without ffmpeg: %s", got)
	}
	// heic: only ImageMagick reads it
	if tg, _ := Route("heic", Default("heic", noTools()), noTools()); tg.Available || tg.Needs != "ImageMagick" {
		t.Errorf("heic without magick: %+v", tg)
	}
	// md -> pdf without LibreOffice: a pandoc target is proposed instead
	pan := NewTools(map[Engine]string{EnginePandoc: "pandoc"}, nil)
	if d := Default("md", pan); d != "html" {
		t.Errorf("md with pandoc only proposes %s", d)
	}
	// docx -> pdf without LibreOffice: pandoc's popular txt
	if d := Default("docx", pan); d != "txt" {
		t.Errorf("docx with pandoc only proposes %s", d)
	}
	// every source on several machines: if any target works, the default does
	for _, tools := range []*Tools{pan, magick, noTools(), allTools(), NewTools(map[Engine]string{EngineSoffice: "soffice"}, nil)} {
		for _, f := range Formats() {
			works := false
			for _, tg := range Targets(f.ID, tools) {
				works = works || tg.Available
			}
			if tg, _ := Route(f.ID, Default(f.ID, tools), tools); works && !tg.Available {
				t.Errorf("%s: default %s unavailable though another target works", f.ID, tg.ID)
			}
		}
	}
	// the two-step markup PDF names only the tool that is missing
	if tg, _ := Route("md", "pdf", NewTools(map[Engine]string{EngineSoffice: "soffice"}, nil)); tg.Needs != "pandoc" {
		t.Errorf("md->pdf with LibreOffice only needs %q", tg.Needs)
	}
	if tg, _ := Route("md", "pdf", pan); tg.Needs != "LibreOffice" {
		t.Errorf("md->pdf with pandoc only needs %q", tg.Needs)
	}
	// with both installed (this machine) md -> pdf is available
	if tg, _ := Route("md", "pdf", allTools()); !tg.Available || tg.Engine != EngineDocPDF {
		t.Errorf("md->pdf with both: %+v", tg)
	}
}
