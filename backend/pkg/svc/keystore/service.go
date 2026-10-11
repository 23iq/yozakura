package keystore

import (
	"bytes"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/ipc"
	"yozakura/backend/pkg/paths"
)

// Service stores API keys in an sqlite DB (0600). Values are only obfuscated
// (XOR with the machine-id salt, byte-compatible with the legacy
// scripts/keystore.py flow), not encrypted: the file permissions are the
// protection. SQL is fed through stdin so secrets never appear in argv.
type Service struct {
	paths *paths.Paths
	db    string
	lock  chan struct{}
}

func NewService(p *paths.Paths) *Service {
	return &Service{
		paths: p,
		db:    p.KeysDB(),
		lock:  make(chan struct{}, 1),
	}
}

func (s *Service) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "keystore",
		Methods: map[string]ipc.HandlerFunc{
			"get":    s.get,
			"set":    s.set,
			"delete": s.delete,
			"list":   s.list,
			"has":    s.has,
		},
	})
}

type entry struct {
	Provider   string `json:"provider"`
	APIKey     string `json:"api_key"`
	Endpoint   string `json:"endpoint"`
	CustomCurl string `json:"custom_curl"`
}

func machineKey() []byte {
	data, err := os.ReadFile("/etc/machine-id")
	if err == nil && len(strings.TrimSpace(string(data))) > 0 {
		return []byte(strings.TrimSpace(string(data)))
	}
	// Legacy literal on purpose: changing the salt would make keys stored
	// by earlier versions undecryptable.
	return []byte(brand.LegacyAppID + "-fallback-salt-82741")
}

func xorCrypt(data, key []byte) []byte {
	out := make([]byte, len(data))
	for i, b := range data {
		out[i] = b ^ key[i%len(key)]
	}
	return out
}

func encrypt(text string, key []byte) string {
	return hex.EncodeToString(xorCrypt([]byte(text), key))
}

func decrypt(hexStr string, key []byte) string {
	enc, err := hex.DecodeString(hexStr)
	if err != nil {
		return ""
	}
	return string(xorCrypt(enc, key))
}

const schema = `CREATE TABLE IF NOT EXISTS api_keys (
	provider TEXT PRIMARY KEY,
	api_key TEXT NOT NULL,
	endpoint TEXT DEFAULT '',
	custom_curl TEXT DEFAULT ''
);`

// ensureDB creates the directory, the file and the table; every path that
// touches the database goes through it (query), so a clean install works.
// Callers hold s.lock.
func (s *Service) ensureDB() error {
	if err := os.MkdirAll(filepath.Dir(s.db), 0o755); err != nil {
		return err
	}
	if _, err := os.Stat(s.db); err != nil {
		f, cerr := os.OpenFile(s.db, os.O_CREATE|os.O_WRONLY, 0o600)
		if cerr != nil {
			return cerr
		}
		f.Close()
	}
	if err := os.Chmod(s.db, 0o600); err != nil {
		return err
	}
	return s.exec(schema)
}

// exec feeds the SQL through stdin so secrets never reach argv
// (/proc/<pid>/cmdline).
func (s *Service) exec(sql string) error {
	_, err := s.run(sql)
	return err
}

func (s *Service) run(sql string, flags ...string) (string, error) {
	bin, err := exec.LookPath("sqlite3")
	if err != nil {
		return "", errors.New("sqlite3 is not installed")
	}
	cmd := exec.Command(bin, append(flags, s.db)...)
	cmd.Stdin = strings.NewReader(sql)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	out, err := cmd.Output()
	if err != nil {
		if msg := strings.TrimSpace(stderr.String()); msg != "" {
			return "", errors.New(msg)
		}
		return "", err
	}
	return string(out), nil
}

// query runs SQL against the ensured database and returns the output.
func (s *Service) query(sql string, flags ...string) (string, error) {
	s.lock <- struct{}{}
	defer func() { <-s.lock }()
	if err := s.ensureDB(); err != nil {
		return "", err
	}
	return s.run(sql, flags...)
}

