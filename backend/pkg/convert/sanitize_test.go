package convert

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// The sanitizer is pure Go: these fixtures are pandoc JSON trees, so the
// safety rules run in CI without pandoc installed.

func astImg(target string) map[string]any {
	return map[string]any{"t": "Image", "c": []any{[]any{"", []any{}, []any{}},
		[]any{map[string]any{"t": "Str", "c": "alt"}}, []any{target, ""}}}
}

func raw(format, s string) map[string]any {
	return map[string]any{"t": "RawInline", "c": []any{format, s}}
}

func para(inl ...any) map[string]any { return map[string]any{"t": "Para", "c": inl} }

func metaInl(inl ...any) map[string]any { return map[string]any{"t": "MetaInlines", "c": inl} }

// sanitize runs SanitizeAST on doc for a document in root and returns the
// cleaned JSON text.
func sanitize(t *testing.T, doc map[string]any, root, mediaLink string) (string, map[string]any) {
	t.Helper()
	work := t.TempDir()
	in, out := filepath.Join(work, "in.json"), filepath.Join(work, "out.json")
	b, _ := json.Marshal(doc)
	if err := os.WriteFile(in, b, 0o600); err != nil {
		t.Fatal(err)
	}
	if err := SanitizeAST(in, out, root, mediaLink, "docx"); err != nil {
		t.Fatal(err)
	}
	res, _ := os.ReadFile(out)
	var got map[string]any
	if err := json.Unmarshal(res, &got); err != nil {
		t.Fatal(err)
	}
	return string(res), got
}

func TestSanitizeAST(t *testing.T) {
	outside := t.TempDir()
	secret := filepath.Join(outside, "secret.png")
	pngFile(t, secret, 2, 2, "")
	root := t.TempDir()
	_ = os.MkdirAll(filepath.Join(root, "img"), 0o755)
	_ = os.MkdirAll(filepath.Join(root, ".ssh"), 0o700)
	pngFile(t, filepath.Join(root, "img", "pic.png"), 2, 2, "")
	pngFile(t, filepath.Join(root, ".ssh", "key.png"), 2, 2, "")
	_ = os.WriteFile(filepath.Join(root, "img", "key.png"), []byte("-----BEGIN OPENSSH PRIVATE KEY-----\nabc\n"), 0o600)
	_ = os.Symlink(secret, filepath.Join(root, "img", "sneaky.png"))
	_ = os.Symlink(filepath.Join(root, ".ssh"), filepath.Join(root, "keys"))

	doc := map[string]any{
		"pandoc-api-version": []any{1, 23},
		"meta": map[string]any{
			"title":           metaInl(astImg(secret), map[string]any{"t": "Str", "c": "Title"}),
			"abstract":        map[string]any{"t": "MetaBlocks", "c": []any{para(astImg("/home/u/.ssh/id_ed25519"))}},
			"author":          map[string]any{"t": "MetaList", "c": []any{metaInl(astImg("../x.png"))}},
			"cover-image":     map[string]any{"t": "MetaString", "c": secret},
			"header-includes": metaInl(raw("html", "<link rel=stylesheet href=/x.css>")),
			"anything-else":   map[string]any{"t": "MetaString", "c": secret},
		},
		"blocks": []any{
			para(astImg(secret), astImg("img/sneaky.png"), astImg("%2e%2e/x.png"), astImg("https://example.invalid/x.png"),
				astImg(".ssh/key.png"), astImg("keys/key.png"), astImg("img/key.png"), astImg("img/pic.png"), astImg("data:image/png;base64,AA")),
			para(
				raw("html", `<img src = "`+secret+`">`),
				raw("html", `<VIDEO POSTER='`+secret+`'>`),
				raw("html", `<img srcset="img/pic.png 1x, `+secret+` 2x">`),
				raw("html", `<svg><image xlink:href="`+secret+`"/></svg>`),
				raw("html", `<p style="background: u\rl( '`+secret+`' )">`),
				raw("html", `<link rel="stylesheet" href="x.css">`),
				raw("html", `<img src = "`+secret+`"`),
				raw("html", `<object data="img/pic.png">`),
				raw("html5", `<source src="https://example.invalid/a.mp4">`),
				raw("openxml", `<w:fldSimple w:instr="INCLUDEPICTURE file:///etc/passwd"/>`),
				raw("rtf", `{\field{\*\fldinst INCLUDEPICTURE "/etc/passwd"}}`),
				raw("latex", `\input{/etc/passwd}`),
			),
			para(
				raw("html", `<img src="img/pic.png" alt="ok">`),
				raw("html", `<a href="https://example.com/">link</a>`),
				raw("html", `<span class="x" style="color: red">`),
				raw("markdown", `*kept*`),
			),
		},
	}
	text, got := sanitize(t, doc, root, "")
	for _, leak := range []string{secret, "id_ed25519", "../x.png", "%2e%2e", "example.invalid", ".ssh/key.png",
		"keys/key.png", "img/key.png", "sneaky", "POSTER", "fldSimple", "INCLUDEPICTURE", "\\input", "x.css", "u\\\\rl",
		"<object", "anything-else", "cover-image", "header-includes"} {
		if strings.Contains(text, leak) {
			t.Errorf("cleaned tree still holds %q", leak)
		}
	}
	for _, keep := range []string{`"img/pic.png"`, "data:image/png;base64,AA", `img src=\"img/pic.png\" alt=\"ok\"`,
		"https://example.com/", "color: red", "*kept*", `"Title"`, `"title"`, `"abstract"`, `"author"`} {
		if !strings.Contains(text, keep) {
			t.Errorf("cleaned tree lost %q:\n%s", keep, text)
		}
	}
	// a refused image keeps its alt text
	if !strings.Contains(text, `"t":"Span"`) || !strings.Contains(text, `"alt"`) {
		t.Errorf("refused images lost their alt text: %s", text)
	}
	if _, ok := got["meta"].(map[string]any)["title"]; !ok {
		t.Error("title dropped")
	}
}

