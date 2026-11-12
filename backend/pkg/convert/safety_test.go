package convert

import (
	"archive/zip"
	"bytes"
	"context"
	"encoding/binary"
	"hash/crc32"
	"image"
	"image/png"
	"io"
	"os"
	"path/filepath"
	"strings"
	"syscall"
	"testing"
	"time"

	"yozakura/backend/pkg/proc"
)

// "%d" in a file name is a pattern to ImageMagick and ffmpeg: converting
// y%d.png must convert y%d.png, not y0.png next to it.
func TestPercentInFileNameIsInert(t *testing.T) {
	need(t, EngineMagick)
	dir := t.TempDir()
	odd, other := filepath.Join(dir, "y%d.png"), filepath.Join(dir, "y0.png")
	pngFile(t, odd, 3, 2, "")
	pngFile(t, other, 7, 5, "")
	out := filepath.Join(t.TempDir(), "r.bmp")
	_ = os.WriteFile(out, runPlan(t, odd, "png", "bmp"), 0o644)
	w, _ := proc.Run(context.Background(), realTools.Prog(EngineMagick), out, "-format", "%w", "info:")
	if strings.TrimSpace(string(w)) != "3" {
		t.Fatalf("converted the wrong file: width %q", w)
	}
	if realTools.Has(EngineFFmpeg) {
		p, _ := BuildPlan(Request{Src: odd, From: "png", To: "tga"}, NewTools(map[Engine]string{EngineFFmpeg: realTools.Prog(EngineFFmpeg)}, nil), t.TempDir(), PlanOptions{})
		if err := p.Run(context.Background(), nil); err != nil {
			t.Fatalf("ffmpeg with %%d name: %v", err)
		}
		w, _ := proc.Run(context.Background(), realTools.Prog(EngineMagick), p.Out, "-format", "%w", "info:")
		if strings.TrimSpace(string(w)) != "3" {
			t.Fatalf("ffmpeg converted the wrong file: width %q", w)
		}
	}
}

func zipText(t *testing.T, data []byte) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "x.zip")
	_ = os.WriteFile(path, data, 0o644)
	r, err := zip.OpenReader(path)
	if err != nil {
		t.Fatal(err)
	}
	defer r.Close()
	var b strings.Builder
	for _, f := range r.File {
		b.WriteString(f.Name + "\n")
		rc, _ := f.Open()
		c, _ := io.ReadAll(rc)
		rc.Close()
		b.Write(c)
	}
	return b.String()
}

// pandoc never embeds a file outside the document's folder nor fetches a
// URL; an image next to the document (or below it) is embedded.
func TestPandocPullsOnlyTheDocumentsOwnFiles(t *testing.T) {
	need(t, EnginePandoc)
	outside := t.TempDir()
	secret := filepath.Join(outside, "secret.png")
	pngFile(t, secret, 2, 2, "SECRET-MARKER")
	doc := t.TempDir()
	_ = os.Mkdir(filepath.Join(doc, "img"), 0o755)
	pngFile(t, filepath.Join(doc, "img", "pic.png"), 2, 2, "LOCAL-MARKER")
	_ = os.Symlink(secret, filepath.Join(doc, "img", "sneaky.png"))
	md := "---\nepub-cover-image: " + secret + "\n---\n# t\n\n![a](" + secret + ")\n\n![b](../" + filepath.Base(outside) + "/secret.png)\n\n" +
		"![c](img/sneaky.png)\n\n![d](https://example.invalid/x.png)\n\n<img src=\"" + secret + "\">\n\n![local](img/pic.png)\n"
	src := filepath.Join(doc, "notes.md")
	_ = os.WriteFile(src, []byte(md), 0o644)
	for _, to := range []string{"docx", "epub", "odt"} {
		got := zipText(t, runPlan(t, src, "md", to))
		if strings.Contains(got, "SECRET-MARKER") {
			t.Errorf("md->%s embedded a file outside the document's folder", to)
		}
		if !strings.Contains(got, "LOCAL-MARKER") {
			t.Errorf("md->%s dropped the document's own image", to)
		}
	}
	if realTools.Has(EngineSoffice) {
		pdf := runPlan(t, src, "md", "pdf")
		if len(pdf) < 100 {
			t.Fatal("md->pdf wrote nothing")
		}
	}
	// a container (docx) is converted in the sandbox and keeps its media
	docx := filepath.Join(t.TempDir(), "d.docx")
	_ = os.WriteFile(docx, runPlan(t, src, "md", "docx"), 0o644)
	if !strings.Contains(zipText(t, runPlan(t, docx, "docx", "epub")), "LOCAL-MARKER") {
		t.Error("docx->epub lost the embedded image")
	}
}

