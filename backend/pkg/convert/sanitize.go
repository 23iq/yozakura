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
// cover image named in its metadata. Written to docx or epub, pandoc would
// embed them. SanitizeAST cleans pandoc's JSON document tree before the
// writer runs, so only what the document's own folder tree holds can be
// pulled in:
//   - an image whose target is remote, absolute, or resolves (symlinks
//     followed) outside the source's folder becomes its alt text;
//   - raw HTML / LaTeX that loads something (src=, <link, \include,
//     \input, url() ...) is dropped;
//   - metadata keys that name files to read are dropped.

// metaFileKeys are metadata fields pandoc's writers read files from.
var metaFileKeys = []string{"cover-image", "epub-cover-image", "css", "stylesheet", "epub-embedded-fonts",
	"epub-metadata", "bibliography", "csl", "citation-abbreviations", "reference-doc", "header-includes",
	"include-before", "include-after", "logo", "template"}

// rawLoaders mark raw markup that makes a writer read another file.
var rawLoaders = []string{"src=", "srcset=", "<link", "<object", "<embed", "<iframe", "url(", "\\include", "\\input",
	"\\usepackage", "\\lstinputlisting", "\\verbatiminput", "@import", "data="}

// SanitizeAST reads pandoc JSON from in, cleans it for a document living
// in srcDir and writes it to out.
func SanitizeAST(in, out, srcDir string) error {
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
	if meta, ok := doc["meta"].(map[string]any); ok {
		for _, k := range metaFileKeys {
			delete(meta, k)
		}
	}
	doc["blocks"] = clean(doc["blocks"], root)
	b, err := json.Marshal(doc)
	if err != nil {
		return err
	}
	return os.WriteFile(out, b, 0o600)
}

// clean walks the tree and returns the cleaned value.
func clean(v any, root string) any {
	switch n := v.(type) {
	case []any:
		for i := range n {
			n[i] = clean(n[i], root)
		}
		return n
	case map[string]any:
		switch n["t"] {
		case "Image":
			if c, ok := n["c"].([]any); ok && len(c) == 3 {
				if tgt, ok := c[2].([]any); ok && len(tgt) == 2 {
					if s, _ := tgt[0].(string); !LocalResource(s, root) {
						return map[string]any{"t": "Span", "c": []any{c[0], clean(c[1], root)}}
					}
				}
			}
		case "RawInline", "RawBlock":
			if c, ok := n["c"].([]any); ok && len(c) == 2 {
				if s, _ := c[1].(string); loadsFiles(s) {
					c[1] = ""
				}
			}
			return n
		}
		for k, x := range n {
			if k != "t" {
				n[k] = clean(x, root)
			}
		}
		return n
	}
	return v
}

func loadsFiles(raw string) bool {
	low := strings.ToLower(raw)
	for _, l := range rawLoaders {
		if strings.Contains(low, l) {
			return true
		}
	}
	return false
}

// LocalResource reports whether an image target is a file inside root:
// relative, no scheme (data: URIs are inline and allowed), and resolving
// (also percent-decoded, symlinks followed) under root.
func LocalResource(target, root string) bool {
	t := strings.TrimSpace(target)
	if t == "" {
		return false
	}
	if strings.HasPrefix(strings.ToLower(t), "data:") {
		return true
	}
	if u, err := url.Parse(t); err != nil || u.Scheme != "" || u.Host != "" || strings.HasPrefix(t, "//") {
		return false
	}
	cands := []string{t}
	if d, err := url.PathUnescape(t); err == nil && d != t {
		cands = append(cands, d)
	}
	for _, c := range cands {
		if filepath.IsAbs(c) || strings.HasPrefix(c, "~") || strings.Contains(c, "\\") {
			return false
		}
		p := filepath.Join(root, c)
		if r, err := filepath.EvalSymlinks(p); err == nil {
			p = r
		}
		if p != root && !strings.HasPrefix(p, root+string(filepath.Separator)) {
			return false
		}
	}
	return true
}
