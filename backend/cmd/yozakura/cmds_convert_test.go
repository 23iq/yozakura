package main

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	conv "yozakura/backend/pkg/convert"
	convertsvc "yozakura/backend/pkg/svc/convert"
)

func testConvertEnv(t *testing.T) convertEnv {
	t.Helper()
	tools := conv.NewTools(nil, nil) // native engines only
	s := convertsvc.New(convertsvc.Options{Detect: func() *conv.Tools { return tools }, CacheDir: t.TempDir(), Home: t.TempDir()})
	return convertEnv{svc: s, tick: 5 * time.Millisecond, tools: s.Tools}
}

func TestConvertCLI(t *testing.T) {
	dir := t.TempDir()
	src := filepath.Join(dir, "data.json")
	_ = os.WriteFile(src, []byte(`{"k": "v"}`), 0o644)
	var out, errOut bytes.Buffer
	if code := runConvert([]string{src}, testConvertEnv(t), &out, &errOut); code != 0 {
		t.Fatalf("default target: %d %s", code, errOut.String())
	}
	if !strings.Contains(out.String(), "data.yaml") {
		t.Fatalf("out: %s", out.String())
	}
	out.Reset()
	outDir := t.TempDir()
	if code := runConvert([]string{src, "--to=toml", "--out", outDir, "--json"}, testConvertEnv(t), &out, &errOut); code != 0 {
		t.Fatalf("--to toml: %s", errOut.String())
	}
	var jobs []convertsvc.Job
	if json.Unmarshal(out.Bytes(), &jobs) != nil || len(jobs) != 1 || jobs[0].Output != filepath.Join(outDir, "data.toml") {
		t.Fatalf("json: %s", out.String())
	}
	errOut.Reset()
	if code := runConvert([]string{src, "--to", "nope"}, testConvertEnv(t), &out, &errOut); code != 2 || !strings.Contains(errOut.String(), "unknown format") {
		t.Fatalf("bad format: %d %s", code, errOut.String())
	}
	if code := runConvert(nil, testConvertEnv(t), &out, &errOut); code != 2 {
		t.Fatal("no args")
	}
	// a failure exits 1 with a short reason
	errOut.Reset()
	_ = os.WriteFile(filepath.Join(dir, "a.flac"), []byte("fLaC\x00"), 0o644)
	if code := runConvert([]string{filepath.Join(dir, "a.flac")}, testConvertEnv(t), &out, &errOut); code != 1 || !strings.Contains(errOut.String(), "needs ffmpeg") {
		t.Fatalf("missing tool: %d %s", code, errOut.String())
	}
}

func TestConvertFormatsCLI(t *testing.T) {
	var out, errOut bytes.Buffer
	if runConvert([]string{"formats"}, testConvertEnv(t), &out, &errOut) != 0 || !strings.Contains(out.String(), "data:") {
		t.Fatalf("%s", out.String())
	}
	dir := t.TempDir()
	src := filepath.Join(dir, "a.flac")
	_ = os.WriteFile(src, []byte("fLaC"), 0o644)
	out.Reset()
	runConvert([]string{"formats", src}, testConvertEnv(t), &out, &errOut)
	if !strings.Contains(out.String(), "FLAC (audio)") || !strings.Contains(out.String(), "needs ffmpeg") {
		t.Fatalf("%s", out.String())
	}
	out.Reset()
	runConvert([]string{"__formats"}, testConvertEnv(t), &out, &errOut)
	if !strings.Contains(out.String(), "\nwebp\n") {
		t.Fatal("__formats")
	}
	s, _ := completionScript("fish")
	if !strings.Contains(s, "convert __formats") {
		t.Fatal("completion")
	}
}
