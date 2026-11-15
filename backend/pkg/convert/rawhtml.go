package convert

import (
	"io"
	"strings"

	"golang.org/x/net/html"
)

// Raw HTML is parsed the way a browser (or pandoc's TagSoup) would, so
// `src = "/x"`, upper case, entities and any quoting are seen as the
// attribute they are.

// htmlBlockedTags load or run something whatever their attributes say.
var htmlBlockedTags = map[string]bool{"link": true, "script": true, "style": true, "iframe": true, "frame": true,
	"frameset": true, "object": true, "embed": true, "applet": true, "base": true, "meta": true, "portal": true,
	"import": true}

// htmlURLAttrs name a resource the writer (or a reader of the result)
// loads; checked with LocalResource.
var htmlURLAttrs = map[string]bool{"src": true, "href": true, "xlink:href": true, "poster": true, "data": true,
	"background": true, "lowsrc": true, "dynsrc": true, "codebase": true, "manifest": true, "archive": true,
	"classid": true, "icon": true}

// htmlSrcsets hold comma-separated "url descriptor" candidates.
var htmlSrcsets = map[string]bool{"srcset": true, "imagesrcset": true}

// htmlLinks: an <a href> is a link the reader follows, never loaded.
var htmlLinks = map[string]bool{"a": true, "area": true}

// cssLoaders mark CSS that fetches something.
var cssLoaders = []string{"url(", "image-set(", "@import", "expression(", "src:"}

// rawHTMLSafe reports whether raw HTML only loads files under root.
func rawHTMLSafe(raw, root string) bool {
	z := html.NewTokenizer(strings.NewReader(raw))
	consumed := 0
	for {
		tt := z.Next()
		if tt == html.ErrorToken {
			// a tag cut off at the end is not a token: judge what is left
			return z.Err() == io.EOF && !looksLikeLoader(raw[min(consumed, len(raw)):])
		}
		consumed += len(z.Raw())
		if tt != html.StartTagToken && tt != html.SelfClosingTagToken {
			continue
		}
		tok := z.Token()
		name := strings.ToLower(tok.Data)
		if htmlBlockedTags[name] {
			return false
		}
		for _, a := range tok.Attr {
			key := strings.ToLower(a.Key)
			if a.Namespace != "" {
				key = strings.ToLower(a.Namespace) + ":" + key
			}
			switch {
			case key == "style":
				if cssLoads(a.Val) {
					return false
				}
			case htmlSrcsets[key]:
				for _, cand := range strings.Split(a.Val, ",") {
					if f := strings.Fields(cand); len(f) > 0 && !LocalImage(f[0], root) {
						return false
					}
				}
			case key == "href" && htmlLinks[name]:
			case htmlURLAttrs[key], strings.HasSuffix(key, ":href"):
				if !LocalImage(a.Val, root) {
					return false
				}
			}
		}
	}
}

// cssLoads: CSS (with escapes and whitespace removed) that fetches.
func cssLoads(css string) bool {
	low := strings.ToLower(strings.Map(func(r rune) rune {
		if r == '\\' || r == ' ' || r == '\t' || r == '\n' || r == '\r' || r == '\f' {
			return -1
		}
		return r
	}, css))
	for _, l := range cssLoaders {
		if strings.Contains(low, l) {
			return true
		}
	}
	return false
}

// looksLikeLoader: text the tokenizer did not finish (an unterminated tag)
// that names a loading attribute or tag, whitespace ignored.
func looksLikeLoader(rest string) bool {
	if !strings.Contains(rest, "<") {
		return false
	}
	low := strings.ToLower(strings.Join(strings.Fields(rest), ""))
	for _, l := range []string{"src=", "srcset=", "href=", "poster=", "data=", "background=", "url(", "@import",
		"<link", "<script", "<style", "<iframe", "<object", "<embed", "<base", "<meta"} {
		if strings.Contains(low, l) {
			return true
		}
	}
	return false
}
