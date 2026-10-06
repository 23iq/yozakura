package usage

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strconv"
	"sync"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestParseClaudeUsageFixture(t *testing.T) {
	body, err := os.ReadFile("testdata/claude_usage.json")
	require.NoError(t, err)
	l, err := ParseClaudeUsage(body)
	require.NoError(t, err)
	assert.Equal(t, ClaudeProvider, l.Provider)
	assert.Equal(t, "oauth", l.Source)
	require.Len(t, l.Windows, 2) // null opus/sonnet windows are skipped
	assert.Equal(t, "5h", l.Windows[0].ID)
	assert.Equal(t, 4.0, l.Windows[0].UsedPercent)
	assert.Equal(t, time.Date(2026, 10, 6, 7, 50, 0, 216476000, time.UTC), l.Windows[0].ResetsAt.UTC())
	assert.Equal(t, "week", l.Windows[1].ID)
	assert.Equal(t, 38.0, l.Windows[1].UsedPercent)

	_, err = ParseClaudeUsage([]byte(`{"five_hour":null}`))
	assert.Error(t, err)
	_, err = ParseClaudeUsage([]byte(`nope`))
	assert.Error(t, err)
}

func writeCreds(t *testing.T, token string, expires time.Time) string {
	path := filepath.Join(t.TempDir(), ".credentials.json")
	body := `{"claudeAiOauth":{"accessToken":"` + token + `","expiresAt":` + strconv.FormatInt(expires.UnixMilli(), 10) + `}}`
	require.NoError(t, os.WriteFile(path, []byte(body), 0o600))
	return path
}

func TestClaudeFetcher(t *testing.T) {
	fixture, _ := os.ReadFile("testdata/claude_usage.json")
	status := http.StatusOK
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "Bearer tok-123" || r.Header.Get("anthropic-beta") != claudeOAuthBeta {
			w.WriteHeader(http.StatusUnauthorized)
			return
		}
		w.WriteHeader(status)
		_, _ = w.Write(fixture)
	}))
	defer srv.Close()
	now := time.Now()
	f := &ClaudeFetcher{CredPath: writeCreds(t, "tok-123", now.Add(time.Hour)), URL: srv.URL, Client: srv.Client(), Now: func() time.Time { return now }}
	l, err := f.Fetch(context.Background())
	require.NoError(t, err)
	assert.Len(t, l.Windows, 2)
	assert.Equal(t, now, l.UpdatedAt)

	status = http.StatusInternalServerError
	_, err = f.Fetch(context.Background())
	assert.Error(t, err)
	assert.NotContains(t, err.Error(), "tok-123")

	f.CredPath = writeCreds(t, "wrong", now.Add(time.Hour))
	_, err = f.Fetch(context.Background())
	assert.ErrorIs(t, err, ErrUnauthorized)

	f.CredPath = writeCreds(t, "tok-123", now.Add(-time.Minute)) // expired: never refreshed by us
	_, err = f.Fetch(context.Background())
	assert.ErrorIs(t, err, ErrNoCredentials)

	f.CredPath = filepath.Join(t.TempDir(), "missing.json")
	_, err = f.Fetch(context.Background())
	assert.ErrorIs(t, err, ErrNoCredentials)
}

func TestClaudeCredentialsPath(t *testing.T) {
	t.Setenv("CLAUDE_CONFIG_DIR", "/x/claude")
	assert.Equal(t, "/x/claude/.credentials.json", ClaudeCredentialsPath())
}

func TestPollerHaltsSilently(t *testing.T) {
	var mu sync.Mutex
	errs := []error{errors.New("net"), errors.New("net"), errors.New("net")}
	calls := 0
	fetch := func(context.Context) (Limits, error) {
		mu.Lock()
		defer mu.Unlock()
		calls++
		if len(errs) > 0 {
			e := errs[0]
			errs = errs[1:]
			return Limits{}, e
		}
		return Limits{Provider: ClaudeProvider}, nil
	}
	published := 0
	p := newClaudePoller(fetch, func(Limits) { mu.Lock(); published++; mu.Unlock() })
	p.interval = time.Millisecond
	p.AddSubscriber()
	p.SetEnabled(true)
	require.Eventually(t, func() bool { return !p.Running() }, 3*time.Second, time.Millisecond)
	mu.Lock()
	assert.Equal(t, maxPollFailures, calls)
	assert.Equal(t, 0, published)
	mu.Unlock()

	// Re-enabling re-arms it; now fetches succeed.
	p.SetEnabled(true)
	require.Eventually(t, func() bool { mu.Lock(); defer mu.Unlock(); return published > 0 }, 3*time.Second, time.Millisecond)
	p.Stop()
	assert.False(t, p.Running())

	// Auth errors halt at once.
	p2 := newClaudePoller(func(context.Context) (Limits, error) { return Limits{}, ErrUnauthorized }, func(Limits) {})
	p2.interval = time.Millisecond
	p2.SetEnabled(true)
	p2.AddSubscriber()
	require.Eventually(t, func() bool { return !p2.Running() }, 3*time.Second, time.Millisecond)
	p2.RemoveSubscriber()
}
