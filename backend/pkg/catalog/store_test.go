package catalog

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
)

func newStore(t *testing.T) *Store {
	dir := t.TempDir()
	return &Store{Cat: load(t), File: func(d string) string { return filepath.Join(dir, d+".json") }}
}

func TestStoreSetKeepsOrderAndUnknownKeys(t *testing.T) {
	s := newStore(t)
	must(t, os.WriteFile(s.File("bar"), []byte(`{"zeta": 1, "position": "top", "alpha": {"b": 1, "a": 2}}`), 0o644))
	ch, err := s.Set("bar.position", "left", false)
	must(t, err)
	assert.Equal(t, []Change{{Key: "bar.position", Old: "top", New: "left"}}, ch)
	data, _ := os.ReadFile(s.File("bar"))
	assert.Equal(t, "{\n  \"zeta\": 1,\n  \"position\": \"left\",\n  \"alpha\": {\n    \"b\": 1,\n    \"a\": 2\n  }\n}", string(data))

	ch, err = s.Set("bar.layout.style", "islands", false)
	must(t, err)
	assert.Equal(t, "classic", ch[0].Old, "old value falls back to the default")
	v, explicit, err := s.Get("bar.layout.style")
	must(t, err)
	assert.Equal(t, "islands", v)
	assert.True(t, explicit)
	v, explicit, _ = s.Get("bar.compact")
	assert.Equal(t, false, v)
	assert.False(t, explicit)
}

func TestStoreNoOpDoesNotWrite(t *testing.T) {
	s := newStore(t)
	must(t, os.WriteFile(s.File("dock"), []byte(`{"enabled": true}`), 0o644))
	before, _ := os.Stat(s.File("dock"))
	ch, err := s.Set("dock.enabled", true, false)
	must(t, err)
	assert.Empty(t, ch)
	after, _ := os.Stat(s.File("dock"))
	assert.Equal(t, before.ModTime(), after.ModTime())
	data, _ := os.ReadFile(s.File("dock"))
	assert.Equal(t, `{"enabled": true}`, string(data))
}

func TestStoreArrayItems(t *testing.T) {
	s := newStore(t)
	_, err := s.Set("bar.layout.left.0", "clock", false)
	must(t, err)
	v, _, _ := s.Get("bar.layout.left")
	assert.Equal(t, []any{"clock", "workspaces", "layoutSelector", "pin"}, v)
	_, err = s.Set("bar.layout.left[4]", "battery", false)
	must(t, err, "index == len appends")
	item, _, err := s.Get("bar.layout.left.4")
	must(t, err)
	assert.Equal(t, "battery", item)
	_, err = s.Set("bar.layout.left.9", "power", false)
	assert.ErrorContains(t, err, "out of range")
	_, err = s.Set("bar.layout.left.0", "workspaces", false)
	assert.ErrorContains(t, err, "duplicate")
	_, _, err = s.Get("bar.layout.left.20")
	assert.Error(t, err)
}

func TestStoreReset(t *testing.T) {
	s := newStore(t)
	_, err := s.Set("notch.liveActivities", map[string]any{"enabled": false, "maxVisible": 2.0}, false)
	must(t, err)
	_, err = s.Set("bar.position", "bottom", false)
	must(t, err)
	ch, err := s.Reset("notch.liveActivities")
	must(t, err)
	assert.Len(t, ch, 2)
	v, _, _ := s.Get("notch.liveActivities.maxVisible")
	assert.Equal(t, 4.0, v)
	_, err = s.Reset("bar.layout.left.0")
	assert.Error(t, err)

	ch, err = s.ResetDomain("bar")
	must(t, err)
	assert.Equal(t, []Change{{Key: "bar.position", Old: "bottom", New: "top"}}, ch)
	cur, err := s.Current("bar")
	must(t, err)
	assert.Equal(t, Compact(s.Cat.DomainDefault("bar")), Compact(cur))
	data, _ := os.ReadFile(s.File("bar"))
	assert.Regexp(t, `^\{\n  "position": "top",\n  "launcherIcon"`, string(data), "defaults written in file order")
	_, err = s.Current("nope")
	assert.Error(t, err)
}

func TestStoreBrokenFile(t *testing.T) {
	s := newStore(t)
	must(t, os.WriteFile(s.File("bar"), []byte(`{broken`), 0o644))
	_, err := s.Set("bar.position", "left", false)
	assert.Error(t, err)
	data, _ := os.ReadFile(s.File("bar"))
	assert.Equal(t, `{broken`, string(data), "a file that does not parse is never overwritten")
}

func TestStoreWriteKeepsSymlinkedFile(t *testing.T) {
	s := newStore(t)
	real := filepath.Join(t.TempDir(), "dotfiles-bar.json")
	must(t, os.WriteFile(real, []byte(`{"position": "top"}`), 0o644))
	must(t, os.Symlink(real, s.File("bar")))
	_, err := s.Set("bar.position", "left", false)
	must(t, err)
	st, err := os.Lstat(s.File("bar"))
	must(t, err)
	assert.True(t, st.Mode()&os.ModeSymlink != 0, "a symlinked config file stays a symlink")
	data, _ := os.ReadFile(real)
	assert.Contains(t, string(data), `"left"`, "the link target is updated")
}

// Long values that share their first 120 JSON bytes are still different
// (equalJSON once compared truncated renderings and skipped the write).
func TestEqualJSONComparesWholeValues(t *testing.T) {
	long := strings.Repeat("x", 200)
	assert.False(t, equalJSON([]any{long}, []any{long, "y"}))
	assert.True(t, equalJSON(map[string]any{"a": long}, map[string]any{"a": long}))
}

// SetAll validates everything before one write: an invalid value writes
// nothing, valid ones land together.
func TestStoreSetAllIsAllOrNothing(t *testing.T) {
	s := newStore(t)
	if _, err := s.SetAll([]KV{{"keyboard.repeatRate", float64(50)}, {"keyboard.repeatDelay", float64(5)}}, false); err == nil {
		t.Fatal("out-of-range delay must fail")
	}
	if _, err := os.Stat(s.File("keyboard")); err == nil {
		t.Fatal("a failing SetAll must write nothing")
	}
	if err := s.Check("keyboard.repeatRate", float64(500), false); err == nil {
		t.Fatal("Check must validate the range")
	}
	if _, err := s.SetAll([]KV{{"keyboard.repeatRate", float64(50)}, {"keyboard.managed", true}}, false); err != nil {
		t.Fatal(err)
	}
	if v, _, _ := s.Get("keyboard.repeatRate"); v != float64(50) {
		t.Fatalf("rate %v", v)
	}
	if v, _, _ := s.Get("keyboard.managed"); v != true {
		t.Fatalf("managed %v", v)
	}
	if _, err := s.SetAll([]KV{{"keyboard.repeatRate", float64(60)}, {"bar.position", "top"}}, false); err == nil {
		t.Fatal("keys of two domains must fail")
	}
}
