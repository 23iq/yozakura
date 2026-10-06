package extras

import (
	"bufio"
	"bytes"
	"os"
	"path/filepath"
	"strings"
)

// FS is the filesystem access DetectPlatform needs (fakeable in tests).
type FS interface {
	ReadFile(path string) ([]byte, error)
	Glob(pattern string) ([]string, error)
}

// OSFS is the real filesystem.
type OSFS struct{}

// ReadFile implements FS.
func (OSFS) ReadFile(p string) ([]byte, error) { return os.ReadFile(p) }

// Glob implements FS.
func (OSFS) Glob(p string) ([]string, error) { return filepath.Glob(p) }

// Platform describes the host distro, GPU and available installers.
type Platform struct {
	Distro     string `json:"distro"` // arch|fedora|nixos|other
	GPU        string `json:"gpu"`    // nvidia|amd|intel|none
	HasParu    bool   `json:"hasParu"`
	HasYay     bool   `json:"hasYay"`
	HasFlatpak bool   `json:"hasFlatpak"`
	HasNpm     bool   `json:"hasNpm"`
	HasPkexec  bool   `json:"hasPkexec"`
	Multilib   bool   `json:"multilib"`
}

// DetectPlatform probes distro, GPU, installers and pacman multilib. look
// reports whether a binary is on PATH.
func DetectPlatform(fs FS, look func(string) bool) Platform {
	p := Platform{
		Distro:     detectDistro(fs),
		GPU:        detectGPU(fs),
		HasParu:    look("paru"),
		HasYay:     look("yay"),
		HasFlatpak: look("flatpak"),
		HasNpm:     look("npm"),
		HasPkexec:  look("pkexec"),
	}
	p.Multilib = multilibEnabled(fs)
	return p
}

func detectDistro(fs FS) string {
	data, err := fs.ReadFile("/etc/os-release")
	if err != nil {
		return "other"
	}
	var ids []string
	sc := bufio.NewScanner(bytes.NewReader(data))
	for sc.Scan() {
		k, v, ok := strings.Cut(strings.TrimSpace(sc.Text()), "=")
		if !ok || (k != "ID" && k != "ID_LIKE") {
			continue
		}
		ids = append(ids, strings.Fields(strings.Trim(v, `"'`))...)
	}
	for _, want := range []string{"arch", "fedora", "nixos"} {
		for _, id := range ids {
			if id == want {
				return want
			}
		}
	}
	return "other"
}

func detectGPU(fs FS) string {
	files, _ := fs.Glob("/sys/class/drm/card*/device/vendor")
	rank := map[string]int{"none": 0, "intel": 1, "amd": 2, "nvidia": 3}
	best := "none"
	for _, f := range files {
		data, err := fs.ReadFile(f)
		if err != nil {
			continue
		}
		var g string
		switch strings.ToLower(strings.TrimSpace(string(data))) {
		case "0x10de":
			g = "nvidia"
		case "0x1002":
			g = "amd"
		case "0x8086":
			g = "intel"
		default:
			continue
		}
		if rank[g] > rank[best] {
			best = g
		}
	}
	return best
}

func multilibEnabled(fs FS) bool {
	data, err := fs.ReadFile("/etc/pacman.conf")
	if err != nil {
		return false
	}
	for _, line := range strings.Split(string(data), "\n") {
		if strings.TrimSpace(line) == "[multilib]" {
			return true
		}
	}
	return false
}
