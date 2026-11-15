package convert

import (
	"encoding/base64"
	"net/url"
	"os"
	"path/filepath"
	"testing"
)

const svgHead = `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="4" height="4">`

// An SVG is embedded only when it references nothing outside itself.
func TestSVGSafe(t *testing.T) {
	for body, want := range map[string]bool{
		`<rect width="4" height="4" fill="red"/>`:                                                 true,
		`<defs><linearGradient id="g"/></defs><rect fill="url(#g)"/>`:                             true,
		`<use href="#g"/><image href="data:image/png;base64,AAAA"/>`:                              true,
		`<image href="/home/u/secret.png"/>`:                                                      false,
		`<image xlink:href="secret.png"/>`:                                                        false,
		`<image XLINK:HREF="https://example.invalid/x.png"/>`:                                     false,
		`<use href="other.svg#g"/>`:                                                               false,
		`<image href="data:image/svg+xml;base64,AAAA"/>`:                                          false,
		`<rect style="fill: u\72l(https://e.invalid/x)"/>`:                                        false,
		`<rect fill="url(https://e.invalid/p.svg#g)"/>`:                                           false,
		`<style>rect { fill: url(/x.svg#a) }</style>`:                                             false,
		`<style>rect { fill: red }</style><rect/>`:                                                true,
		`<script>fetch('x')</script>`:                                                             false,
		`<foreignObject><img xmlns="http://www.w3.org/1999/xhtml" src="/x.png"/></foreignObject>`: false,
		`<feImage href="/x.png"/>`:                                                                false,
		`<a href="https://example.com/"><text>link</text></a>`:                                    false,
		`<text x="0" y="3">a &amp; b</text>`:                                                      true,
	} {
		if got := svgSafe([]byte(svgHead + body + `</svg>`)); got != want {
			t.Errorf("%s: %v, want %v", body, got, want)
		}
	}
}

// Files and data: URIs: an SVG naming an outside file is not embedded; a
// self-contained one and rasters are.
func TestLocalImageSVG(t *testing.T) {
	root := t.TempDir()
	_ = os.WriteFile(filepath.Join(root, "ok.svg"), []byte(svgHead+`<rect/></svg>`), 0o644)
	_ = os.WriteFile(filepath.Join(root, "bad.svg"), []byte(svgHead+`<image href="/etc/x.png"/></svg>`), 0o644)
	bad := svgHead + `<image href="/etc/x.png"/></svg>`
	ok := svgHead + `<rect/></svg>`
	for target, want := range map[string]bool{
		"ok.svg":  true,
		"bad.svg": false,
		"data:image/svg+xml;base64," + base64.StdEncoding.EncodeToString([]byte(bad)): false,
		"data:image/svg+xml;base64," + base64.StdEncoding.EncodeToString([]byte(ok)):  true,
		"data:image/svg+xml," + url.PathEscape(bad):                                   false,
		"data:image/svg+xml;utf8," + url.PathEscape(ok):                               true,
		"data:image/png;base64,AAAA":                                                  true,
		"data:image/svg+xml;base64,!!!":                                               false,
	} {
		if got := LocalImage(target, root); got != want {
			t.Errorf("%.60s: %v, want %v", target, got, want)
		}
	}
}
