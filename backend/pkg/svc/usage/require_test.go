package usage

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

// require mirrors the testify/require calls these tests use (that package
// is not vendored): assert, then stop the test on failure.
var require requireT

type requireT struct{}

func stop(t *testing.T, ok bool) {
	t.Helper()
	if !ok {
		t.FailNow()
	}
}

func (requireT) NoError(t *testing.T, err error, msg ...any) {
	t.Helper()
	stop(t, assert.NoError(t, err, msg...))
}

func (requireT) Len(t *testing.T, obj any, n int, msg ...any) {
	t.Helper()
	stop(t, assert.Len(t, obj, n, msg...))
}

func (requireT) NotNil(t *testing.T, obj any, msg ...any) {
	t.Helper()
	stop(t, assert.NotNil(t, obj, msg...))
}

func (requireT) True(t *testing.T, v bool, msg ...any) {
	t.Helper()
	stop(t, assert.True(t, v, msg...))
}

func (requireT) Eventually(t *testing.T, cond func() bool, wait, tick time.Duration, msg ...any) {
	t.Helper()
	stop(t, assert.Eventually(t, cond, wait, tick, msg...))
}
