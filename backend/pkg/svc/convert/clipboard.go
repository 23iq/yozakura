package convert

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"time"

	conv "yozakura/backend/pkg/convert"
	"yozakura/backend/pkg/proc"
)

// Clipboard reads and writes the Wayland clipboard.
type Clipboard interface {
	Types() ([]string, error)
	Read(mime string) ([]byte, error)
	// Write offers data under mime (the serving child is not waited for).
	Write(mime string, data []byte) error
}

// wlClipboard uses wl-paste / wl-copy.
type wlClipboard struct{}

func (wlClipboard) Types() ([]string, error) {
	out, err := proc.RunWith(context.Background(), proc.Options{Timeout: 3 * time.Second}, "wl-paste", "--list-types")
	if err != nil {
		return nil, errors.New("the clipboard is empty")
	}
	return strings.Fields(string(out)), nil
}

func (wlClipboard) Read(mime string) ([]byte, error) {
	return proc.RunWith(context.Background(), proc.Options{Timeout: 10 * time.Second}, "wl-paste", "--no-newline", "--type", mime)
}

// Write must not wait on wl-copy: it forks a clipboard-serving child that
// lives until the content is replaced.
func (wlClipboard) Write(mime string, data []byte) error {
	cmd := proc.Command(context.Background(), "wl-copy", "--type", mime)
	cmd.Stdin = bytes.NewReader(data)
	return proc.StartReaped(cmd)
}

// pasteDir holds image data pasted without a file.
func (s *Service) pasteDir() string { return filepath.Join(s.o.CacheDir, "pasted") }

func (s *Service) isPasted(path string) bool {
	return s.o.CacheDir != "" && filepath.Dir(path) == s.pasteDir()
}

// pastedOutDir: results of pasted images go to ~/Pictures (else home),
// never into the cache.
func (s *Service) pastedOutDir() string {
	if pics := filepath.Join(s.o.Home, "Pictures"); isDir(pics) {
		return pics
	}
	return s.o.Home
}

func isDir(p string) bool {
	st, err := os.Stat(p)
	return err == nil && st.IsDir()
}

func (s *Service) paste(json.RawMessage) (any, error) {
	paths, err := s.Paste()
	if err != nil {
		return nil, err
	}
	return map[string]any{"paths": paths}, nil
}

// Paste returns the files on the clipboard: a uri-list, plain-text
// absolute paths, or image data (saved to a file first).
func (s *Service) Paste() ([]string, error) {
	cb := s.o.Clipboard
	types, err := cb.Types()
	if err != nil {
		return nil, err
	}
	has := func(m string) bool {
		for _, t := range types {
			if t == m {
				return true
			}
		}
		return false
	}
	if has("text/uri-list") {
		if data, err := cb.Read("text/uri-list"); err == nil {
			if paths := ParseURIList(string(data)); len(paths) > 0 {
				return paths, nil
			}
		}
	}
	for _, mime := range []string{"image/png", "image/jpeg", "image/webp", "image/gif", "image/bmp", "image/tiff", "image/avif", "image/svg+xml"} {
		if has(mime) {
			data, err := cb.Read(mime)
			if err != nil || len(data) == 0 {
				continue
			}
			p, err := s.savePasted(data, mime)
			if err != nil {
				return nil, err
			}
			return []string{p}, nil
		}
	}
	for _, mime := range []string{"text/plain;charset=utf-8", "text/plain", "UTF8_STRING"} {
		if has(mime) {
			if data, err := cb.Read(mime); err == nil {
				if paths := existingPaths(string(data)); len(paths) > 0 {
					return paths, nil
				}
			}
			break
		}
	}
	return nil, errors.New("no file on the clipboard")
}

func (s *Service) savePasted(data []byte, mime string) (string, error) {
	dir := s.pasteDir()
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return "", err
	}
	pruneOld(dir, 24*time.Hour)
	ext := strings.TrimPrefix(mime, "image/")
	if f, ok := conv.Lookup(strings.TrimSuffix(ext, "+xml")); ok {
		ext = f.Ext()
	}
	name := "pasted-" + time.Now().Format("2006-01-02-150405")
	for i := 0; ; i++ {
		p := filepath.Join(dir, name+"."+ext)
		if i > 0 {
			p = filepath.Join(dir, fmt.Sprintf("%s-%d.%s", name, i, ext))
		}
		f, err := os.OpenFile(p, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0o600)
		if errors.Is(err, os.ErrExist) {
			continue
		}
		if err != nil {
			return "", err
		}
		_, err = f.Write(data)
		if cerr := f.Close(); err == nil {
			err = cerr
		}
		return p, err
	}
}

// pruneOld removes pasted files older than age.
func pruneOld(dir string, age time.Duration) {
	entries, _ := os.ReadDir(dir)
	for _, e := range entries {
		if info, err := e.Info(); err == nil && time.Since(info.ModTime()) > age {
			os.Remove(filepath.Join(dir, e.Name()))
		}
	}
}

// ParseURIList returns the local paths of a text/uri-list.
func ParseURIList(s string) []string {
	var out []string
	for _, line := range strings.Split(s, "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		u, err := url.Parse(line)
		if err != nil || u.Scheme != "file" || (u.Host != "" && u.Host != "localhost") {
			continue
		}
		out = append(out, u.Path)
	}
	return out
}

func existingPaths(s string) []string {
	var out []string
	for _, line := range strings.Split(s, "\n") {
		p := strings.TrimSpace(line)
		if p == "" {
			continue
		}
		if strings.HasPrefix(p, "file://") {
			out = append(out, ParseURIList(p)...)
			continue
		}
		if !filepath.IsAbs(p) {
			return nil
		}
		if st, err := os.Stat(p); err != nil || st.IsDir() {
			return nil
		}
		out = append(out, p)
	}
	return out
}

func (s *Service) copy(params json.RawMessage) (any, error) {
	var p struct {
		Path string `json:"path"`
	}
	if err := json.Unmarshal(params, &p); err != nil || p.Path == "" {
		return nil, errors.New("path is required")
	}
	return map[string]any{}, s.Copy(p.Path)
}

// Copy puts a result on the clipboard: an image as image data (pastes into
// chats and editors), anything else as a file (file managers).
func (s *Service) Copy(path string) error {
	if !filepath.IsAbs(path) {
		return errors.New("path must be absolute")
	}
	st, err := os.Stat(path)
	if err != nil || st.IsDir() {
		return errors.New("not found")
	}
	if fm, ok := conv.Detect(path); ok && fm.Kind == conv.KindImage && fm.ID != "svg" && st.Size() < 64<<20 {
		data, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		return s.o.Clipboard.Write(imageMime(fm.ID), data)
	}
	u := url.URL{Scheme: "file", Path: path}
	return s.o.Clipboard.Write("text/uri-list", []byte(u.String()+"\r\n"))
}

func imageMime(id string) string {
	switch id {
	case "jpg":
		return "image/jpeg"
	case "ico":
		return "image/vnd.microsoft.icon"
	}
	return "image/" + id
}
