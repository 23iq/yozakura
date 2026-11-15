package convert

import (
	"context"
	"fmt"
	"os"
	"runtime/debug"
	"time"
)

// Native conversions run inside the daemon (the process that supervises
// the shell), so they are bounded: the input size, the decoded pixels, the
// run time and a panic in a decoder all end the job, never the daemon.

// maxNativeInput: a data file larger than this is refused (its node tree
// takes 10-20 times its size).
const maxNativeInput = 64 << 20

// nativeTimeout bounds one native step.
const nativeTimeout = 2 * time.Minute

// ConvertNative converts without external tools: the data formats (json,
// yaml, toml, csv) and the common raster images.
func ConvertNative(src, from, dst, to string, q Quality) error {
	if byID[from].Kind == KindData {
		st, err := os.Stat(src)
		if err != nil {
			return err
		}
		if st.Size() > maxNativeInput {
			return Errorf(CodeTooLarge, nil, "the file is too large to convert (over %d MB)", maxNativeInput>>20)
		}
		return convertData(src, from, dst, to)
	}
	return convertImage(src, dst, to, q)
}

// errNativeTimeout: a native step ran past its timeout.
var errNativeTimeout = Errorf(CodeTimeout, []string{"converter"}, "the conversion timed out")

// nativeSlots bounds the native steps alive in this process, the ones a
// cancel or a timeout left behind included: a decode cannot be
// interrupted, so a step that gave up on one still holds its slot until it
// really ends, and the next native step waits for it. Memory stays bounded
// however often a job is started and stopped.
var nativeSlots = make(chan struct{}, 2)

// closedCh is a channel that is already closed.
var closedCh = func() chan struct{} { c := make(chan struct{}); close(c); return c }()

// runNative runs a native step off the caller's goroutine: cancelling or
// the timeout returns at once (the step's result is then dropped), and a
// panic becomes the job's error. The returned channel closes when the
// step's goroutine has really ended (the work dir may be removed then).
func runNative(ctx context.Context, st Step) (<-chan struct{}, error) {
	select {
	case nativeSlots <- struct{}{}:
	case <-ctx.Done():
		return closedCh, ctx.Err()
	}
	done := make(chan error, 1)
	ended := make(chan struct{})
	go func() {
		defer func() {
			<-nativeSlots
			close(ended)
		}()
		defer func() {
			if r := recover(); r != nil {
				fmt.Fprintf(os.Stderr, "convert: native step panicked: %v\n%s", r, debug.Stack())
				done <- Errorf(CodeCrashed, nil, "the converter failed on this file (%v)", r)
			}
		}()
		done <- st.Native()
	}()
	timeout := st.Timeout
	if timeout <= 0 {
		timeout = nativeTimeout
	}
	t := time.NewTimer(timeout)
	defer t.Stop()
	select {
	case err := <-done:
		return ended, err
	case <-ctx.Done():
		return ended, ctx.Err()
	case <-t.C:
		return ended, errNativeTimeout
	}
}
