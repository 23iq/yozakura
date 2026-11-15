package convert

import (
	"bytes"
	"encoding/xml"
	"path/filepath"
	"strings"
)

// ImageMagick picks a decoder from a file's bytes, not its name: without
// care, PostScript named photo.jpg goes to Ghostscript and SVG named .png to
// the SVG renderer. Every run therefore
//   - names the coder of the input and the output explicitly (JPEG:in.jpg),
//     so content of another format is refused;
//   - reads a private policy.xml (MAGICK_CONFIGURE_PATH = the work dir) that
//     denies the script / network / indirect-read coders and external
//     delegates (Ghostscript only when the route needs PDF);
//   - is bounded by -limit and keeps its temporary files in the work dir.
//
// Limit: ImageMagick loads MAGICK_CONFIGURE_PATH's policy.xml before the
// system one and applies the last rule matching a coder or path (checked
// with ImageMagick 7.1.2: of two policy files, the later one's grant wins).
// A system or admin policy that grants a coder or path therefore overrides
// our deny for it, and nothing makes our file load last. The explicit
// coder still decides how the input itself is decoded; the denies are
// defence in depth for what a decoder reads on its own.

// magickPolicyFile is written into the work dir, read through
// MAGICK_CONFIGURE_PATH.
const magickPolicyFile = "policy.xml"

// magickDenied: coders no conversion here needs that read scripts, run
// Ghostscript, fetch URLs or render text from a file.
var magickDenied = []string{"PS", "PS2", "PS3", "EPS", "EPSI", "EPSF", "EPT", "EPI", "XPS", "PCL", "MVG", "MSL",
	"TEXT", "TXT", "URL", "HTTP", "HTTPS", "FTP", "FILE", "EPHEMERAL", "SHOW", "WIN", "X", "VID", "LABEL", "CAPTION",
	"PANGO"}

// magickPDFCoders are denied unless the route reads or writes PDF.
var magickPDFCoders = []string{"PDF", "PDFA", "EPDF", "AI"}

// magickLimits bound memory, the disk pixel cache and run time (a small
// file can declare a gigapixel canvas). Plain numbers parse the same in
// ImageMagick 6 and 7.
var magickLimits = []string{
	"-limit", "memory", "1GiB",
	"-limit", "map", "2GiB",
	"-limit", "disk", "4GiB",
	"-limit", "area", "268435456",
	"-limit", "width", "32768",
	"-limit", "height", "32768",
	"-limit", "time", "600",
}

// magickPolicy is the policy.xml of one run from -> to in work, whose input
// is read with coder in.
func magickPolicy(from, to, in, work string) string {
	denied := make([]string, 0, len(magickDenied)+len(magickPDFCoders))
	for _, c := range magickDenied {
		// ImageMagick's own SVG renderer draws through its MVG coder: the
		// input is still read as SVG (explicit MSVG:), and what it opens
		// is bounded by the path policy below
		if c != "MVG" || in != "MSVG" {
			denied = append(denied, c)
		}
	}
	if from != "pdf" && to != "pdf" {
		denied = append(denied, magickPDFCoders...)
	}
	var b strings.Builder
	b.WriteString("<policymap>\n")
	if from != "pdf" {
		// Ghostscript reads PDF; nothing else runs an external program
		b.WriteString(`  <policy domain="delegate" rights="none" pattern="*"/>` + "\n")
	}
	b.WriteString(`  <policy domain="coder" rights="none" pattern="{` + strings.Join(denied, ",") + `}"/>` + "\n")
	// @file reads a list of names from a file
	b.WriteString(`  <policy domain="path" rights="none" pattern="@*"/>` + "\n")
	if in == "MSVG" {
		// ImageMagick's own SVG renderer opens what an <image href> names:
		// only the work dir (a later rule wins in ImageMagick 7; librsvg
		// keeps to the SVG's folder by itself)
		for _, p := range []string{"/*", "*..*", "~*"} {
			b.WriteString(`  <policy domain="path" rights="none" pattern="` + p + `"/>` + "\n")
		}
		// ImageMagick matches the resolved path: allow the work dir as
		// named and with its symlinks resolved (a symlinked cache, /home
		// -> /var/home)
		dirs := []string{work}
		if r, err := filepath.EvalSymlinks(work); err == nil && r != work {
			dirs = append(dirs, r)
		}
		for _, d := range dirs {
			var w bytes.Buffer
			_ = xml.EscapeText(&w, []byte(d+"/*"))
			b.WriteString(`  <policy domain="path" rights="read|write" pattern="` + w.String() + `"/>` + "\n")
		}
	}
	b.WriteString("</policymap>\n")
	return b.String()
}

// magickEnv points ImageMagick at the policy and keeps its temporary files
// (pixel cache, delegate files) in the work dir, removed with it.
func magickEnv(work string) []string {
	return []string{"MAGICK_CONFIGURE_PATH=" + work, "MAGICK_TEMPORARY_PATH=" + work, "MAGICK_TMPDIR=" + work,
		"TMPDIR=" + work}
}

// magickCoder is the explicit coder of a format; SVG is read by librsvg
// when ImageMagick has it (it never loads files outside the SVG's folder),
// else by ImageMagick's own renderer under the path policy, never by the
// generic SVG coder (it would try the inkscape delegate).
func (t *Tools) magickCoder(id string) string {
	if id == "svg" {
		if t != nil && t.magickFormats != nil {
			if _, ok := t.magickFormats["RSVG"]; ok {
				return "RSVG"
			}
		}
		return "MSVG"
	}
	return magickName(id)
}

// magickArgs: the first frame unless the target keeps several (animated
// gif / webp, multi-page tiff / pdf); jpg and bmp get a white background
// instead of transparency.
func magickArgs(req Request, out string, t *Tools) []string {
	args := append([]string(nil), magickLimits...)
	src := t.magickCoder(req.From) + ":" + req.Src
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
	return append(args, t.magickCoder(req.To)+":"+out)
}
