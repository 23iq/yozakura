package usage

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"time"
)

// Ledger is the append-only usage log: one JSONL file per (local) month.
// Parsed months are cached; Append keeps the cache in sync. It is safe for
// concurrent use within one process.
type Ledger struct {
	dir   string
	mu    sync.Mutex
	cache map[string][]Record // month key -> records
}

// NewLedger stores its files in dir (created on first append).
func NewLedger(dir string) *Ledger {
	return &Ledger{dir: dir, cache: map[string][]Record{}}
}

// Dir is the ledger directory.
func (l *Ledger) Dir() string { return l.dir }

func monthKey(t time.Time) string { return t.Local().Format("2006-01") }

func (l *Ledger) file(month string) string { return filepath.Join(l.dir, month+".jsonl") }

// Append writes r to the file of its month.
func (l *Ledger) Append(r Record) error {
	data, err := json.Marshal(r)
	if err != nil {
		return err
	}
	l.mu.Lock()
	defer l.mu.Unlock()
	if err := os.MkdirAll(l.dir, 0o700); err != nil {
		return err
	}
	month := monthKey(r.Time)
	f, err := os.OpenFile(l.file(month), os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o600)
	if err != nil {
		return err
	}
	_, werr := f.Write(append(data, '\n'))
	cerr := f.Close()
	if werr != nil {
		return werr
	}
	if cerr != nil {
		return cerr
	}
	if recs, ok := l.cache[month]; ok {
		l.cache[month] = append(recs, r)
	}
	return nil
}

// Months lists the month keys that have a file, oldest first.
func (l *Ledger) Months() []string {
	entries, err := os.ReadDir(l.dir)
	if err != nil {
		return nil
	}
	var out []string
	for _, e := range entries {
		name := e.Name()
		if e.IsDir() || !strings.HasSuffix(name, ".jsonl") {
			continue
		}
		key := strings.TrimSuffix(name, ".jsonl")
		if _, err := time.Parse("2006-01", key); err == nil {
			out = append(out, key)
		}
	}
	sort.Strings(out)
	return out
}

// Between returns the records with from <= time < to (zero to: no bound).
func (l *Ledger) Between(from, to time.Time) ([]Record, error) {
	var out []Record
	for _, month := range l.Months() {
		start, _ := time.ParseInLocation("2006-01", month, time.Local)
		end := start.AddDate(0, 1, 0)
		if !end.After(from) || (!to.IsZero() && !start.Before(to)) {
			continue
		}
		recs, err := l.load(month)
		if err != nil {
			return nil, err
		}
		for _, r := range recs {
			if r.Time.Before(from) || (!to.IsZero() && !r.Time.Before(to)) {
				continue
			}
			out = append(out, r)
		}
	}
	return out, nil
}

func (l *Ledger) load(month string) ([]Record, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	if recs, ok := l.cache[month]; ok {
		return recs, nil
	}
	f, err := os.Open(l.file(month))
	if os.IsNotExist(err) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	defer f.Close()
	var recs []Record
	sc := bufio.NewScanner(f)
	sc.Buffer(make([]byte, 64*1024), 1024*1024)
	for sc.Scan() {
		line := sc.Bytes()
		if len(strings.TrimSpace(string(line))) == 0 {
			continue
		}
		var r Record
		if json.Unmarshal(line, &r) != nil {
			continue // a torn or foreign line must not hide the rest
		}
		recs = append(recs, r)
	}
	if err := sc.Err(); err != nil {
		return nil, fmt.Errorf("usage: read %s: %w", month, err)
	}
	l.cache[month] = recs
	return recs, nil
}
