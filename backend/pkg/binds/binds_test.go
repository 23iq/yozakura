package binds

import (
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"yozakura/backend/pkg/specials"
	"yozakura/backend/pkg/yozd/ipc"
)

// repoRoot holds assets/schema/bind-actions.json.
var repoRoot = filepath.Join("..", "..", "..")

func testAdvisor(t *testing.T) (*Advisor, string) {
	t.Helper()
	cat, err := LoadCatalog(repoRoot)
	if err != nil {
		t.Fatal(err)
	}
	src, err := os.ReadFile(filepath.Join("testdata", "binds.json"))
	if err != nil {
		t.Fatal(err)
	}
	file := filepath.Join(t.TempDir(), "binds.json")
	if err := os.WriteFile(file, src, 0o644); err != nil {
		t.Fatal(err)
	}
	a := &Advisor{
		Catalog: cat, File: file, AppID: "yozakura", CompositorName: "hyprland",
		Compositor: func() ([]ipc.Bind, error) {
			return []ipc.Bind{
				{Modifiers: []string{"SUPER"}, Key: "Q", Dispatcher: "__lua"},                             // rendered from binds.json
				{Modifiers: []string{"SUPER"}, Key: "P", Dispatcher: "__lua", Description: "Window: Pin"}, // user's own config
				{Modifiers: []string{"SUPER", "CTRL"}, Key: "Q", Dispatcher: "exec", Arg: "wlogout"},      // undescribed extra
				{Modifiers: []string{"SUPER"}, Key: "G", Dispatcher: "exec", Arg: "x", Submap: "resize"},  // other submap
				{Modifiers: []string{"SUPER"}, Key: "Q", Dispatcher: "__lua", Description: "Close (lua)"}, // native duplicate
				{Modifiers: []string{"SUPER"}, Key: "Super_L", Dispatcher: "__lua", Release: true},        // the launcher (release bind)
				{Modifiers: []string{"SUPER", "CTRL"}, Key: "T", Dispatcher: "__lua"},                     // rendered special toggle
			}, nil
		},
		Apps: func() []App {
			return []App{{ID: "firefox", Name: "Firefox"}, {ID: "org.telegram.desktop", Name: "Telegram"}}
		},
		Specials: func() ([]specials.Special, error) {
			return []specials.Special{{ID: "chat", Name: "Chat", Toggle: specials.Combo{Modifiers: []string{"SUPER", "CTRL"}, Key: "T"}}}, nil
		},
	}
	return a, file
}

func readFile(t *testing.T, path string) string {
	t.Helper()
	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	return string(b)
}

func TestParseCombo(t *testing.T) {
	same := []string{"SUPER+SHIFT+S", "super + shift + s", "Mod4 Shift S", "SHIFT+SUPER+s", "SUPER SHIFT, S", "win+shift+S"}
	want := "SUPER+SHIFT|s"
	for _, s := range same {
		c, err := ParseCombo(s)
		if err != nil || c.ID() != want || c.String() != "SUPER+SHIFT+S" || c.Key != "S" {
			t.Fatalf("%q: %+v %q %v", s, c, c.ID(), err)
		}
	}
	if c, _ := ParseCombo("SUPER"); c.Key != "Super_L" || c.ID() != "SUPER|super_l" || c.String() != "SUPER" {
		t.Fatalf("lone super: %+v", c)
	}
	if c, _ := ParseCombo("SUPER+."); c.Key != "PERIOD" || c.ID() != "SUPER|period" {
		t.Fatalf("period: %+v", c)
	}
	if c, _ := ParseCombo("CTRL+ALT+Return"); c.ID() != "CTRL+ALT|return" {
		t.Fatalf("return: %+v", c)
	}
	if a, b := (Combo{Key: "enter", Modifiers: []string{"SUPER"}}), (Combo{Key: "RETURN", Modifiers: []string{"MOD4"}}); a.ID() != b.ID() {
		t.Fatal("key aliases must compare equal")
	}
	for _, bad := range []string{"", "SUPER+SHIFT", "HYPER+S"} {
		if _, err := ParseCombo(bad); err == nil {
			t.Fatalf("%q: want an error", bad)
		}
	}
}

func TestDocumentRoundTripKeepsBytes(t *testing.T) {
	src := readFile(t, filepath.Join("testdata", "binds.json"))
	doc, err := loadDocument(filepath.Join("testdata", "binds.json"), "yozakura")
	if err != nil {
		t.Fatal(err)
	}
	out, err := doc.bytes()
	if err != nil {
		t.Fatal(err)
	}
	if string(out) != src {
		t.Fatalf("round trip changed the file:\n%s", out)
	}
}

