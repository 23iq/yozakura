package termlook

import (
	"bytes"
	"errors"
	"fmt"
	"image"
	_ "image/png" // DecodeConfig of PNG logos
	"os"
	"path/filepath"
	"strings"
	"unicode/utf8"
)

// A custom logo (terminal.fastfetchLogoPath) is data from the user: it is
// checked here and only ever reaches fastfetch inside its JSON config,
// never a shell line.

// Size caps of a custom logo.
const (
	MaxTextLogo  = 64 << 10
	MaxImageLogo = 8 << 20
)

// Logo kinds of a checked custom logo.
const (
	LogoText  = "text"  // printed with $1..$5 colour markers
	LogoANSI  = "ansi"  // carries its own colours (only SGR kept, logosafe.go)
	LogoImage = "image" // a PNG: kitty graphics in kitty, the text logo elsewhere
)

// ImageLogoWidth is the width in cells of a picture logo.
const ImageLogoWidth = 20

// Errors a custom logo check reports (the UI shows them by key).
var (
	ErrLogoPath     = errors.New("logo_path")     // empty, relative or with control characters
	ErrLogoMissing  = errors.New("logo_missing")  // not there / not readable
	ErrLogoNotFile  = errors.New("logo_not_file") // a directory, device, ...
	ErrLogoTooLarge = errors.New("logo_too_large")
	ErrLogoFormat   = errors.New("logo_format") // binary that is not a PNG
)

// CustomLogo is a checked custom logo.
type CustomLogo struct {
	Path          string
	Kind          string // text | ansi | image
	Width, Height int    // image: cells
}

// CheckLogoPath validates a custom logo path: absolute, no control
// characters, an existing regular file (symlinks followed) under the size
// cap, either UTF-8 text or a PNG image.
func CheckLogoPath(p string) (CustomLogo, error) {
	if p == "" || !filepath.IsAbs(p) || hasControl(p) {
		return CustomLogo{}, ErrLogoPath
	}
	st, err := os.Stat(p)
	if err != nil {
		return CustomLogo{}, ErrLogoMissing
	}
	if !st.Mode().IsRegular() {
		return CustomLogo{}, ErrLogoNotFile
	}
	f, err := os.Open(p)
	if err != nil {
		return CustomLogo{}, ErrLogoMissing
	}
	defer f.Close()
	head := make([]byte, 512)
	n, _ := f.Read(head)
	head = head[:n]
	if bytes.HasPrefix(head, []byte("\x89PNG\r\n\x1a\n")) {
		if st.Size() > MaxImageLogo {
			return CustomLogo{}, ErrLogoTooLarge
		}
		if _, err := f.Seek(0, 0); err != nil {
			return CustomLogo{}, ErrLogoMissing
		}
		cfg, _, err := image.DecodeConfig(f)
		if err != nil || cfg.Width <= 0 || cfg.Height <= 0 {
			return CustomLogo{}, ErrLogoFormat
		}
		return CustomLogo{Path: p, Kind: LogoImage, Width: ImageLogoWidth, Height: imageRows(cfg.Width, cfg.Height)}, nil
	}
	if st.Size() > MaxTextLogo {
		return CustomLogo{}, ErrLogoTooLarge
	}
	data, err := os.ReadFile(p)
	if err != nil {
		return CustomLogo{}, ErrLogoMissing
	}
	if !utf8.Valid(data) || bytes.IndexByte(data, 0) >= 0 || strings.TrimSpace(string(data)) == "" {
		return CustomLogo{}, ErrLogoFormat
	}
	kind := LogoText
	if bytes.IndexByte(data, 0x1b) >= 0 {
		kind = LogoANSI
	}
	return CustomLogo{Path: p, Kind: kind}, nil
}

// imageRows is the height in cells of a w x h picture drawn ImageLogoWidth
// cells wide (a cell is about twice as tall as it is wide).
func imageRows(w, h int) int {
	rows := (ImageLogoWidth*h + w) / (2 * w)
	return min(max(rows, 4), 24)
}

func hasControl(s string) bool {
	for _, r := range s {
		if r < 0x20 || (r >= 0x7f && r <= 0x9f) || r == utf8.RuneError {
			return true
		}
	}
	return false
}

var logoErrors = []error{ErrLogoPath, ErrLogoMissing, ErrLogoNotFile, ErrLogoTooLarge, ErrLogoFormat}

func isLogoError(err error) bool {
	for _, e := range logoErrors {
		if errors.Is(err, e) {
			return true
		}
	}
	return false
}

// LogoError is the UI key of a logo check error ("" for nil).
func LogoError(err error) string {
	for _, e := range logoErrors {
		if errors.Is(err, e) {
			return e.Error()
		}
	}
	if err != nil {
		return fmt.Sprint(err)
	}
	return ""
}
