package convert

import (
	"strings"
	"testing"
)

func attr(kvs ...[2]string) []any {
	out := []any{}
	for _, kv := range kvs {
		out = append(out, []any{kv[0], kv[1]})
	}
	return []any{"id1", []any{"note"}, out}
}

// Attributes of native elements (a markdown <div>, an HTML reader's
// <span>, {srcset=...} on an image or header) never carry a loader into
// html / epub.
func TestSanitizeASTElementAttributes(t *testing.T) {
	root := t.TempDir()
	pngFile(t, root+"/ok.png", 2, 2, "")
	str := map[string]any{"t": "Str", "c": "x"}
	doc := map[string]any{"meta": map[string]any{}, "blocks": []any{
		map[string]any{"t": "Div", "c": []any{attr([2]string{"style", "background:url(https://example.invalid/div.png)"},
			[2]string{"lang", "en"}), []any{para(str)}}},
		map[string]any{"t": "Header", "c": []any{1, attr([2]string{"srcset", "/etc/a.png 2x"}, [2]string{"data", "/x"}),
			[]any{str}}},
		para(
			map[string]any{"t": "Span", "c": []any{attr([2]string{"style", `background:u\72l(https://example.invalid/esc.png)`},
				[2]string{"data-keep", "1"}), []any{str}}},
			map[string]any{"t": "Span", "c": []any{attr([2]string{"STYLE", `b: \75 rl( /x )`}), []any{str}}},
			map[string]any{"t": "Span", "c": []any{attr([2]string{"style", "color: red"}), []any{str}}},
			map[string]any{"t": "Image", "c": []any{attr([2]string{"width", "50%"}, [2]string{"poster", "/abs.png"},
				[2]string{"xlink:href", "/abs.png"}), []any{str}, []any{"ok.png", ""}}},
			map[string]any{"t": "Code", "c": []any{attr([2]string{"src", "/x"}), "code"}},
		),
	}}
	text, _ := sanitize(t, doc, root, "")
	for _, leak := range []string{"example.invalid", "/etc/a.png", `"data"`, "/abs.png", "\\\\72", "\\\\75", `"src"`, `"STYLE"`} {
		if strings.Contains(text, leak) {
			t.Errorf("cleaned tree still holds %q:\n%s", leak, text)
		}
	}
	for _, keep := range []string{`"lang","en"`, `"data-keep","1"`, `"style","color: red"`, `"width","50%"`, `"ok.png"`, `"code"`} {
		if !strings.Contains(text, keep) {
			t.Errorf("cleaned tree lost %q:\n%s", keep, text)
		}
	}
}

func TestCSSLoads(t *testing.T) {
	for css, want := range map[string]bool{
		"color: red; margin: 0":                    false,
		"color: rgb(0, 0, 0)":                      false,
		"background: url(x.png)":                   true,
		"background: URL ( x.png )":                true, // whitespace dropped: the safe side
		`background: u\72l(x)`:                     true,
		`background: \75 rl(x)`:                    true,
		`background: \000075rl(x)`:                 true,
		`b: u\rl(x)`:                               true,
		"b: u/**/rl(x)":                            true, // comments removed first: safe side
		"@\\69mport 'x.css'":                       true,
		"b: image-set('a.png' 1x)":                 true,
		"b: -webkit-image-set('a.png' 1x)":         true,
		"src: local(x)":                            true,
		"b: expression(alert(1))":                  true,
		"font-family: 'Open Sans', sans-serif":     false,
		"content: '\\201C'":                        false,
		"background:\nurl(\n'https://e.invalid/')": true,
	} {
		if got := cssLoads(css); got != want {
			t.Errorf("%q: %v, want %v", css, got, want)
		}
	}
	root := t.TempDir()
	for s, want := range map[string]bool{
		`<img src="x.png" style="background:u\72l(https://e.invalid/a.png)">`: false,
		`<b style="\75rl(https://e.invalid/a.png)">`:                          false,
		`<b style="color:red">`:                                               true,
	} {
		if got := rawHTMLSafe(s, root); got != want {
			t.Errorf("%q: %v, want %v", s, got, want)
		}
	}
}
