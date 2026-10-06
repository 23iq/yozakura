package usage

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"time"
)

// Read-only fetcher for the Claude subscription usage that Claude Code's
// /usage shows. It reuses the OAuth token Claude Code stores in
// ~/.claude/.credentials.json (or $CLAUDE_CONFIG_DIR) and never refreshes
// or writes it: an expired token simply yields no data until Claude Code
// refreshes it. The token is never logged or returned.

// ClaudeUsageURL is the endpoint Claude Code's /usage reads.
const ClaudeUsageURL = "https://api.anthropic.com/api/oauth/usage"

const claudeOAuthBeta = "oauth-2025-04-20"

// ClaudeProvider is the limits provider id of the Claude subscription.
const ClaudeProvider = "claude"

// ErrNoCredentials means Claude Code is not signed in with a subscription
// (or its token expired); the fetcher stays quiet.
var ErrNoCredentials = errors.New("usage: no usable Claude credentials")

// ErrUnauthorized is a 401/403 from the endpoint: polling stops.
var ErrUnauthorized = errors.New("usage: Claude usage endpoint refused the token")

// ClaudeFetcher reads the usage endpoint.
type ClaudeFetcher struct {
	CredPath string
	URL      string
	Client   *http.Client
	Now      func() time.Time
}

// NewClaudeFetcher wires the real paths and endpoint.
func NewClaudeFetcher() *ClaudeFetcher {
	return &ClaudeFetcher{
		CredPath: ClaudeCredentialsPath(),
		URL:      ClaudeUsageURL,
		Client:   &http.Client{Timeout: 15 * time.Second},
		Now:      time.Now,
	}
}

// ClaudeCredentialsPath is where Claude Code keeps its OAuth tokens.
func ClaudeCredentialsPath() string {
	dir := os.Getenv("CLAUDE_CONFIG_DIR")
	if dir == "" {
		home, _ := os.UserHomeDir()
		dir = filepath.Join(home, ".claude")
	}
	return filepath.Join(dir, ".credentials.json")
}

func (f *ClaudeFetcher) token() (string, error) {
	data, err := os.ReadFile(f.CredPath)
	if err != nil {
		return "", ErrNoCredentials
	}
	var c struct {
		OAuth struct {
			AccessToken string `json:"accessToken"`
			ExpiresAt   int64  `json:"expiresAt"` // unix ms
		} `json:"claudeAiOauth"`
	}
	if json.Unmarshal(data, &c) != nil || c.OAuth.AccessToken == "" {
		return "", ErrNoCredentials
	}
	if c.OAuth.ExpiresAt > 0 && f.Now().UnixMilli() >= c.OAuth.ExpiresAt {
		return "", ErrNoCredentials
	}
	return c.OAuth.AccessToken, nil
}

// Fetch performs one request and returns the subscription windows.
func (f *ClaudeFetcher) Fetch(ctx context.Context) (Limits, error) {
	tok, err := f.token()
	if err != nil {
		return Limits{}, err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, f.URL, nil)
	if err != nil {
		return Limits{}, err
	}
	req.Header.Set("Authorization", "Bearer "+tok)
	req.Header.Set("anthropic-beta", claudeOAuthBeta)
	req.Header.Set("Accept", "application/json")
	resp, err := f.Client.Do(req)
	if err != nil {
		return Limits{}, errors.New("usage: Claude usage request failed") // the error may echo the request
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return Limits{}, err
	}
	switch {
	case resp.StatusCode == http.StatusUnauthorized || resp.StatusCode == http.StatusForbidden:
		return Limits{}, ErrUnauthorized
	case resp.StatusCode != http.StatusOK:
		return Limits{}, fmt.Errorf("usage: Claude usage endpoint: HTTP %d", resp.StatusCode)
	}
	l, err := ParseClaudeUsage(body)
	if err != nil {
		return Limits{}, err
	}
	l.UpdatedAt = f.Now()
	return l, nil
}

// claudeWindows maps the endpoint's window fields to our window ids.
var claudeWindows = []struct{ field, id string }{
	{"five_hour", "5h"},
	{"seven_day", "week"},
	{"seven_day_opus", "week_opus"},
	{"seven_day_sonnet", "week_sonnet"},
}

// ParseClaudeUsage converts the endpoint body. utilization is already a
// percentage there; null windows are skipped.
func ParseClaudeUsage(body []byte) (Limits, error) {
	var raw map[string]json.RawMessage
	if err := json.Unmarshal(body, &raw); err != nil {
		return Limits{}, fmt.Errorf("usage: Claude usage: %w", err)
	}
	l := Limits{Provider: ClaudeProvider, Source: "oauth", Windows: []Window{}}
	for _, cw := range claudeWindows {
		var w *struct {
			Utilization *float64 `json:"utilization"`
			ResetsAt    string   `json:"resets_at"`
		}
		if json.Unmarshal(raw[cw.field], &w) != nil || w == nil || w.Utilization == nil {
			continue
		}
		win := Window{ID: cw.id, UsedPercent: *w.Utilization}
		if t, err := time.Parse(time.RFC3339Nano, w.ResetsAt); err == nil {
			win.ResetsAt = t
		}
		l.Windows = append(l.Windows, win)
	}
	if len(l.Windows) == 0 {
		return Limits{}, errors.New("usage: Claude usage: no windows")
	}
	return l, nil
}
