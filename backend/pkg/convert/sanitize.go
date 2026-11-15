package convert

import (
	"bytes"
	"encoding/json"
	"net/url"
	"os"
	"path/filepath"
	"strings"
)

// A text document (Markdown, HTML, reStructuredText, Org, LaTeX) can point
// at any file or URL: an image of ~/.ssh/id_ed25519, a remote picture, a
// cover image named in its metadata. Written to docx, odt, epub (or html
// with its resources embedded), pandoc would embed them. SanitizeAST
// cleans pandoc's JSON document tree before the writer runs, so only
// images the document's own folder tree holds can be pulled in:
//   - an image whose target is remote, absolute, in a hidden folder,
//     resolves (symlinks followed) outside the source's folder, or is not
//     an image file becomes its alt text;
//   - raw HTML is parsed: a tag that loads something (img, video, source,
//     svg image ... by src, srcset, poster, data, xlink:href, a CSS url())
//     from anywhere but the document's folder, and tags such as link,
//     script, style, iframe, object, embed, base are dropped;
//   - raw LaTeX that reads files is dropped, raw markup of other formats
//     (OpenXML, ODF, RTF ...: written into the output as is) is dropped;
//   - only plain descriptive metadata is kept (title, author, abstract
//     ...), and it is cleaned like the body (a title can hold an image).

// metaKeep are the metadata fields kept: the ones writers show, none that
// names a file (cover-image, css, bibliography, reference-doc, header-includes ...).
var metaKeep = map[string]bool{"title": true, "subtitle": true, "author": true, "date": true, "lang": true,
	"dir": true, "abstract": true, "abstract-title": true, "keywords": true, "subject": true, "description": true,
	"category": true, "rights": true, "publisher": true, "creator": true, "contributor": true, "identifier": true,
	"language": true, "toc-title": true, "institute": true, "pagetitle": true, "title-prefix": true}

// texLoaders mark raw LaTeX that reads another file.
var texLoaders = []string{"\\include", "\\input", "\\usepackage", "\\lstinputlisting", "\\verbatiminput",
	"\\openin", "\\read", "\\write18", "\\immediate", "\\href", "\\url"}

// rawText: raw formats whose content is only ever text in the output.
var rawText = map[string]bool{"markdown": true, "commonmark": true, "gfm": true, "rst": true, "org": true,
	"plain": true, "asciidoc": true, "textile": true, "mediawiki": true}

// SanitizeAST reads pandoc JSON from in, cleans it for a document living
// in srcDir and writes it to out. A non-empty mediaLink rewrites images
// under the extracted media folder ("media/...") to mediaLink/...: the
// folder that is shipped next to a text result.
func SanitizeAST(in, out, srcDir, mediaLink string) error {
	raw, err := os.ReadFile(in)
	if err != nil {
		return err
	}
	dec := json.NewDecoder(bytes.NewReader(raw))
	dec.UseNumber()
	var doc map[string]any
	if err := dec.Decode(&doc); err != nil {
		return err
	}
	root, err := filepath.EvalSymlinks(srcDir)
	if err != nil {
		root = filepath.Clean(srcDir)
	}
	c := cleaner{root: root, mediaLink: mediaLink}
	if meta, ok := doc["meta"].(map[string]any); ok {
		for k, v := range meta {
			if metaKeep[k] {
				meta[k] = c.clean(v)
			} else {
				delete(meta, k)
			}
		}
	} else {
		delete(doc, "meta")
	}
	doc["blocks"] = c.clean(doc["blocks"])
	b, err := json.Marshal(doc)
	if err != nil {
		return err
	}
	return os.WriteFile(out, b, 0o600)
}

type cleaner struct {
	root      string
	mediaLink string
}