func TestList(t *testing.T) {
	a, _ := testAdvisor(t)
	l, err := a.List()
	if err != nil {
		t.Fatal(err)
	}
	count := map[string]int{}
	var native []string
	for _, b := range l.Binds {
		count[b.Source]++
		if b.Source == SourceCompositor {
			native = append(native, b.Combo+"="+b.Label)
		}
		if b.Ref == "core:system.reload" && b.Enabled {
			t.Fatal("system.reload is in disabled")
		}
		if b.Ref == "core:system.lockscreen" && b.Combo != "SUPER+DELETE" {
			t.Fatalf("lockscreen keeps the user's combo: %+v", b)
		}
	}
	if count[SourceCore] != len(a.Catalog.Core) || count[SourceUser] != 4 {
		t.Fatalf("counts %v", count)
	}
	if strings.Join(native, ";") != "SUPER+P=Window: Pin;SUPER+CTRL+Q=exec wlogout;SUPER+G=exec x;SUPER+Q=Close (lua)" {
		t.Fatalf("native binds: %v", native)
	}
}

func TestCheck(t *testing.T) {
	a, _ := testAdvisor(t)
	cases := map[string]string{"super+q": "shell-user,compositor", "SUPER+P": "compositor", "SUPER+A": "shell-core", "SUPER+F": "", "SUPER+G": "", "SUPER+CTRL+T": "shell-special", "SUPER": "shell-core"}
	for combo, want := range cases {
		r, err := a.Check(combo)
		if err != nil {
			t.Fatal(err)
		}
		var got []string
		for _, c := range r.Conflicts {
			got = append(got, c.Source)
		}
		if strings.Join(got, ",") != want || r.Free != (want == "") {
			t.Fatalf("%s: conflicts %v free %v", combo, got, r.Free)
		}
	}
	if r, _ := a.Check("SUPER+3"); r.Free || r.Reserved == "" {
		t.Fatalf("SUPER+3 is reserved: %+v", r)
	}
}

func TestSuggest(t *testing.T) {
	a, _ := testAdvisor(t)
	r, err := a.Suggest("window.toggle-float", 4)
	if err != nil {
		t.Fatal(err)
	}
	if len(r.Suggestions) != 4 || r.Suggestions[0].Combo != "SUPER+F" {
		t.Fatalf("suggestions: %+v", r.Suggestions)
	}
	if len(r.Bound) != 1 || r.Bound[0] != "SUPER+SPACE" {
		t.Fatalf("bound: %v", r.Bound)
	}
	for _, s := range r.Suggestions {
		c, _ := ParseCombo(s.Combo)
		if chk, _ := a.Check(s.Combo); !chk.Free || !strings.HasPrefix(c.ID(), "SUPER") {
			t.Fatalf("suggested a taken/reserved combo %s", s.Combo)
		}
	}
	// A query instead of an id resolves through search.
	r, err = a.Suggest("заметки", 2)
	if err != nil || r.Action == nil || r.Action.ID != "yozakura.notes" {
		t.Fatalf("query suggest: %+v %v", r, err)
	}
}

func TestSearch(t *testing.T) {
	a, _ := testAdvisor(t)
	top := func(q string) Result {
		t.Helper()
		res, err := a.Search(q, 5)
		if err != nil || len(res) == 0 {
			t.Fatalf("%q: no results (%v)", q, err)
		}
		return res[0]
	}
	cases := map[string]string{
		"переключить раскладку": "keyboard-layout-next",
		"keyboard layout":     "keyboard-layout-next",
		"громкость":           "audio.volume-up",
		"сделать скриншот":    "yozakura.screenshot",
		"open terminal":       "yozakura.terminal",
		"close window":        "window.close",
		"закрыть окно":        "window.close",
		"firefox":             "firefox",
		"полноэкранный режим": "window.fullscreen",
		"lock the screen":     "system.lock",
		"буфер обмена":        "yozakura.clipboard",
		"mute microphone":     "mic-mute",
		"следующий трек":      "media.next",
		"hotkeys cheatsheet":  "yozakura.keybinds",
	}
	for q, want := range cases {
		if got := top(q); got.ID != want {
			t.Errorf("%q: top %s (%s), want %s", q, got.ID, got.Kind, want)
		}
	}
	if r := top("firefox"); r.Kind != KindApp || r.Action.ID != "apps.launch" || r.Action.Args["app"] != "firefox" {
		t.Fatalf("app result: %+v", r)
	}
	if r := top("close window"); len(r.Bound) != 1 || r.Bound[0] != "SUPER+Q" {
		t.Fatalf("bound: %+v", r)
	}
	if res, _ := a.Search("bind a key", 5); len(res) != 0 {
		t.Fatalf("stop words only: %+v", res)
	}
}