// selectRows returns decoded rows; text columns are hex()-encoded in SQL so
// separators and newlines inside values cannot break parsing.
func (s *Service) selectRows(where string) ([]entry, error) {
	out, err := s.query(`SELECT hex(provider), api_key, hex(endpoint), hex(custom_curl) FROM api_keys `+where+`;`,
		"-separator", "\x1f")
	if err != nil {
		return nil, err
	}
	key := machineKey()
	var res []entry
	for _, row := range strings.Split(out, "\n") {
		f := strings.Split(strings.TrimSpace(row), "\x1f")
		if len(f) < 4 {
			continue
		}
		res = append(res, entry{
			Provider:   unhex(f[0]),
			APIKey:     decrypt(f[1], key),
			Endpoint:   unhex(f[2]),
			CustomCurl: unhex(f[3]),
		})
	}
	return res, nil
}

func unhex(s string) string {
	b, err := hex.DecodeString(s)
	if err != nil {
		return ""
	}
	return string(b)
}

func (s *Service) get(params json.RawMessage) (any, error) {
	var p struct {
		Provider string `json:"provider"`
	}
	json.Unmarshal(params, &p)
	if p.Provider == "" {
		return map[string]any{"error": "get requires provider"}, nil
	}
	rows, err := s.selectRows(`WHERE provider = ` + qsql(p.Provider))
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	if len(rows) == 0 {
		return map[string]any{"error": fmt.Sprintf("Provider '%s' not found", p.Provider)}, nil
	}
	e := rows[0]
	return map[string]any{"provider": e.Provider, "api_key": e.APIKey,
		"endpoint": e.Endpoint, "custom_curl": e.CustomCurl}, nil
}

func (s *Service) set(params json.RawMessage) (any, error) {
	var p struct {
		Provider   string `json:"provider"`
		APIKey     string `json:"api_key"`
		Endpoint   string `json:"endpoint"`
		CustomCurl string `json:"custom_curl"`
	}
	json.Unmarshal(params, &p)
	// A key-less entry is valid when it carries an endpoint (a custom
	// OpenAI-compatible server without authentication).
	if p.Provider == "" || (p.APIKey == "" && p.Endpoint == "") {
		return map[string]any{"error": "set requires provider and api_key or endpoint"}, nil
	}
	key := machineKey()
	enc := encrypt(p.APIKey, key)
	_, err := s.query(`INSERT OR REPLACE INTO api_keys (provider, api_key, endpoint, custom_curl) VALUES (` +
		qsql(p.Provider) + `,` + qsql(enc) + `,` + qsql(p.Endpoint) + `,` + qsql(p.CustomCurl) + `);`)
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	return map[string]any{"status": "ok"}, nil
}

func (s *Service) delete(params json.RawMessage) (any, error) {
	var p struct {
		Provider string `json:"provider"`
	}
	json.Unmarshal(params, &p)
	if p.Provider == "" {
		return map[string]any{"error": "delete requires provider"}, nil
	}
	_, err := s.query(`DELETE FROM api_keys WHERE provider = ` + qsql(p.Provider) + `;`)
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	return map[string]any{"status": "ok"}, nil
}

func (s *Service) list(params json.RawMessage) (any, error) {
	rows, err := s.selectRows("")
	if err != nil {
		return nil, err
	}
	if rows == nil {
		rows = []entry{}
	}
	return rows, nil
}

// Credential is one stored provider credential (in-process use only:
// never send APIKey to a client that did not ask for it by provider).
type Credential struct {
	Provider, APIKey, Endpoint string
}

// Credentials lists the stored credentials (empty when none or on error).
func (s *Service) Credentials() []Credential {
	list, _ := s.selectRows("")
	out := make([]Credential, 0, len(list))
	for _, e := range list {
		out = append(out, Credential{Provider: e.Provider, APIKey: e.APIKey, Endpoint: e.Endpoint})
	}
	return out
}

func (s *Service) has(params json.RawMessage) (any, error) {
	var p struct {
		Provider string `json:"provider"`
	}
	json.Unmarshal(params, &p)
	if p.Provider == "" {
		return false, nil
	}
	out, err := s.query(`SELECT 1 FROM api_keys WHERE provider = ` + qsql(p.Provider) + `;`)
	return err == nil && strings.TrimSpace(out) != "", nil
}

func qsql(s string) string {
	return "'" + strings.ReplaceAll(s, "'", "''") + "'"
}
