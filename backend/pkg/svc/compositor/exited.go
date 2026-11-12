package compositor

import (
	"errors"

	"golang.org/x/sys/unix"
)

// waitExited blocks until the process pid has exited, without reaping it:
// it stays a zombie, so its pid (and process group id) cannot be reused
// until the caller's Wait reaps it. superviseDaemon marks the daemon gone
// in between, so Close never signals a pid that already belongs to
// another process.
func waitExited(pid int) {
	var info unix.Siginfo
	for {
		err := unix.Waitid(unix.P_PID, pid, &info, unix.WEXITED|unix.WNOWAIT, nil)
		if !errors.Is(err, unix.EINTR) {
			return
		}
	}
}
