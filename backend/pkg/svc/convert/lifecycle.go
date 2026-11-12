package convert

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"

	"yozakura/backend/pkg/brand"
	conv "yozakura/backend/pkg/convert"
)

// Everything a converting process keeps on disk carries its pid, so the
// daemon and a `convert` CLI run side by side, and whatever a killed one
// left is removed by the next start:
//   <cache>/convert/work/<pid>-*            work directories
//   <cache>/convert/office-profile-<pid>    its LibreOffice profile
//   <cache>/convert/groups/<pid>-<pgid>     its running process groups

func (s *Service) workRoot() string { return filepath.Join(s.o.CacheDir, "work") }

func (s *Service) officeProfile() string {
	if s.o.CacheDir == "" {
		return ""
	}
	return filepath.Join(s.o.CacheDir, "office-profile-"+strconv.Itoa(os.Getpid()))
}

// workDir makes the job's private directory: under the cache when it is on
// dir's filesystem (the result can be renamed into dir), else a hidden one
// in dir.
func (s *Service) workDir(dir string) (string, error) {
	if s.o.CacheDir != "" {
		root := s.workRoot()
		if err := os.MkdirAll(root, 0o700); err == nil && sameDevice(root, dir) {
			if w, err := os.MkdirTemp(root, strconv.Itoa(os.Getpid())+"-"); err == nil {
				return w, nil
			}
		}
	}
	w, err := os.MkdirTemp(dir, "."+brand.AppID+"-convert-")
	if err != nil {
		return "", fmt.Errorf("cannot write to %s", dir)
	}
	return w, nil
}

func sameDevice(a, b string) bool {
	var sa, sb syscall.Stat_t
	if syscall.Stat(a, &sa) != nil || syscall.Stat(b, &sb) != nil {
		return false
	}
	return sa.Dev == sb.Dev
}

// sweep removes what dead converting processes left and kills their
// process groups; it records this process's groups from now on.
func (s *Service) sweep() {
	if s.o.CacheDir == "" {
		return
	}
	groups := filepath.Join(s.o.CacheDir, "groups")
	conv.KillStaleGroups(groups)
	conv.TrackGroupsIn(groups)
	if entries, err := os.ReadDir(s.workRoot()); err == nil {
		for _, e := range entries {
			if pid, ok := leadingPid(e.Name(), "-"); ok && !pidAlive(pid) {
				_ = os.RemoveAll(filepath.Join(s.workRoot(), e.Name()))
			}
		}
	}
	profiles, _ := filepath.Glob(filepath.Join(s.o.CacheDir, "office-profile-*"))
	for _, p := range profiles {
		if pid, err := strconv.Atoi(strings.TrimPrefix(filepath.Base(p), "office-profile-")); err == nil && !pidAlive(pid) {
			_ = os.RemoveAll(p)
		}
	}
	// the profile this service used before profiles carried a pid
	_ = os.RemoveAll(filepath.Join(s.o.CacheDir, "office-profile"))
}

func leadingPid(name, sep string) (int, bool) {
	head, _, ok := strings.Cut(name, sep)
	if !ok {
		return 0, false
	}
	pid, err := strconv.Atoi(head)
	return pid, err == nil
}

func pidAlive(pid int) bool {
	if pid <= 0 {
		return false
	}
	if pid == os.Getpid() {
		return true
	}
	err := syscall.Kill(pid, 0)
	return err == nil || err == syscall.EPERM
}

// Stop cancels every job, waits (bounded) for them to clean up and
// removes this process's LibreOffice profile. Later starts are refused.
func (s *Service) Stop() {
	s.mu.Lock()
	s.stopped = true
	cancels := make([]func(), 0, len(s.cancels))
	for _, c := range s.cancels {
		cancels = append(cancels, c)
	}
	s.mu.Unlock()
	for _, c := range cancels {
		c()
	}
	done := make(chan struct{})
	go func() {
		s.wg.Wait()
		close(done)
	}()
	select {
	case <-done:
	case <-time.After(10 * time.Second):
	}
	if p := s.officeProfile(); p != "" {
		_ = os.RemoveAll(p)
	}
}
