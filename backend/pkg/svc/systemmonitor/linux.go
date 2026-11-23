//go:build linux

package systemmonitor

import (
	"context"
	"math"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"

	"yozakura/backend/pkg/proc"
)

type syscallStatfs = syscall.Statfs_t

func statfs(mount string, st *syscallStatfs) error {
	s := syscall.Statfs_t{}
	if err := syscall.Statfs(mount, &s); err != nil {
		return err
	}
	*st = s
	return nil
}

func nvidiaQuery(pciID string) (usage float64, temp int) {
	out, err := proc.Run(context.Background(), "nvidia-smi", "-i", pciID,
		"--query-gpu=utilization.gpu,temperature.gpu",
		"--format=csv,noheader,nounits")
	if err != nil {
		return 0, -1
	}
	return parseNvidiaSmi(string(out))
}

// parseNvidiaSmi reads one "utilization, temperature" line from nvidia-smi.
// Newer drivers report fractional degrees ("34.80"), so the temperature is
// parsed as a float and rounded. -1 means the temperature is unknown.
func parseNvidiaSmi(out string) (usage float64, temp int) {
	parts := strings.Split(strings.TrimSpace(out), ",")
	if len(parts) < 2 {
		return 0, -1
	}
	u, _ := strconv.ParseFloat(strings.TrimSpace(parts[0]), 64)
	t, err := strconv.ParseFloat(strings.TrimSpace(parts[1]), 64)
	if err != nil {
		return u, -1
	}
	return u, int(math.Round(t))
}

func amdTemp(card string) int {
	base := filepath.Join("/sys/class/drm", card, "device/hwmon")
	entries, err := os.ReadDir(base)
	if err != nil || len(entries) == 0 {
		return -1
	}
	data, err := os.ReadFile(filepath.Join(base, entries[0].Name(), "temp1_input"))
	if err != nil {
		return -1
	}
	val, _ := strconv.Atoi(strings.TrimSpace(string(data)))
	return val / 1000
}
