package statesfile

import (
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestSetGetKeepsOtherKeys(t *testing.T) {
	path := filepath.Join(t.TempDir(), "states.json")
	if !assert.NoError(t, Set(path, "caffeine", true)) {
		return
	}
	if !assert.NoError(t, Set(path, "nightlight", map[string]any{"active": true, "temp": 4000})) {
		return
	}

	b, found, err := Get[bool](path, "caffeine")
	if !assert.NoError(t, err) {
		return
	}
	assert.True(t, found)
	assert.True(t, b)

	m, found, err := Get[map[string]any](path, "nightlight")
	if !assert.NoError(t, err) {
		return
	}
	assert.True(t, found)
	assert.Equal(t, 4000.0, m["temp"])
}

func TestGetMissing(t *testing.T) {
	path := filepath.Join(t.TempDir(), "states.json")
	_, found, err := Get[bool](path, "x")
	assert.NoError(t, err)
	assert.False(t, found)
	if !assert.NoError(t, Set(path, "a", 1)) {
		return
	}
	_, found, err = Get[bool](path, "x")
	assert.NoError(t, err)
	assert.False(t, found)
}

func TestCorruptFile(t *testing.T) {
	path := filepath.Join(t.TempDir(), "states.json")
	if !assert.NoError(t, os.WriteFile(path, []byte("{nope"), 0o644)) {
		return
	}
	_, _, err := Get[bool](path, "a")
	assert.Error(t, err)
	if !assert.NoError(t, Set(path, "a", true)) {
		return
	}
	v, found, err := Get[bool](path, "a")
	assert.NoError(t, err)
	assert.True(t, found && v)
}

func TestConcurrentSetsDoNotLoseKeys(t *testing.T) {
	path := filepath.Join(t.TempDir(), "states.json")
	var wg sync.WaitGroup
	for i := 0; i < 20; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			assert.NoError(t, Set(path, fmt.Sprintf("k%d", i), i))
		}(i)
	}
	wg.Wait()
	for i := 0; i < 20; i++ {
		v, found, err := Get[int](path, fmt.Sprintf("k%d", i))
		if !assert.NoError(t, err) {
			return
		}
		assert.True(t, found)
		assert.Equal(t, i, v)
	}
}
