package transfers

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"strings"
)

// Transmission RPC (transmission-daemon, -gtk, -qt with remote access on).
// Credentials, if RPC auth is enabled, come from the "transmission" secret
// ("user:password").
type transmission struct {
	url     string
	secret  string
	http    *http.Client
	session string
}

func newTransmission(o Options) *transmission {
	return &transmission{
		url:    o.Endpoint("transmission", "http://127.0.0.1:9091/transmission/rpc"),
		secret: o.Secret("transmission", ""),
		http:   newTorrentHTTP(),
	}
}

func (t *transmission) procs() []string {
	return []string{"transmission-da", "transmission-daemon", "transmission-gt", "transmission-gtk", "transmission-qt"}
}

func (t *transmission) reset() {
	t.http = newTorrentHTTP()
	t.session = ""
}

var transmissionFields = []string{"id", "hashString", "name", "totalSize", "sizeWhenDone", "leftUntilDone",
	"rateDownload", "status", "eta", "downloadDir", "percentDone", "error", "errorString", "addedDate"}

type trTorrent struct {
	ID            int64   `json:"id"`
	Hash          string  `json:"hashString"`
	Name          string  `json:"name"`
	TotalSize     int64   `json:"totalSize"`
	SizeWhenDone  int64   `json:"sizeWhenDone"`
	LeftUntilDone int64   `json:"leftUntilDone"`
	RateDownload  float64 `json:"rateDownload"`
	Status        int     `json:"status"`
	DownloadDir   string  `json:"downloadDir"`
	Error         int     `json:"error"`
	ErrorString   string  `json:"errorString"`
	AddedDate     int64   `json:"addedDate"`
}

func (t *transmission) poll(ctx context.Context) ([]Transfer, error) {
	body, _ := json.Marshal(map[string]any{
		"method":    "torrent-get",
		"arguments": map[string]any{"fields": transmissionFields},
	})
	var resp *http.Response
	for attempt := 0; attempt < 2; attempt++ {
		req, err := http.NewRequestWithContext(ctx, http.MethodPost, t.url, bytes.NewReader(body))
		if err != nil {
			return nil, err
		}
		req.Header.Set("Content-Type", "application/json")
		if t.session != "" {
			req.Header.Set("X-Transmission-Session-Id", t.session)
		}
		if t.secret != "" {
			user, pass, _ := strings.Cut(t.secret, ":")
			req.SetBasicAuth(user, pass)
		}
		resp, err = t.http.Do(req)
		if err != nil {
			return nil, err
		}
		if resp.StatusCode == http.StatusConflict {
			// CSRF handshake: retry with the session id we were handed
			t.session = resp.Header.Get("X-Transmission-Session-Id")
			resp.Body.Close()
			continue
		}
		break
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusUnauthorized || resp.StatusCode == http.StatusForbidden {
		return nil, errTorrentGiveUp
	}
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("transmission: %s", resp.Status)
	}
	var out struct {
		Result    string `json:"result"`
		Arguments struct {
			Torrents []trTorrent `json:"torrents"`
		} `json:"arguments"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return nil, err
	}
	if out.Result != "success" {
		return nil, fmt.Errorf("transmission: %s", out.Result)
	}
	var items []Transfer
	for _, tr := range out.Arguments.Torrents {
		if it, ok := trItem(tr); ok {
			items = append(items, it)
		}
	}
	return items, nil
}

func trItem(t trTorrent) (Transfer, bool) {
	if t.LeftUntilDone <= 0 {
		return Transfer{}, false
	}
	key := t.Hash
	if key == "" {
		key = strconv.FormatInt(t.ID, 10)
	}
	it := torrentItem("Transmission", "transmission", "transmission:"+key, t.Name, t.DownloadDir)
	switch t.Status {
	case 4:
		it.State = StateRunning
	case 3:
		it.State = StateQueued
	case 1, 2:
		it.State, it.Detail = StateQueued, "Checking"
	default: // 0 stopped (5/6 are seeding, filtered by leftUntilDone)
		it.State = StatePaused
	}
	if t.Error != 0 {
		it.State, it.Detail = StateFailed, t.ErrorString
	}
	if t.SizeWhenDone > 0 {
		it.Total = t.SizeWhenDone
		it.Processed = t.SizeWhenDone - t.LeftUntilDone
	}
	it.Rate = t.RateDownload
	if t.AddedDate > 0 {
		it.StartedAt = t.AddedDate * 1000
	}
	return it, true
}
