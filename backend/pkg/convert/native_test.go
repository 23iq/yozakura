package convert

import (
	"image"
	"image/color"
	"image/png"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func roundTrip(t *testing.T, from, src, to string) (string, error) {
	t.Helper()
	dir := t.TempDir()
	in := write(t, dir, "in."+from, []byte(src))
	out := filepath.Join(dir, "out."+to)
	if err := ConvertNative(in, from, out, to, QualityBalanced); err != nil {
		return "", err
	}
	b, _ := os.ReadFile(out)
	return string(b), nil
}

func TestJSONToYAMLKeepsOrderAndTypes(t *testing.T) {
	got, err := roundTrip(t, "json", `{"zeta": 1, "alpha": "x", "zip": "01234", "on": "yes", "list": [true, null, 1.5], "nested": {"b": 2, "a": 1}}`, "yaml")
	if err != nil {
		t.Fatal(err)
	}
	want := "zeta: 1\nalpha: x\nzip: \"01234\"\non: yes\nlist:\n  - true\n  - null\n  - 1.5\nnested:\n  b: 2\n  a: 1\n"
	if got != want {
		t.Fatalf("got\n%s\nwant\n%s", got, want)
	}
}

func TestYAMLToJSON(t *testing.T) {
	got, err := roundTrip(t, "yaml", "b: &x [1, two]\na:\n  c: *x\n  d: ~\n", "json")
	if err != nil {
		t.Fatal(err)
	}
	want := "{\n  \"b\": [\n    1,\n    \"two\"\n  ],\n  \"a\": {\n    \"c\": [\n      1,\n      \"two\"\n    ],\n    \"d\": null\n  }\n}\n"
	if got != want {
		t.Fatalf("got\n%s", got)
	}
}

func TestTOML(t *testing.T) {
	got, err := roundTrip(t, "toml", "title = \"x\"\n[owner]\nname = \"n\"\n", "json")
	if err != nil || !strings.Contains(got, "\"owner\": {") || !strings.Contains(got, "\"name\": \"n\"") {
		t.Fatalf("toml->json: %v %s", err, got)
	}
	got, err = roundTrip(t, "json", `{"a": {"b": 1}}`, "toml")
	if err != nil || !strings.Contains(got, "[a]") || !strings.Contains(got, "b = 1") {
		t.Fatalf("json->toml: %v %s", err, got)
	}
	if _, err := roundTrip(t, "json", `[1, 2]`, "toml"); err == nil || !strings.Contains(err.Error(), "object at the top") {
		t.Fatalf("array to toml: %v", err)
	}
}

func TestCSV(t *testing.T) {
	got, err := roundTrip(t, "csv", "name,zip\nAna,01234\n\"B, C\",9\n", "json")
	if err != nil {
		t.Fatal(err)
	}
	want := "[\n  {\n    \"name\": \"Ana\",\n    \"zip\": \"01234\"\n  },\n  {\n    \"name\": \"B, C\",\n    \"zip\": \"9\"\n  }\n]\n"
	if got != want {
		t.Fatalf("csv->json:\n%s", got)
	}
	got, err = roundTrip(t, "json", `[{"a": 1, "b": {"x": [1]}}, {"c": "z", "a": null}]`, "csv")
	if err != nil || got != "a,b,c\n1,\"{\"\"x\"\":[1]}\",\n,,z\n" {
		t.Fatalf("json->csv: %v %q", err, got)
	}
	if _, err := roundTrip(t, "json", `[1, 2]`, "csv"); err == nil {
		t.Fatal("scalars to csv accepted")
	}
}

func TestBadInputSaysWhy(t *testing.T) {
	if _, err := roundTrip(t, "json", `{"a":`, "yaml"); err == nil || !strings.Contains(err.Error(), "JSON") {
		t.Fatalf("bad json: %v", err)
	}
	if _, err := roundTrip(t, "yaml", "a: [", "json"); err == nil || !strings.Contains(err.Error(), "YAML") {
		t.Fatalf("bad yaml: %v", err)
	}
}

func TestNativeImages(t *testing.T) {
	dir := t.TempDir()
	img := image.NewNRGBA(image.Rect(0, 0, 4, 3))
	img.Set(1, 1, color.NRGBA{255, 0, 0, 128})
	src := filepath.Join(dir, "a.png")
	f, _ := os.Create(src)
	_ = png.Encode(f, img)
	f.Close()
	for _, to := range []string{"jpg", "gif", "bmp", "tiff", "png"} {
		out := filepath.Join(dir, "out."+to)
		if err := ConvertNative(src, "png", out, to, QualityBest); err != nil {
			t.Fatalf("png->%s: %v", to, err)
		}
		g, _ := os.Open(out)
		dec, format, err := image.Decode(g)
		g.Close()
		if err != nil || dec.Bounds().Dx() != 4 {
			t.Fatalf("png->%s unreadable: %v %s", to, err, format)
		}
		if fm, _ := Detect(out); fm.ID != to {
			t.Fatalf("png->%s detected as %s", to, fm.ID)
		}
	}
	if err := ConvertNative(write(t, dir, "bad.png", []byte("nope")), "png", filepath.Join(dir, "x.jpg"), "jpg", QualityBalanced); err == nil {
		t.Fatal("junk decoded")
	}
}