func TestSetAddUndo(t *testing.T) {
	a, file := testAdvisor(t)
	orig := readFile(t, file)
	r, err := a.Set(SetRequest{Combo: "super+f", Action: "window.fullscreen"})
	if err != nil {
		t.Fatal(err)
	}
	after := readFile(t, file)
	if !strings.Contains(after, `"name": "Toggle fullscreen"`) || r.Undo == nil || r.Undo.Tool != "binds_undo" {
		t.Fatalf("set: %+v\n%s", r, after)
	}
	if !strings.Contains(after, "{\n          \"key\": \"F\",\n          \"modifiers\": [\n            \"SUPER\"\n          ]\n        }") {
		t.Fatalf("new bind not in the shell's layout:\n%s", after)
	}
	if chk, _ := a.Check("SUPER+F"); chk.Free {
		t.Fatal("SUPER+F must be taken now")
	}
	again, err := a.Set(SetRequest{Combo: "SUPER+F", Action: "window.fullscreen"})
	if err != nil || again.Undo != nil || readFile(t, file) != after {
		t.Fatalf("setting the same bind twice must be a no-op: %+v %v", again, err)
	}
	u, err := a.Undo(r.Undo.Token)
	if err != nil {
		t.Fatal(err)
	}
	if readFile(t, file) != orig {
		t.Fatal("undo must restore the file byte for byte")
	}
	if _, err := a.Undo(r.Undo.Token); !errors.Is(err, ErrStale) {
		t.Fatalf("second undo: want ErrStale, got %v", err)
	}
	if _, err := a.Undo(u.Undo.Token); err != nil || readFile(t, file) != after {
		t.Fatalf("redo: %v", err)
	}
}

func TestSetConflicts(t *testing.T) {
	a, file := testAdvisor(t)
	orig := readFile(t, file)
	var ce *ConflictError
	if _, err := a.Set(SetRequest{Combo: "SUPER+A", Action: "window.fullscreen"}); !errors.As(err, &ce) || ce.Fixed {
		t.Fatalf("want a shell conflict, got %v", err)
	}
	if _, err := a.Set(SetRequest{Combo: "SUPER+P", Action: "window.fullscreen", Replace: true}); !errors.As(err, &ce) || !ce.Fixed {
		t.Fatalf("want a compositor conflict, got %v", err)
	}
	if readFile(t, file) != orig {
		t.Fatal("refused edits must not write")
	}
	r, err := a.Set(SetRequest{Combo: "SUPER+A", Action: "window.fullscreen", Replace: true})
	if err != nil {
		t.Fatal(err)
	}
	doc, _ := loadDocument(file, "yozakura")
	if !doc.isDisabled("system.reload") || !doc.isDisabled("assistant") {
		t.Fatalf("assistant must be switched off: %v", doc.disabled)
	}
	if len(r.Changes) != 2 {
		t.Fatalf("changes: %v", r.Changes)
	}
	if _, err := a.Undo(r.Undo.Token); err != nil || readFile(t, file) != orig {
		t.Fatalf("undo replace: %v", err)
	}
}

func TestSetCoreRebindAndArgs(t *testing.T) {
	a, file := testAdvisor(t)
	orig := readFile(t, file)
	r, err := a.Set(SetRequest{Combo: "SUPER+R", Action: "yozakura.dashboard"})
	if err != nil {
		t.Fatal(err)
	}
	doc, _ := loadDocument(file, "yozakura")
	raw, _ := doc.core("dashboard")
	if !strings.Contains(string(raw), `"R"`) || len(doc.custom) != 4 {
		t.Fatalf("core rebind: %s", raw)
	}
	if _, err := a.Undo(r.Undo.Token); err != nil || readFile(t, file) != orig {
		t.Fatalf("undo core: %v", err)
	}
	if _, err := a.Set(SetRequest{Combo: "SUPER+R", Action: "yozakura.dashboard", Additional: true}); err != nil {
		t.Fatal(err)
	}
	doc, _ = loadDocument(file, "yozakura")
	if len(doc.custom) != 5 {
		t.Fatal("additional must add a custom bind")
	}
	if _, err := a.Set(SetRequest{Combo: "SUPER+O", Action: "apps.launch"}); err == nil || !strings.Contains(err.Error(), "app") {
		t.Fatalf("apps.launch without app: %v", err)
	}
	if _, err := a.Set(SetRequest{Combo: "SUPER+O", Action: "apps.launch", Args: map[string]any{"app": "firefox", "x": 1}}); err == nil {
		t.Fatal("unknown argument must be refused")
	}
	if _, err := a.Set(SetRequest{Combo: "SUPER+O", Action: "nope.nope"}); err == nil {
		t.Fatal("unknown action must be refused")
	}
	r, err = a.Set(SetRequest{Combo: "SUPER+O", Action: "apps.launch", Args: map[string]any{"app": "firefox"}})
	if err != nil || r.Label != "Open app · firefox" {
		t.Fatalf("apps.launch: %+v %v", r, err)
	}
}

