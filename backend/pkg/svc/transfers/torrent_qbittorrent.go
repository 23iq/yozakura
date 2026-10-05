package transfers

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strings"
)

// qBittorrent WebUI API v2. Works without credentials when "Bypass
// authentication for clients on localhost" is enabled; otherwise the
// "qbittorrent" secret ("user:password") is used to log in once.
type qbittorrent struct {
	base   string
	secret string
	http   *http.Client
	tried  bool // login attempted for this process
}

func newQBittorrent(o Options) *qbittorrent {
	return &qbittorrent{
		base:   strings.TrimRight(o.Endpoint("qbittorrent", "http://127.0.0.1:8080"), "/"),
		secret: o.Secret("qbittorrent", ""),
		http:   newTorrentHTTP(),
	}
}

func (q *qbittorrent) procs() []string { return []string{"qbittorrent", "qbittorrent-nox"} }

func (q *qbittorrent) reset() {
	q.http = newTorrentHTTP()
	q.tried = false
}

type qbTorrent struct {
	Hash        string  `json:"hash"`
	Name        string  `json:"name"`
	Size        int64   `json:"size"`
	TotalSize   int64   `json:"total_size"`
	Completed   int64   `json:"completed"`
	AmountLeft  int64   `json:"amount_left"`
	DLSpeed     float64 `json:"dlspeed"`
	Progress    float64 `json:"progress"`
	State       string  `json:"state"`
	SavePath    string  `json:"save_path"`
	ContentPath string  `json:"content_path"`
	AddedOn     int64   `json:"added_on"`
}

func (q *qbittorrent) poll(ctx context.Context) ([]Transfer, error) {
	resp, err := q.get(ctx)
	if err != nil {
		return nil, err
	}
	if resp.StatusCode == http.StatusForbidden || resp.StatusCode == http.StatusUnauthorized {
		resp.Body.Close()
		if q.tried || q.secret == "" {
			return nil, errTorrentGiveUp
		}
		q.tried = true
		if err := q.login(ctx); err != nil {
			return nil, errTorrentGiveUp
		}
		if resp, err = q.get(ctx); err != nil {
			return nil, err
		}
		if resp.StatusCode != http.StatusOK {
			resp.Body.Close()
			return nil, errTorrentGiveUp
		}
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("qbittorrent: %s", resp.Status)
	}
	var list []qbTorrent
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return nil, err
	}
	var out []Transfer
	for _, t := range list {
		if it, ok := qbItem(t); ok {
			out = append(out, it)
		}
	}
	return out, nil
}

func (q *qbittorrent) get(ctx context.Context) (*http.Response, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, q.base+"/api/v2/torrents/info?filter=all", nil)
	if err != nil {
		return nil, err
	}
	return q.http.Do(req)
}

func (q *qbittorrent) login(ctx context.Context) error {
	user, pass, _ := strings.Cut(q.secret, ":")
	form := url.Values{"username": {user}, "password": {pass}}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, q.base+"/api/v2/auth/login", strings.NewReader(form.Encode()))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Set("Referer", q.base) // CSRF protection
	resp, err := q.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	var buf [16]byte
	n, _ := resp.Body.Read(buf[:])
	if resp.StatusCode != http.StatusOK || !strings.HasPrefix(string(buf[:n]), "Ok") {
		return fmt.Errorf("qbittorrent login refused")
	}
	return nil
}

// qbItem maps an incomplete torrent; complete ones (seeding) are skipped.
func qbItem(t qbTorrent) (Transfer, bool) {
	size := t.Size
	if size <= 0 {
		size = t.TotalSize
	}
	if t.Progress >= 1 || (size > 0 && t.AmountLeft == 0 && t.Completed >= size) {
		return Transfer{}, false
	}
	state := ""
	detail := ""
	switch t.State {
	case "downloading", "forcedDL", "metaDL", "forcedMetaDL", "allocating", "moving":
		state = StateRunning
	case "stalledDL":
		state, detail = StateRunning, "Stalled"
	case "pausedDL", "stoppedDL":
		state = StatePaused
	case "queuedDL", "checkingDL", "checkingResumeData":
		state = StateQueued
		if strings.HasPrefix(t.State, "checking") {
			detail = "Checking"
		}
	case "error", "missingFiles":
		state, detail = StateFailed, "Error"
	default:
		return Transfer{}, false // uploading, stalledUP, pausedUP, ...
	}
	it := torrentItem("qBittorrent", "qbittorrent", "qbittorrent:"+t.Hash, t.Name, t.SavePath)
	if t.ContentPath != "" {
		it.Path = t.ContentPath
	}
	it.State, it.Detail = state, detail
	if size > 0 {
		it.Total = size
		it.Processed = t.Completed
		if it.Processed <= 0 && t.Progress > 0 {
			it.Processed = int64(t.Progress * float64(size))
		}
	}
	it.Rate = t.DLSpeed
	if t.AddedOn > 0 {
		it.StartedAt = t.AddedOn * 1000
	}
	return it, true
}
