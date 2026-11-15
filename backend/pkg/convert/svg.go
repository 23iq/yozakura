package convert

import (
	"bytes"
	"encoding/base64"
	"io"
	"net/url"
	"os"
	"strings"

	"golang.org/x/net/html"
)

// An SVG is embedded whole (docx, epub, the ODT LibreOffice prints): its
// <image href>, <use href>, CSS url() would be resolved by whatever renders
// it, and older LibreOffice draws any local file an SVG names. An SVG is
// only kept when every reference stays inside it (#id) or is inline data.

// maxSVGCheck: a larger SVG is refused rather than read whole.
const maxSVGCheck = 8 << 20

// svgBlockedTags load or run something.
var svgBlockedTags = map[string]bool{"script": true, "foreignobject": true, "iframe": true, "embed": true,
	"object": true, "link": true, "handler": true, "listener": true}

// svgSafe reports whether the SVG text references nothing outside itself.
func svgSafe(svg []byte) bool {
	z := html.NewTokenizer(bytes.NewReader(svg))
	inStyle := false
	for {
		tt := z.Next()
		switch tt {
		case html.ErrorToken:
			return z.Err() == io.EOF
		case html.TextToken:
			if inStyle && cssLoads(string(z.Text())) {
				return false
			}
		case html.EndTagToken:
			if n, _ := z.TagName(); strings.EqualFold(string(n), "style") {
				inStyle = false
			}
		case html.StartTagToken, html.SelfClosingTagToken:
			tok := z.Token()
			name := strings.ToLower(tok.Data)
			if svgBlockedTags[name] {
				return false
			}
			inStyle = name == "style" && tt == html.StartTagToken
			for _, a := range tok.Attr {
				key := strings.ToLower(a.Key)
				if a.Namespace != "" {
					key = strings.ToLower(a.Namespace) + ":" + key
				}
				v := strings.TrimSpace(a.Val)
				switch {
				case key == "style":
					if cssLoads(v) {
						return false
					}
				case key == "href" || strings.HasSuffix(key, ":href") || key == "src":
					if !svgInternalRef(v) {
						return false
					}
				default:
					// presentation attributes take url(#id) paints / filters
					if strings.Contains(strings.ToLower(cssPlain(v)), "url(") && !strings.HasPrefix(strings.ToLower(cssPlain(v)), "url(#") {
						return false
					}
				}
			}
		}
	}
}

// svgInternalRef: a fragment of this document, or inline raster data.
func svgInternalRef(v string) bool {
	low := strings.ToLower(v)
	if strings.HasPrefix(low, "#") {
		return true
	}
	return strings.HasPrefix(low, "data:") && !strings.HasPrefix(low, "data:image/svg")
}

// svgFileSafe checks an SVG file on disk.
func svgFileSafe(path string) bool {
	f, err := os.Open(path)
	if err != nil {
		return false
	}
	defer f.Close()
	b, err := io.ReadAll(io.LimitReader(f, maxSVGCheck+1))
	return err == nil && len(b) <= maxSVGCheck && svgSafe(b)
}

// dataSVGSafe checks a data: URI that holds an SVG (inline <svg> read by
// pandoc becomes one); other data: URIs are inline rasters, kept.
func dataSVGSafe(uri string) bool {
	meta, data, ok := strings.Cut(uri[len("data:"):], ",")
	if !ok {
		return false
	}
	if !strings.HasPrefix(strings.ToLower(strings.TrimSpace(meta)), "image/svg") {
		return true
	}
	var b []byte
	if strings.HasSuffix(strings.ToLower(meta), ";base64") {
		d, err := base64.StdEncoding.DecodeString(strings.TrimSpace(data))
		if err != nil {
			return false
		}
		b = d
	} else {
		d, err := url.PathUnescape(data)
		if err != nil {
			return false
		}
		b = []byte(d)
	}
	return len(b) <= maxSVGCheck && svgSafe(b)
}
