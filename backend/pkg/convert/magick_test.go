package convert

import (
	"bytes"
	"context"
	"image"
	_ "image/jpeg"
	"image/png"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// Every ImageMagick run names its coders, reads a private policy and is
// bounded; nothing here needs ImageMagick installed.
func TestMagickPlanIsHardened(t *testing.T) {
	p := plan(t, "png", "jpg", QualityBalanced)
	a := argv(p, 0)
	for _, w := range []string{"-limit memory 1GiB", "-limit disk 4GiB", "-limit time 600", "PNG:in.png[0]", "JPEG:out.jpg"} {
		if !strings.Contains(a, w) {
			t.Errorf("%q lacks %q", a, w)
		}
	}
	env := strings.Join(p.Steps[0].Env, " ")
	if !strings.Contains(env, "MAGICK_CONFIGURE_PATH=/work") || !strings.Contains(env, "MAGICK_TEMPORARY_PATH=/work") {
		t.Errorf("env %q", env)
	}
	pol := p.Files[magickPolicyFile]
	for _, w := range []string{`domain="delegate" rights="none" pattern="*"`, "PS,", "EPS,", "MVG", "MSL", "URL", "HTTPS", "PDF", `pattern="@*"`} {
		if !strings.Contains(pol, w) {
			t.Errorf("policy lacks %q:\n%s", w, pol)
		}
	}
	// a route through PDF keeps that coder (and Ghostscript to read it)
	toPDF := plan(t, "png", "pdf", QualityBalanced).Files[magickPolicyFile]
	if strings.Contains(toPDF, "PDF,") || strings.Contains(toPDF, ",PDF}") || !strings.Contains(toPDF, "delegate") {
		t.Errorf("png->pdf policy:\n%s", toPDF)
	}
	fromPDF := magickPolicy("pdf", "png", "PDF", "/w")
	if strings.Contains(fromPDF, "delegate") || !strings.Contains(fromPDF, "MVG") {
		t.Errorf("pdf->png policy:\n%s", fromPDF)
	}
	// SVG: librsvg when ImageMagick has it, else its own renderer under a
	// path policy; never the generic coder (the inkscape delegate)
	withRsvg := NewTools(map[Engine]string{EngineMagick: "magick"}, map[string]string{"SVG": "rw+", "RSVG": "rw+", "PNG": "rw+", "JPEG": "rw+"})
	svgArgs := strings.Join(magickArgs(Request{Src: "in.svg", From: "svg", To: "jpg"}, "out.jpg", withRsvg), " ")
	if !strings.Contains(svgArgs, "RSVG:in.svg[0]") {
		t.Errorf("svg argv %q", svgArgs)
	}
	if a := strings.Join(magickArgs(Request{Src: "in.svg", From: "svg", To: "jpg"}, "out.jpg", allTools()), " "); !strings.Contains(a, "MSVG:in.svg[0]") {
		t.Errorf("svg argv without a format list %q", a)
	}
	if pol := magickPolicy("svg", "jpg", "MSVG", "/w&"); !strings.Contains(pol, `pattern="/*"`) || !strings.Contains(pol, `pattern="*..*"`) ||
		!strings.Contains(pol, `rights="read|write" pattern="/w&amp;/*"`) {
		t.Errorf("svg policy:\n%s", pol)
	}
}

// PostScript named .jpg (Detect keeps the extension: text is a weak sniff)
// is refused by the JPEG coder; Ghostscript never runs. SVG named .png is
// refused the same way.
func TestMagickRefusesContentOfAnotherFormat(t *testing.T) {
	need(t, EngineMagick)
	fake := t.TempDir()
	marker := filepath.Join(fake, "gs-ran")
	if err := os.WriteFile(filepath.Join(fake, "gs"), []byte("#!/bin/sh\ntouch '"+marker+"'\nexit 1\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", fake+string(os.PathListSeparator)+os.Getenv("PATH"))
	dir := t.TempDir()
	cases := map[string]string{
		"photo.jpg": "%!PS-Adobe-3.0\n/Helvetica findfont 20 scalefont setfont 10 10 moveto (hi) show showpage\n",
		"pic.png":   `<svg xmlns="http://www.w3.org/2000/svg" width="4" height="4"><rect width="4" height="4"/></svg>`,
		"draw.png":  "push graphic-context\nviewbox 0 0 4 4\nimage over 0,0 4,4 '/etc/hostname'\npop graphic-context\n",
	}
	tools := NewTools(map[Engine]string{EngineMagick: realTools.Prog(EngineMagick)}, nil)
	for name, content := range cases {
		src := filepath.Join(dir, name)
		if err := os.WriteFile(src, []byte(content), 0o644); err != nil {
			t.Fatal(err)
		}
		f, ok := Detect(src)
		if !ok {
			t.Fatalf("%s: not detected", name)
		}
		to := "png"
		if f.ID == "png" {
			to = "bmp"
		}
		p, err := BuildPlan(Request{Src: src, From: f.ID, To: to}, tools, t.TempDir(), PlanOptions{})
		if err != nil {
			t.Fatalf("%s: %v", name, err)
		}
		if err := p.Run(context.Background(), nil); err == nil {
			t.Errorf("%s (%s) converted: content of another format was decoded", name, f.ID)
		}
	}
	if _, err := os.Stat(marker); err == nil {
		t.Fatal("ImageMagick handed a file to Ghostscript")
	}
}

// An SVG converted by ImageMagick never draws a file outside its folder,
// with librsvg or with ImageMagick's own renderer.
func TestMagickSVGKeepsToItsFolder(t *testing.T) {
	need(t, EngineMagick)
	outside := t.TempDir()
	secret := filepath.Join(outside, "secret.png")
	red := image.NewRGBA(image.Rect(0, 0, 8, 8))
	for i := range red.Pix {
		red.Pix[i] = map[int]uint8{0: 255, 1: 0, 2: 0, 3: 255}[i%4]
	}
	var b bytes.Buffer
	_ = png.Encode(&b, red)
	_ = os.WriteFile(secret, b.Bytes(), 0o644)
	src := filepath.Join(t.TempDir(), "x.svg")
	svg := `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="8" height="8">` +
		`<rect width="8" height="8" fill="white"/><image width="8" height="8" xlink:href="` + secret + `"/></svg>`
	_ = os.WriteFile(src, []byte(svg), 0o644)
	for _, formats := range []map[string]string{realTools.magickFormats, nil} {
		tools := NewTools(map[Engine]string{EngineMagick: realTools.Prog(EngineMagick)}, formats)
		p, err := BuildPlan(Request{Src: src, From: "svg", To: "jpg"}, tools, t.TempDir(), PlanOptions{})
		if err != nil {
			t.Fatal(err)
		}
		if err := p.Run(context.Background(), nil); err != nil {
			continue // refused: fine
		}
		f, _ := os.Open(p.Out)
		img, _, err := image.Decode(f)
		f.Close()
		if err != nil {
			t.Fatal(err)
		}
		if r, g, _, _ := img.At(4, 4).RGBA(); r > 0xc000 && g < 0x4000 {
			t.Errorf("%s drew a file outside the SVG's folder", tools.magickCoder("svg"))
		}
	}
}
