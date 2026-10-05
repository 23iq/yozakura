package transfers

import (
	"context"
	"os"
	"time"

	"golang.org/x/sys/unix"
)

// DirWatch wakes a source when entries of a directory are created, removed,
// renamed or finish writing (inotify). Without inotify (or when the
// directory is missing) Events is nil and the caller falls back to its
// slow poll tick.
type DirWatch struct {
	Events <-chan struct{}
	file   *os.File
}

const dirWatchMask = unix.IN_CREATE | unix.IN_DELETE | unix.IN_MOVED_FROM | unix.IN_MOVED_TO |
	unix.IN_CLOSE_WRITE | unix.IN_DELETE_SELF | unix.IN_MOVE_SELF

// WatchDir starts watching dir until ctx is done.
func WatchDir(ctx context.Context, dir string) *DirWatch {
	w := &DirWatch{}
	fd, err := unix.InotifyInit1(unix.IN_NONBLOCK | unix.IN_CLOEXEC)
	if err != nil {
		return w
	}
	if _, err := unix.InotifyAddWatch(fd, dir, dirWatchMask); err != nil {
		unix.Close(fd)
		return w
	}
	// A non-blocking fd goes through the runtime poller, so Close unblocks
	// the reader goroutine.
	w.file = os.NewFile(uintptr(fd), "inotify")
	ch := make(chan struct{}, 1)
	w.Events = ch
	go func() {
		<-ctx.Done()
		w.file.Close()
	}()
	go func() {
		buf := make([]byte, 4096)
		for {
			if _, err := w.file.Read(buf); err != nil {
				return
			}
			select {
			case ch <- struct{}{}:
			default:
			}
		}
	}()
	return w
}

// Close stops the watch early (also done when ctx ends).
func (w *DirWatch) Close() {
	if w.file != nil {
		w.file.Close()
	}
}

// sleepOrWake waits for d, a watch event (nil channel never fires) or ctx.
// It reports false when ctx is done.
func sleepOrWake(ctx context.Context, d time.Duration, wake <-chan struct{}) bool {
	t := time.NewTimer(d)
	defer t.Stop()
	select {
	case <-ctx.Done():
		return false
	case <-t.C:
	case <-wake:
	}
	return true
}
