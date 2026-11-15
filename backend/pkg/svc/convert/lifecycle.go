package convert

import (
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
//   <cache>/convert/outside/<pid>-*         the path of a hidden work dir it
//                                           made in an output folder

func (s *Service) workRoot() string { return filepath.Join(s.o.CacheDir, "work") }

func (s *Service) officeProfile() string {
	if s.o.CacheDir == "" {
		return ""
	}
	return filepath.Join(s.o.CacheDir, "office-profile-"+strconv.Itoa(os.Getpid()))
}

func (s *Service) outsideRoot() string { return filepath.Join(s.o.CacheDir, "outside") }

// hiddenPrefix starts the name of a work dir made in an output folder.
func hiddenPrefix() string { return "." + brand.AppID + "-convert-" }

// workDir makes the job's private directory and returns its cleanup:
// under the cache when it is on dir's filesystem (the result can be
// renamed into dir), else a hidden one in dir, recorded in the cache so a
// later start removes it if this process dies first.
func (s *Service) workDir(dir string) (string, func(), error) {
	if s.o.CacheDir != "" {
		root := s.workRoot()
		if err := os.MkdirAll(root, 0o700); err == nil && sameDevice(root, dir) {
			if w, err := os.MkdirTemp(root, strconv.Itoa(os.Getpid())+"-"); err == nil {
				return w, func() { _ = os.RemoveAll(w) }, nil
			}
		}
	}
	return s.hiddenWorkDir(dir)
}

// hiddenWorkDir makes a recorded hidden work dir in dir.
func (s *Service) hiddenWorkDir(dir string) (string, func(), error) {
	w, err := os.MkdirTemp(dir, hiddenPrefix()+strconv.Itoa(os.Getpid())+"-")
	if err != nil {
		return "", nil, conv.Errorf(conv.CodeNoWrite, []string{dir}, "cannot write to %s", dir)
	}
	record := ""
	if s.o.CacheDir != "" && os.MkdirAll(s.outsideRoot(), 0o700) == nil {
		if f, err := os.CreateTemp(s.outsideRoot(), strconv.Itoa(os.Getpid())+"-"); err == nil {
			_, _ = f.WriteString(w)
			f.Close()
			record = f.Name()
		}
	}
	return w, func() {
		// the record goes only with the dir: what is left is swept later
		if os.RemoveAll(w) == nil && record != "" {
			_ = os.Remove(record)
		}
	}, nil
}

// sweepOutside removes the hidden work dirs dead processes recorded; a
// record only ever names a dir of the recorded process's own pattern.
func (s *Service) sweepOutside() {
	entries, err := os.ReadDir(s.outsideRoot())
	if err != nil {
		return
	}
	for _, e := range entries {
		pid, ok := leadingPid(e.Name(), "-")
		if ok && conv.PidAlive(pid) {
			continue
		}
		rec := filepath.Join(s.outsideRoot(), e.Name())
		b, _ := os.ReadFile(rec)
		_ = os.Remove(rec)
		w := strings.TrimSpace(string(b))
		if ok && filepath.IsAbs(w) && strings.HasPrefix(filepath.Base(w), hiddenPrefix()+strconv.Itoa(pid)+"-") {
			if st, err := os.Lstat(w); err == nil && st.IsDir() {
				_ = os.RemoveAll(w)
			}
		}
	}
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
	s.sweepOutside()
	if entries, err := os.ReadDir(s.workRoot()); err == nil {
		for _, e := range entries {
			if pid, ok := leadingPid(e.Name(), "-"); ok && !conv.PidAlive(pid) {
				_ = os.RemoveAll(filepath.Join(s.workRoot(), e.Name()))
			}
		}
	}
	profiles, _ := filepath.Glob(filepath.Join(s.o.CacheDir, "office-profile-*"))
	for _, p := range profiles {
		if pid, err := strconv.Atoi(strings.TrimPrefix(filepath.Base(p), "office-profile-")); err == nil && !conv.PidAlive(pid) {
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
