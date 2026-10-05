package transfers

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
)

// Deluge through deluge-web's JSON-RPC (the GTK client has no HTTP API).
// The web password comes from the "deluge" secret (Deluge's default is
// "deluge"). Only reads; never connects the web UI to a daemon itself.
type deluge struct {
	url      string
	password string
	http     *http.Client
	authed   bool
	tried    bool
	id       int
}

func newDeluge(o Options) *deluge {
	return &deluge{
		url:      o.Endpoint("deluge", "http://127.0.0.1:8112/json"),
		password: o.Secret("deluge", "deluge"),
		http:     newTorrentHTTP(),
	}
}

func (d *deluge) procs() []string { return []string{"deluge-web"} }

func (d *deluge) reset() {
	d.http = newTorrentHTTP()
	d.authed, d.tried = false, false
}

type delugeTorrent struct {
	Name        string  `json:"name"`
	TotalWanted int64   `json:"total_wanted"`
	TotalDone   int64   `json:"total_done"`
	Rate        float64 `json:"download_payload_rate"`
	State       string  `json:"state"`
	SavePath    string  `json:"save_path"`
	Progress    float64 `json:"progress"`
	TimeAdded   float64 `json:"time_added"`
}

func (d *deluge) call(ctx context.Context, method string, params []any, out any) error {
	d.id++
	body, _ := json.Marshal(map[string]any{"method": method, "params": params, "id": d.id})
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, d.url, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := d.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("deluge: %s", resp.Status)
	}
	var env struct {
		Result json.RawMessage `json:"result"`
		Error  *struct {
			Message string `json:"message"`
			Code    int    `json:"code"`
		} `json:"error"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&env); err != nil {
		return err
	}
	if env.Error != nil {
		if env.Error.Code == 1 { // not authenticated
			d.authed = false
		}
		return fmt.Errorf("deluge: %s", env.Error.Message)
	}
	return json.Unmarshal(env.Result, out)
}

func (d *deluge) poll(ctx context.Context) ([]Transfer, error) {
	if !d.authed {
		if d.tried {
			return nil, errTorrentGiveUp
		}
		var ok bool
		if err := d.call(ctx, "auth.login", []any{d.password}, &ok); err != nil {
			return nil, err // web UI still starting: retry later
		}
		if !ok {
			d.tried = true // wrong password: wait for a restart
			return nil, errTorrentGiveUp
		}
		d.authed = true // an expired session logs in again
	}
	var ui struct {
		Connected bool                     `json:"connected"`
		Torrents  map[string]delugeTorrent `json:"torrents"`
	}
	keys := []string{"name", "total_wanted", "total_done", "download_payload_rate", "state", "eta", "save_path", "progress", "time_added"}
	if err := d.call(ctx, "web.update_ui", []any{keys, map[string]any{}}, &ui); err != nil {
		return nil, err
	}
	var out []Transfer
	for hash, t := range ui.Torrents {
		if it, ok := delugeItem(hash, t); ok {
			out = append(out, it)
		}
	}
	return out, nil
}

func delugeItem(hash string, t delugeTorrent) (Transfer, bool) {
	if t.TotalWanted > 0 && t.TotalDone >= t.TotalWanted {
		return Transfer{}, false
	}
	if t.State == "Seeding" {
		return Transfer{}, false
	}
	it := torrentItem("Deluge", "deluge", "deluge:"+hash, t.Name, t.SavePath)
	switch t.State {
	case "Downloading", "Allocating", "Moving":
		it.State = StateRunning
	case "Paused":
		it.State = StatePaused
	case "Queued":
		it.State = StateQueued
	case "Checking":
		it.State, it.Detail = StateQueued, "Checking"
	case "Error":
		it.State, it.Detail = StateFailed, "Error"
	default:
		it.State = StateRunning
	}
	if t.TotalWanted > 0 {
		it.Total, it.Processed = t.TotalWanted, t.TotalDone
	}
	it.Rate = t.Rate
	if t.TimeAdded > 0 {
		it.StartedAt = int64(t.TimeAdded * 1000)
	}
	return it, true
}
