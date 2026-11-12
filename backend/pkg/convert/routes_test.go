package convert

import (
	"slices"
	"testing"
)

// everything installed, every ImageMagick format readable and writable
func allTools() *Tools {
	return NewTools(map[Engine]string{
		EngineFFmpeg: "ffmpeg", EngineMagick: "magick", EngineRsvg: "rsvg-convert", EngineSoffice: "soffice",
		EnginePandoc: "pandoc", EnginePdftoppm: "pdftoppm", EnginePdftotext: "pdftotext",
	}, nil)
}

func noTools() *Tools { return NewTools(nil, nil) }

func TestEverySourceHasDefaultAmongItsTargets(t *testing.T) {
	for _, tools := range []*Tools{allTools(), noTools()} {
		for _, f := range Formats() {
			targets := Targets(f.ID, tools)
			if len(targets) == 0 {
				t.Errorf("%s: no targets", f.ID)
				continue
			}
			d := Default(f.ID, tools)
			if d == "" {
				t.Errorf("%s: no default", f.ID)
			}
			ids := []string{}
			for _, tg := range targets {
				ids = append(ids, tg.ID)
				if tg.ID == f.ID {
					t.Errorf("%s targets itself", f.ID)
				}
				if byID[tg.ID].ReadOnly {
					t.Errorf("%s -> %s: a read-only format is a target", f.ID, tg.ID)
				}
				if !tg.Available && tg.Needs == "" {
					t.Errorf("%s -> %s: unavailable without needs", f.ID, tg.ID)
				}
			}
			if !slices.Contains(ids, d) {
				t.Errorf("%s: default %s not among %v", f.ID, d, ids)
			}
			for _, x := range defaults[f.ID] {
				if !slices.Contains(ids, x) {
					t.Errorf("%s: default candidate %s is not a target", f.ID, x)
				}
			}
		}
	}
}

func TestTablesNameKnownFormats(t *testing.T) {
	for _, fam := range families {
		for _, s := range fam.sources {
			if _, ok := byID[s]; !ok {
				t.Errorf("unknown source %s", s)
			}
		}
		for _, r := range fam.routes {
			if _, ok := byID[r.to]; !ok {
				t.Errorf("unknown target %s", r.to)
			}
			if len(r.via) == 0 {
				t.Errorf("%s: no engine", r.to)
			}
		}
	}
	for src := range defaults {
		if _, ok := byID[src]; !ok {
			t.Errorf("default for unknown %s", src)
		}
	}
	seen := map[string]bool{}
	for _, f := range formats {
		for _, e := range f.Exts {
			if seen[e] {
				t.Errorf("extension %s twice", e)
			}
			seen[e] = true
		}
	}
}

func TestSmartDefaults(t *testing.T) {
	all := allTools()
	for from, want := range map[string]string{
		"jpg": "png", "webp": "png", "heic": "jpg", "avif": "png", "bmp": "png", "tiff": "png",
		"png": "jpg", "svg": "png", "gif": "mp4", "flac": "mp3", "wav": "mp3", "ogg": "mp3",
		"opus": "mp3", "m4a": "mp3", "aac": "mp3", "aiff": "mp3", "mp3": "wav", "mkv": "mp4",
		"mov": "mp4", "webm": "mp4", "avi": "mp4", "mp4": "webm", "docx": "pdf", "odt": "pdf",
		"rtf": "pdf", "pptx": "pdf", "xlsx": "pdf", "md": "pdf", "html": "pdf", "txt": "pdf",
		"pdf": "docx", "epub": "pdf", "json": "yaml", "yaml": "json", "csv": "json",
	} {
		if got := Default(from, all); got != want {
			t.Errorf("%s: default %s, want %s", from, got, want)
		}
	}
	// pdf without LibreOffice falls back to png (poppler)
	pop := NewTools(map[Engine]string{EnginePdftoppm: "pdftoppm"}, nil)
	if got := Default("pdf", pop); got != "png" {
		t.Errorf("pdf without soffice: %s", got)
	}
	// md without LibreOffice: html (pandoc alone)
	pan := NewTools(map[Engine]string{EnginePandoc: "pandoc"}, nil)
	if got := Default("md", pan); got != "html" {
		t.Errorf("md with pandoc only: %s", got)
	}
}

func TestOfferedTargets(t *testing.T) {
	all := allTools()
	want := map[string][]string{
		"mp4":  {"webm", "mkv", "gif", "mp3", "wav"},
		"jpg":  {"png", "webp", "avif", "gif", "bmp", "tiff", "ico", "jxl", "pdf"},
		"flac": {"mp3", "wav", "ogg", "opus"},
		"json": {"yaml", "toml", "csv"},
	}
	for from, ids := range want {
		for _, id := range ids {
			if tg, ok := Route(from, id, all); !ok || !tg.Available {
				t.Errorf("%s -> %s not offered", from, id)
			}
		}
	}
}

func TestUnavailableNamesTheTool(t *testing.T) {
	none := noTools()
	tg, _ := Route("flac", "mp3", none)
	if tg.Available || tg.Needs != "ffmpeg" {
		t.Fatalf("flac->mp3 without ffmpeg: %+v", tg)
	}
	tg, _ = Route("docx", "pdf", none)
	if tg.Available || tg.Needs != "LibreOffice" {
		t.Fatalf("docx->pdf: %+v", tg)
	}
	tg, _ = Route("md", "pdf", none)
	if tg.Needs != "pandoc + LibreOffice" {
		t.Fatalf("md->pdf: %+v", tg)
	}
	// native: data and common images need nothing
	for _, p := range [][2]string{{"json", "yaml"}, {"csv", "json"}, {"jpg", "png"}, {"webp", "png"}, {"png", "jpg"}} {
		if tg, _ := Route(p[0], p[1], none); !tg.Available || tg.Engine != EngineNative {
			t.Errorf("%s->%s should be native: %+v", p[0], p[1], tg)
		}
	}
	// heic needs ImageMagick
	if tg, _ := Route("heic", "png", none); tg.Available || tg.Needs != "ImageMagick" {
		t.Errorf("heic->png: %+v", tg)
	}
}

func TestMagickFormatList(t *testing.T) {
	list := "   Format  Module    Mode  Description\n" +
		"-------------------------------------------\n" +
		"      PNG* PNG       rw-   Portable Network Graphics\n" +
		"     JPEG* JPEG      rw-   Joint Photographic Experts Group JFIF format\n" +
		"     HEIC  HEIC      r--   High Efficiency Image Format\n" +
		"      GIF* GIF       rw+   CompuServe graphics interchange format\n"
	tools := NewTools(map[Engine]string{EngineMagick: "magick"}, parseMagickFormats(list))
	if tg, _ := Route("heic", "jpg", tools); !tg.Available || tg.Engine != EngineMagick {
		t.Errorf("heic readable: %+v", tg)
	}
	// avif is not in the list and there is no ffmpeg
	if tg, _ := Route("png", "avif", tools); tg.Available {
		t.Errorf("avif not writable: %+v", tg)
	}
	// webp is not in magick's list: the native decoder takes webp -> png
	if tg, _ := Route("webp", "png", tools); !tg.Available || tg.Engine != EngineNative {
		t.Errorf("webp->png: %+v", tg)
	}
}

func TestPopularIncludesDefault(t *testing.T) {
	all := allTools()
	for _, f := range Formats() {
		d := Default(f.ID, all)
		for _, tg := range Targets(f.ID, all) {
			if tg.ID == d && !tg.Popular {
				t.Errorf("%s: default %s is not popular", f.ID, d)
			}
		}
	}
}
