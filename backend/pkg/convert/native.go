package convert

import (
	"context"
	"errors"
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
			return fmt.Errorf("the file is too large to convert (over %d MB)", maxNativeInput>>20)
		}
		return convertData(src, from, dst, to)
	}
	return convertImage(src, dst, to, q)
}

// errNativeTimeout: a native step ran past its timeout.
var errNativeTimeout = errors.New("the conversion timed out")

// runNative runs a native step off the caller's goroutine: cancelling or
// the timeout returns at once (the step's result is then dropped with the
// work dir), and a panic becomes the job's error.
func runNative(ctx context.Context, st Step) error {
	done := make(chan error, 1)
	go func() {
		defer func() {
			if r := recover(); r != nil {
				fmt.Fprintf(os.Stderr, "convert: native step panicked: %v\n%s", r, debug.Stack())
				done <- fmt.Errorf("the converter failed on this file (%v)", r)
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
		return err
	case <-ctx.Done():
		return ctx.Err()
	case <-t.C:
		return errNativeTimeout
	}
}
