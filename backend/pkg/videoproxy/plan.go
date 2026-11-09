// Package videoproxy makes screen-sized copies of video wallpapers.
//
// A 4K/60 fps wallpaper on a 1440p screen decodes (often on the CPU) more
// than twice the pixels anyone sees. The shell asks for a copy scaled to
// cover the screen at no more than MaxFPS; it is transcoded once with
// ffmpeg into <cache>/video-wallpapers and reused while the source file is
// unchanged. Without ffmpeg/ffprobe, or when the source is already small,
// the original is played.
package videoproxy

import (
	"encoding/json"
	"fmt"
	"math"
	"strconv"
	"strings"
)

// MaxFPS is the frame rate cap of a proxy.
const MaxFPS = 30

// formatVersion is part of every cache key: bump it when Args changes so
// old proxies are rebuilt.
const formatVersion = 1

// Info is the first video stream of a file.
type Info struct {
	Width, Height int
	// FPS is the average frame rate; Rate the same as ffprobe printed it
	// ("30000/1001").
	FPS  float64
	Rate string
}

// Plan is the proxy to make: its size and frame rate (an ffmpeg fps value).
type Plan struct {
	Width, Height int
	Rate          string
}

// ParseProbe reads ProbeArgs output. Width and Height are the displayed
// size: a stream rotated by 90/270 degrees (phone videos; display matrix
// side data or the older "rotate" tag) has them swapped, as ffmpeg
// autorotates before the scale filter.
func ParseProbe(data []byte) (Info, error) {
	var doc struct {
		Streams []struct {
			Width        int    `json:"width"`
			Height       int    `json:"height"`
			AvgFrameRate string `json:"avg_frame_rate"`
			RFrameRate   string `json:"r_frame_rate"`
			Tags         struct {
				Rotate string `json:"rotate"`
			} `json:"tags"`
			SideData []struct {
				Rotation float64 `json:"rotation"`
			} `json:"side_data_list"`
		} `json:"streams"`
	}
	if err := json.Unmarshal(data, &doc); err != nil {
		return Info{}, err
	}
	for _, s := range doc.Streams {
		if s.Width <= 0 || s.Height <= 0 {
			continue
		}
		rate := s.AvgFrameRate
		fps := parseRate(rate)
		if fps <= 0 {
			rate = s.RFrameRate
			fps = parseRate(rate)
		}
		w, h := s.Width, s.Height
		rot, _ := strconv.ParseFloat(s.Tags.Rotate, 64)
		for _, sd := range s.SideData {
			if sd.Rotation != 0 {
				rot = sd.Rotation
			}
		}
		if q := int(math.Round(math.Abs(rot)/90)) % 4; q == 1 || q == 3 {
			w, h = h, w
		}
		return Info{Width: w, Height: h, FPS: fps, Rate: rate}, nil
	}
	return Info{}, fmt.Errorf("no video stream")
}

// parseRate turns "30000/1001" or "25" into frames per second (0 if unknown).
func parseRate(r string) float64 {
	num, den, ok := strings.Cut(strings.TrimSpace(r), "/")
	n, err := strconv.ParseFloat(num, 64)
	if err != nil || n <= 0 {
		return 0
	}
	if !ok {
		return n
	}
	d, err := strconv.ParseFloat(den, 64)
	if err != nil || d <= 0 {
		return 0
	}
	return n / d
}

// PlanFor decides whether `src` needs a proxy for a screen of
// screenW x screenH physical pixels: it does when it is larger than the
// size covering the screen (the wallpaper is drawn with aspect crop) or
// faster than MaxFPS. The proxy keeps the aspect ratio, covers the screen
// and has even dimensions (yuv420p).
func PlanFor(src Info, screenW, screenH int) (Plan, bool) {
	if src.Width <= 0 || src.Height <= 0 || screenW <= 0 || screenH <= 0 {
		return Plan{}, false
	}
	scale := math.Max(float64(screenW)/float64(src.Width), float64(screenH)/float64(src.Height))
	// Within 10% of the screen: scaling is not worth a re-encode.
	smaller := scale < 0.9
	faster := src.FPS > MaxFPS+0.5
	if !smaller && !faster {
		return Plan{}, false
	}
	p := Plan{Width: src.Width, Height: src.Height, Rate: src.Rate}
	if smaller {
		p.Width = even(float64(src.Width) * scale)
		p.Height = even(float64(src.Height) * scale)
	}
	if faster || p.Rate == "" || parseRate(p.Rate) <= 0 {
		p.Rate = strconv.Itoa(MaxFPS)
	}
	return p, true
}

func even(v float64) int {
	n := int(math.Ceil(v))
	if n%2 == 1 {
		n++
	}
	return max(n, 2)
}

// ProbeArgs are the ffprobe arguments for `path`.
func ProbeArgs(path string) []string {
	return []string{"-v", "error", "-select_streams", "v:0",
		"-show_entries", "stream=width,height,avg_frame_rate,r_frame_rate:stream_tags=rotate:stream_side_data=rotation",
		"-of", "json", "--", path}
}

// Args are the ffmpeg arguments that write the proxy of `src` to `dst`
// (an mp4 whatever its extension): video only, H.264 yuv420p, faststart.
func Args(src, dst string, p Plan) []string {
	vf := fmt.Sprintf("scale=%d:%d:flags=lanczos,fps=%s", p.Width, p.Height, p.Rate)
	return []string{"-nostdin", "-hide_banner", "-loglevel", "error", "-y",
		"-i", src, "-map", "0:v:0", "-an", "-sn", "-dn",
		"-vf", vf, "-c:v", "libx264", "-preset", "medium", "-crf", "20",
		"-pix_fmt", "yuv420p", "-movflags", "+faststart", "-f", "mp4", dst}
}
