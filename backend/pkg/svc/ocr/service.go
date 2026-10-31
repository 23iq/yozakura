package ocr

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os/exec"
	"strings"
	"time"

	"yozakura/backend/pkg/capture"
	"yozakura/backend/pkg/ipc"
	"yozakura/backend/pkg/proc"
)

type Service struct{}

func NewService() *Service {
	return &Service{}
}

func (s *Service) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "ocr",
		Methods: map[string]ipc.HandlerFunc{
			"text":    s.text,
			"barcode": s.barcode,
		},
	})
}

type rectParams struct {
	X      int    `json:"x"`
	Y      int    `json:"y"`
	Width  int    `json:"width"`
	Height int    `json:"height"`
	Langs  string `json:"langs,omitempty"`
}

func (s *Service) text(params json.RawMessage) (any, error) {
	var p rectParams
	if err := json.Unmarshal(params, &p); err != nil {
		return nil, err
	}

	pngBytes, closer, err := capture.RegionPNG("", p.X, p.Y, p.Width, p.Height)
	if err != nil {
		return nil, err
	}
	defer closer()

	langs := p.Langs
	if strings.TrimSpace(langs) == "" {
		langs = "eng+spa"
	}

	if _, err := exec.LookPath("tesseract"); err != nil {
		return nil, fmt.Errorf("tesseract is not installed")
	}
	if listed, lerr := proc.Run(context.Background(), "tesseract", "--list-langs"); lerr == nil {
		if missing := MissingLangs(langs, string(listed)); len(missing) > 0 {
			return nil, fmt.Errorf("tesseract language data missing: %s (install the tesseract language packs)", strings.Join(missing, ", "))
		}
	}

	out, err := proc.RunWith(context.Background(), proc.Options{Timeout: time.Minute, Stdin: bytes.NewReader(pngBytes)},
		"tesseract", "-", "-", "-l", langs)
	if err != nil {
		var pe *proc.Error
		if errors.As(err, &pe) {
			if msg := strings.TrimSpace(pe.Stderr); msg != "" {
				return nil, fmt.Errorf("tesseract: %s", msg)
			}
		}
		return nil, fmt.Errorf("tesseract: %w", err)
	}
	text := strings.TrimSpace(string(out))
	if text != "" {
		copyText(text)
	}
	return map[string]any{"text": text}, nil
}

// MissingLangs returns the languages of langs ("eng+rus") that
// `tesseract --list-langs` output does not list.
func MissingLangs(langs, listed string) []string {
	have := map[string]bool{}
	for _, l := range strings.Split(listed, "\n") {
		if l = strings.TrimSpace(l); l != "" && !strings.HasPrefix(l, "List of") {
			have[l] = true
		}
	}
	var missing []string
	for _, l := range strings.Split(langs, "+") {
		if l = strings.TrimSpace(l); l != "" && !have[l] {
			missing = append(missing, l)
		}
	}
	return missing
}

func (s *Service) barcode(params json.RawMessage) (any, error) {
	var p rectParams
	if err := json.Unmarshal(params, &p); err != nil {
		return nil, err
	}

	pngBytes, closer, err := capture.RegionPNG("", p.X, p.Y, p.Width, p.Height)
	if err != nil {
		return nil, err
	}
	defer closer()

	content, err := decodeBarcode(pngBytes)
	if err != nil {
		return nil, err
	}
	if content != "" {
		copyText(content)
	}
	return map[string]any{"content": content}, nil
}

// copyText spawns wl-copy detached: its clipboard-serving child inherits
// nothing and the handler returns immediately.
func copyText(text string) {
	cmd := exec.CommandContext(context.Background(), "wl-copy", "--type", "text/plain")
	cmd.Stdin = strings.NewReader(text)
	cmd.Stdout = nil
	cmd.Stderr = nil
	if err := cmd.Start(); err != nil {
		return
	}
	go func() { _ = cmd.Wait() }()
}