func TestSpecialBindsAreReadOnly(t *testing.T) {
	a, file := testAdvisor(t)
	orig := readFile(t, file)
	var ce *ConflictError
	if _, err := a.Set(SetRequest{Combo: "SUPER+CTRL+T", Action: "window.close", Replace: true}); !errors.As(err, &ce) || !ce.Fixed || !strings.Contains(err.Error(), "special_update") {
		t.Fatalf("special conflict: %v", err)
	}
	if _, err := a.Remove("SUPER+CTRL+T", ""); err == nil || !strings.Contains(err.Error(), "special workspace") {
		t.Fatalf("special remove: %v", err)
	}
	if readFile(t, file) != orig {
		t.Fatal("nothing may be written")
	}
}

func TestRemove(t *testing.T) {
	a, file := testAdvisor(t)
	orig := readFile(t, file)
	r, err := a.Remove("SUPER+Q", "")
	if err != nil {
		t.Fatal(err)
	}
	doc, _ := loadDocument(file, "yozakura")
	if len(doc.custom) != 3 {
		t.Fatal("close window bind must be gone")
	}
	if _, err := a.Undo(r.Undo.Token); err != nil || readFile(t, file) != orig {
		t.Fatalf("undo remove: %v", err)
	}
	if _, err := a.Remove("SUPER+P", ""); err == nil || !strings.Contains(err.Error(), "compositor") {
		t.Fatalf("compositor bind: %v", err)
	}
	if _, err := a.Remove("SUPER+Q", "window.fullscreen"); err == nil {
		t.Fatal("action filter must not match")
	}
	r, err = a.Remove("SUPER+V", "")
	if err != nil {
		t.Fatal(err)
	}
	doc, _ = loadDocument(file, "yozakura")
	if !doc.isDisabled("clipboard") {
		t.Fatal("core clipboard bind must be switched off")
	}
	if _, err := a.Undo(r.Undo.Token); err != nil || readFile(t, file) != orig {
		t.Fatalf("undo core remove: %v", err)
	}
}

func TestRemoveOneKeyOfMultiKeyBind(t *testing.T) {
	a, file := testAdvisor(t)
	doc, _ := loadDocument(file, "yozakura")
	raw := []byte(`{"name":"Two","keys":[{"key":"J","modifiers":["SUPER"]},{"key":"K","modifiers":["SUPER"]}],"actions":[{"args":{},"id":"window.close","layouts":[]}],"enabled":true}`)
	doc.custom = append(doc.custom, raw)
	if err := doc.save(file); err != nil {
		t.Fatal(err)
	}
	before := readFile(t, file)
	r, err := a.Remove("SUPER+J", "")
	if err != nil {
		t.Fatal(err)
	}
	doc, _ = loadDocument(file, "yozakura")
	last := string(doc.custom[len(doc.custom)-1])
	if strings.Contains(last, `"J"`) || !strings.Contains(last, `"K"`) || len(doc.custom) != 5 {
		t.Fatalf("multi-key bind: %s", last)
	}
	if _, err := a.Undo(r.Undo.Token); err != nil || readFile(t, file) != before {
		t.Fatalf("undo: %v", err)
	}
}

func TestMissingFileIsCreated(t *testing.T) {
	a, _ := testAdvisor(t)
	a.File = filepath.Join(t.TempDir(), "binds.json")
	if _, err := a.Set(SetRequest{Combo: "SUPER+F", Action: "window.fullscreen"}); err != nil {
		t.Fatal(err)
	}
	if got := readFile(t, a.File); !strings.HasPrefix(got, "{\n  \"custom\": [") {
		t.Fatalf("new file:\n%s", got)
	}
}

func TestParseDaemonBinds(t *testing.T) {
	if _, err := ParseDaemonBinds([]byte("Error: feature not supported on this compositor\n")); err == nil || !strings.Contains(err.Error(), "not supported") {
		t.Fatalf("error reply: %v", err)
	}
	b, err := ParseDaemonBinds([]byte(`[{"modifiers":["SUPER"],"key":"Q","dispatcher":"killactive"}]`))
	if err != nil || len(b) != 1 || b[0].Key != "Q" {
		t.Fatalf("%v %v", b, err)
	}
}