func TestLocalResource(t *testing.T) {
	root := t.TempDir()
	_ = os.MkdirAll(filepath.Join(root, "a"), 0o755)
	for target, want := range map[string]bool{
		"a/x.png": true, "x.png": true, "data:image/png;base64,AAA": true, "a/../x.png": true,
		"../x.png": false, "/etc/passwd": false, "~/x.png": false, "file:///etc/passwd": false,
		"https://example.com/x.png": false, "//example.com/x.png": false, "%2e%2e/x.png": false, "": false,
	} {
		if got := LocalResource(target, root); got != want {
			t.Errorf("%q: %v, want %v", target, got, want)
		}
	}
}

// A hung step ends at its timeout with a clear error; its group is gone.
func TestStepTimeoutKillsTheGroup(t *testing.T) {
	work := t.TempDir()
	p := &Plan{Work: work, Out: filepath.Join(work, "out.txt"), Steps: []Step{{
		Prog: "/bin/sh", Args: []string{"-c", "sleep 300 & sleep 300"}, Out: "out.txt", Timeout: 300 * time.Millisecond}}}
	start := time.Now()
	err := p.Run(context.Background(), nil)
	if err == nil || !strings.Contains(err.Error(), "timed out") || time.Since(start) > 10*time.Second {
		t.Fatalf("timeout: %v after %s", err, time.Since(start))
	}
}

// Groups recorded by a dead run are killed on the next start.
func TestKillStaleGroups(t *testing.T) {
	dir := t.TempDir()
	cmd := proc.Command(context.Background(), "sleep", "300")
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	if err := cmd.Start(); err != nil {
		t.Fatal(err)
	}
	pgid := cmd.Process.Pid
	TrackGroupsIn(dir)
	release := trackGroup(pgid, "sleep")
	_ = release // the "daemon" dies without releasing
	TrackGroupsIn("")
	// a record whose group runs something else is left alone
	_ = os.WriteFile(filepath.Join(dir, "999999-1"), []byte("sleep"), 0o600)
	// a live owner's groups are left alone
	if n := KillStaleGroups(dir); n != 0 {
		t.Fatalf("killed a live owner's group")
	}
	if n := killStaleGroups(dir, func(int) bool { return false }); n != 1 {
		t.Fatalf("killed %d groups", n)
	}
	done := make(chan error, 1)
	go func() { done <- cmd.Wait() }()
	select {
	case <-done:
	case <-time.After(5 * time.Second):
		_ = cmd.Process.Kill()
		t.Fatal("stale group still running")
	}
	if entries, _ := os.ReadDir(dir); len(entries) != 0 {
		t.Fatal("records left")
	}
}

// pngFile writes a w x h PNG with an optional tEXt chunk carrying marker
// (written from Go: ImageMagick would expand a %d in the name).
func pngFile(t *testing.T, path string, w, h int, marker string) {
	t.Helper()
	var b bytes.Buffer
	if err := png.Encode(&b, image.NewRGBA(image.Rect(0, 0, w, h))); err != nil {
		t.Fatal(err)
	}
	data := b.Bytes()
	if marker != "" {
		body := append([]byte("Comment\x00"), marker...)
		var c bytes.Buffer
		_ = binary.Write(&c, binary.BigEndian, uint32(len(body)))
		c.WriteString("tEXt")
		c.Write(body)
		_ = binary.Write(&c, binary.BigEndian, crc32.ChecksumIEEE(append([]byte("tEXt"), body...)))
		data = append(append(append([]byte{}, data[:33]...), c.Bytes()...), data[33:]...)
	}
	if err := os.WriteFile(path, data, 0o644); err != nil {
		t.Fatal(err)
	}
}
