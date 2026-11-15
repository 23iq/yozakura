package convert

import (
	"image"
	"image/color"
	"image/draw"
	"image/gif"
	"image/jpeg"
	"image/png"
	"io"
	"os"

	"golang.org/x/image/bmp"
	"golang.org/x/image/tiff"
	_ "golang.org/x/image/webp" // decoder
)

// maxPixels bounds what the native image path decodes (a small file can
// declare a huge canvas; a 16-bit image takes 8 bytes a pixel, plus a copy
// to flatten it); ImageMagick handles bigger images.
const maxPixels = 40_000_000

func convertImage(src, dst, to string, q Quality) error {
	f, err := os.Open(src)
	if err != nil {
		return err
	}
	cfg, _, err := image.DecodeConfig(f)
	if err != nil {
		f.Close()
		return Errorf(CodeBadInput, nil, "cannot read the image: %v", err)
	}
	if cfg.Width <= 0 || cfg.Height <= 0 || int64(cfg.Width)*int64(cfg.Height) > maxPixels {
		f.Close()
		return Errorf(CodeTooLarge, nil, "the image is too large (%dx%d) to convert without ImageMagick", cfg.Width, cfg.Height)
	}
	if _, err := f.Seek(0, io.SeekStart); err != nil {
		f.Close()
		return err
	}
	img, _, err := image.Decode(f)
	f.Close()
	if err != nil {
		return Errorf(CodeBadInput, nil, "cannot read the image: %v", err)
	}
	out, err := os.Create(dst)
	if err != nil {
		return err
	}
	if err := encodeImage(out, img, to, q); err != nil {
		out.Close()
		return err
	}
	return out.Close()
}

func encodeImage(w io.Writer, img image.Image, to string, q Quality) error {
	switch to {
	case "png":
		return png.Encode(w, img)
	case "jpg":
		return jpeg.Encode(w, onWhite(img), &jpeg.Options{Quality: pickQ(q, 60, 82, 92)})
	case "gif":
		return gif.Encode(w, img, nil)
	case "bmp":
		return bmp.Encode(w, onWhite(img))
	case "tiff":
		return tiff.Encode(w, img, &tiff.Options{Compression: tiff.Deflate})
	}
	return Errorf(CodeToolMissing, []string{label(to), ToolName(EngineMagick)}, "cannot write %s without ImageMagick", label(to))
}

// onWhite flattens transparency onto white (formats without alpha).
func onWhite(img image.Image) image.Image {
	b := img.Bounds()
	out := image.NewRGBA(b)
	draw.Draw(out, b, &image.Uniform{C: color.White}, image.Point{}, draw.Src)
	draw.Draw(out, b, img, b.Min, draw.Over)
	return out
}
