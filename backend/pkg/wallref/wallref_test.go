package wallref

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestResolve(t *testing.T) {
	dir := BundledDir("/nix/store/new-shell")
	assert.Equal(t, "/nix/store/new-shell/assets/wallpapers_example", dir)
	assert.Equal(t, "", BundledDir(""))

	assert.Equal(t, dir+"/wallpaper-08.png", Resolve("bundled:wallpaper-08.png", dir))
	assert.Equal(t, dir+"/sub/a.mp4", Resolve("bundled:sub/a.mp4", dir))
	assert.Equal(t, dir+"/wallpaper-08.png",
		Resolve("/nix/store/old-shell-0.2.0/assets/wallpapers_example/wallpaper-08.png", dir), "an old store copy")
	assert.Equal(t, dir+"/etc/x.png", Resolve("bundled:../../etc/x.png", dir), "never leaves the folder")
	assert.Equal(t, "/home/u/a.jpg", Resolve("/home/u/a.jpg", dir))
	assert.Equal(t, "", Resolve("", dir))
	assert.Equal(t, "bundled:a.png", Resolve("bundled:a.png", ""), "unknown shell: unchanged")
}
