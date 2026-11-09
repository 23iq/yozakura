package videoproxy

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestParseProbe(t *testing.T) {
	info, err := ParseProbe([]byte(`{"programs":[],"streams":[{"width":3840,"height":2160,"avg_frame_rate":"30000/1001","r_frame_rate":"30000/1001"}]}`))
	must(t, assert.NoError(t, err))
	assert.Equal(t, 3840, info.Width)
	assert.Equal(t, 2160, info.Height)
	assert.InDelta(t, 29.97, info.FPS, 0.01)
	assert.Equal(t, "30000/1001", info.Rate)

	// avg_frame_rate unknown ("0/0"): r_frame_rate is used.
	info, err = ParseProbe([]byte(`{"streams":[{"width":1920,"height":1080,"avg_frame_rate":"0/0","r_frame_rate":"60/1"}]}`))
	must(t, assert.NoError(t, err))
	assert.Equal(t, 60.0, info.FPS)
	assert.Equal(t, "60/1", info.Rate)

	_, err = ParseProbe([]byte(`{"streams":[]}`))
	assert.Error(t, err)
	_, err = ParseProbe([]byte(`not json`))
	assert.Error(t, err)
}

func TestPlanFor(t *testing.T) {
	uhd30 := Info{Width: 3840, Height: 2160, FPS: 30, Rate: "30/1"}

	p, ok := PlanFor(uhd30, 2560, 1440)
	must(t, assert.True(t, ok, "4K on a 1440p screen is downscaled"))
	assert.Equal(t, Plan{Width: 2560, Height: 1440, Rate: "30/1"}, p)

	_, ok = PlanFor(uhd30, 3840, 2160)
	assert.False(t, ok, "same size, 30 fps: original")
	_, ok = PlanFor(Info{Width: 2048, Height: 1152, FPS: 24, Rate: "24/1"}, 1920, 1080)
	assert.False(t, ok, "within 10% of the screen: original")

	p, ok = PlanFor(Info{Width: 1920, Height: 1080, FPS: 60, Rate: "60/1"}, 1920, 1080)
	must(t, assert.True(t, ok, "60 fps is capped"))
	assert.Equal(t, Plan{Width: 1920, Height: 1080, Rate: "30"}, p)

	// Ultrawide screen, 16:9 source: covers the width, even height.
	p, ok = PlanFor(uhd30, 2560, 1080)
	must(t, assert.True(t, ok))
	assert.Equal(t, 2560, p.Width)
	assert.Equal(t, 1440, p.Height)

	// Odd results round up to even.
	p, ok = PlanFor(Info{Width: 4001, Height: 3001, FPS: 25, Rate: "25/1"}, 1001, 751)
	must(t, assert.True(t, ok))
	assert.Equal(t, 0, p.Width%2)
	assert.Equal(t, 0, p.Height%2)
	assert.GreaterOrEqual(t, p.Width, 1001)
	assert.GreaterOrEqual(t, p.Height, 751)

	// Unknown frame rate: capped value.
	p, ok = PlanFor(Info{Width: 3840, Height: 2160}, 1920, 1080)
	must(t, assert.True(t, ok))
	assert.Equal(t, "30", p.Rate)

	for _, bad := range [][4]int{{0, 1080, 1920, 1080}, {1920, 1080, 0, 0}} {
		_, ok = PlanFor(Info{Width: bad[0], Height: bad[1], FPS: 60}, bad[2], bad[3])
		assert.False(t, ok)
	}
}

func TestArgs(t *testing.T) {
	args := Args("/v/in.mp4", "/c/out.mp4.part", Plan{Width: 1920, Height: 1080, Rate: "30"})
	assert.Contains(t, args, "scale=1920:1080:flags=lanczos,fps=30")
	assert.Equal(t, "/c/out.mp4.part", args[len(args)-1])
	assert.Equal(t, []string{"-f", "mp4"}, args[len(args)-3:len(args)-1])
	assert.Contains(t, args, "-an")
	assert.Equal(t, "/v/in.mp4", ProbeArgs("/v/in.mp4")[len(ProbeArgs("/v/in.mp4"))-1])
}

// must stops the test when a precondition assertion failed.
func must(t *testing.T, ok bool) {
	t.Helper()
	if !ok {
		t.FailNow()
	}
}

func TestParseProbeRotation(t *testing.T) {
	side, err := ParseProbe([]byte(`{"streams":[{"width":1920,"height":1080,"avg_frame_rate":"30/1",` +
		`"tags":{},"side_data_list":[{"rotation":-90}]}]}`))
	assert.NoError(t, err)
	assert.Equal(t, 1080, side.Width, "display matrix")
	assert.Equal(t, 1920, side.Height)

	tag, err := ParseProbe([]byte(`{"streams":[{"width":1920,"height":1080,"avg_frame_rate":"30/1","tags":{"rotate":"270"}}]}`))
	assert.NoError(t, err)
	assert.Equal(t, 1080, tag.Width, "rotate tag")

	flip, err := ParseProbe([]byte(`{"streams":[{"width":1920,"height":1080,"avg_frame_rate":"30/1","side_data_list":[{"rotation":180}]}]}`))
	assert.NoError(t, err)
	assert.Equal(t, 1920, flip.Width, "upside down keeps the size")
}