// A container's extracted media is pointed at the folder shipped next to
// a text result.
func TestSanitizeASTMediaLink(t *testing.T) {
	work := t.TempDir()
	_ = os.MkdirAll(filepath.Join(work, "media"), 0o755)
	pngFile(t, filepath.Join(work, "media", "image1.png"), 2, 2, "")
	doc := map[string]any{"meta": map[string]any{}, "blocks": []any{para(astImg("media/image1.png"))}}
	text, _ := sanitize(t, doc, work, "report_media")
	if !strings.Contains(text, `"report_media/image1.png"`) {
		t.Fatalf("media not relinked: %s", text)
	}
	text, _ = sanitize(t, doc, work, "")
	if !strings.Contains(text, `"media/image1.png"`) {
		t.Fatalf("media relinked without a link: %s", text)
	}
}

func TestRawHTMLSafe(t *testing.T) {
	root := t.TempDir()
	pngFile(t, filepath.Join(root, "a.png"), 2, 2, "")
	for s, want := range map[string]bool{
		`<b>bold</b>`:                         true,
		`<img src="a.png">`:                   true,
		`<img src = "/etc/x.png">`:            false,
		"<img\nsrc\n=\n/etc/x.png>":           false,
		`<IMG SRC="https://x/a.png">`:         false,
		`<video poster="/x.png"></video>`:     false,
		`<audio src="../a.mp3">`:              false,
		`<img srcset="a.png, /x.png 2x">`:     false,
		`<use href="#icon"/>`:                 true,
		`<image xlink:href="/x.png"/>`:        false,
		`<div style="background:url(/x)">`:    false,
		`<div style="b:URL&#40;/x)">`:         false,
		`<iframe src="a.png">`:                false,
		`<script>1</script>`:                  false,
		`<a href="/etc/passwd">a link</a>`:    true,
		`<img src="/x.png"`:                   false,
		`<!-- <img src="/x.png"> -->`:         true,
		`<img src="a.png" onerror="x">`:       true,
		`<embed src="a.png">`:                 false,
		`<base href="https://example.com/">`:  false,
		`<input type="image" src="/x.png">`:   false,
		`<table background="/x.png"></table>`: false,
	} {
		if got := rawHTMLSafe(s, root); got != want {
			t.Errorf("%q: safe=%v, want %v", s, got, want)
		}
	}
}
