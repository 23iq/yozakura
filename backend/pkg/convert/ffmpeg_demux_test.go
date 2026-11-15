package convert

import (
	"context"
	"strings"
	"testing"

	"yozakura/backend/pkg/proc"
)

// Every pinned demuxer exists in this ffmpeg; a playlist named .mp4 is
// read as MP4 (and refused), never as HLS.
func TestFFmpegDemuxers(t *testing.T) {
	need(t, EngineFFmpeg)
	ff := realTools.Prog(EngineFFmpeg)
	for from, d := range ffDemuxers {
		out, _ := proc.Combined(context.Background(), ff, "-hide_banner", "-f", d, "-i", "/nonexistent/x")
		if strings.Contains(string(out), "Unknown input format") {
			t.Errorf("%s: ffmpeg has no demuxer %q", from, d)
		}
	}
	src := write(t, t.TempDir(), "list.mp4", []byte("#EXTM3U\n#EXTINF:1,\n/etc/hostname\n"))
	p, err := BuildPlan(Request{Src: src, From: "mp4", To: "mp3"}, realTools, t.TempDir(), PlanOptions{})
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(strings.Join(p.Steps[0].Args, " "), "-f mov -i in.mp4") {
		t.Fatalf("argv %v", p.Steps[0].Args)
	}
	if err := p.Run(context.Background(), nil); err == nil {
		t.Fatal("a playlist named .mp4 was converted")
	}
}