// clean walks the tree and returns the cleaned value.
func (c cleaner) clean(v any) any {
	switch n := v.(type) {
	case []any:
		for i := range n {
			n[i] = c.clean(n[i])
		}
		return n
	case map[string]any:
		switch n["t"] {
		case "Image":
			if args, ok := n["c"].([]any); ok && len(args) == 3 {
				if tgt, ok := args[2].([]any); ok && len(tgt) == 2 {
					s, _ := tgt[0].(string)
					if !LocalImage(s, c.root) {
						return map[string]any{"t": "Span", "c": []any{args[0], c.clean(args[1])}}
					}
					if c.mediaLink != "" && strings.HasPrefix(s, mediaDir+"/") {
						tgt[0] = c.mediaLink + "/" + strings.TrimPrefix(s, mediaDir+"/")
					}
				}
			}
		case "RawInline", "RawBlock":
			if args, ok := n["c"].([]any); ok && len(args) == 2 {
				format, _ := args[0].(string)
				s, _ := args[1].(string)
				if !c.rawSafe(strings.ToLower(format), s) {
					args[1] = ""
				}
			}
			return n
		}
		for k, x := range n {
			if k != "t" {
				n[k] = c.clean(x)
			}
		}
		return n
	}
	return v
}

func (c cleaner) rawSafe(format, s string) bool {
	switch {
	case strings.HasPrefix(format, "html"):
		return rawHTMLSafe(s, c.root)
	case format == "latex" || format == "tex" || format == "context":
		low := strings.ToLower(s)
		for _, l := range texLoaders {
			if strings.Contains(low, l) {
				return false
			}
		}
		return true
	}
	return rawText[format]
}

// LocalResource reports whether an image target is a file inside root:
// relative, no scheme (data: URIs are inline and allowed), not in a hidden
// file or folder, and resolving (also percent-decoded, symlinks followed)
// under root.
func LocalResource(target, root string) bool {
	_, ok := localPaths(target, root)
	return ok
}

// LocalImage is LocalResource that is also an image when it exists (a
// key file renamed .png is not one); a missing file embeds nothing.
func LocalImage(target, root string) bool {
	paths, ok := localPaths(target, root)
	if !ok {
		return false
	}
	for _, p := range paths {
		st, err := os.Stat(p)
		if err != nil {
			continue
		}
		if !st.Mode().IsRegular() {
			return false
		}
		if f, _, ok := sniffFile(p); !ok || f.Kind != KindImage {
			return false
		}
	}
	return true
}

// localPaths: the resolved files a target may name (as written and
// percent-decoded), ok when every one is a local resource under root.
func localPaths(target, root string) ([]string, bool) {
	t := strings.TrimSpace(target)
	if t == "" {
		return nil, false
	}
	if strings.HasPrefix(strings.ToLower(t), "data:") {
		return nil, true
	}
	if u, err := url.Parse(t); err != nil || u.Scheme != "" || u.Host != "" || strings.HasPrefix(t, "//") {
		return nil, false
	}
	cands := []string{t}
	if d, err := url.PathUnescape(t); err == nil && d != t {
		cands = append(cands, d)
	}
	var out []string
	for _, c := range cands {
		if filepath.IsAbs(c) || strings.HasPrefix(c, "~") || strings.Contains(c, "\\") || hidden(filepath.Clean(c)) {
			return nil, false
		}
		p := filepath.Join(root, c)
		if r, err := filepath.EvalSymlinks(p); err == nil {
			p = r
		}
		if p != root && !strings.HasPrefix(p, root+string(filepath.Separator)) {
			return nil, false
		}
		if rel, err := filepath.Rel(root, p); err != nil || hidden(rel) {
			return nil, false
		}
		out = append(out, p)
	}
	return out, true
}

// hidden: a relative path with a component starting with "." (".." is
// left to the folder check).
func hidden(rel string) bool {
	for _, part := range strings.Split(filepath.ToSlash(rel), "/") {
		if strings.HasPrefix(part, ".") && part != "." && part != ".." {
			return true
		}
	}
	return false
}
