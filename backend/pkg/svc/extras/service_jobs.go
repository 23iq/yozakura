package extras

import (
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"path/filepath"
	"regexp"
	"strings"
)

// Close empties the install queue for a daemon stop or reload: queued jobs
// are dropped, a running system/AUR install is waited for (logged).
func (s *Service) Close() {
	s.q.Shutdown(func(line string) { log.Printf("[extras] %s", line) })
}

var reModel = regexp.MustCompile(`^[a-z0-9._:/-]+$`)

func (s *Service) ollamaPull(params json.RawMessage) (any, error) {
	var p struct {
		Model string `json:"model"`
	}
	if err := json.Unmarshal(params, &p); err != nil || !reModel.MatchString(p.Model) || strings.HasPrefix(p.Model, "-") {
		return nil, errors.New("invalid model name")
	}
	return s.enqueue([]Job{{ID: newJobID(KindOllama), Kind: KindOllama, Entries: []string{},
		Names: []string{p.Model}, Argv: []string{"ollama", "pull", p.Model}}}), nil
}

// validShell reports whether shell is an absolute path listed in /etc/shells
// (the privileged helper checks again).
func validShell(etcShells []byte, shell string) bool {
	if !strings.HasPrefix(shell, "/") || strings.ContainsAny(shell, " \t\r\n") {
		return false
	}
	for _, l := range strings.Split(string(etcShells), "\n") {
		if strings.TrimSpace(l) == shell {
			return true
		}
	}
	return false
}

func (s *Service) setLoginShell(params json.RawMessage) (any, error) {
	var p struct {
		Shell string `json:"shell"`
	}
	if err := json.Unmarshal(params, &p); err != nil || p.Shell == "" {
		return nil, errors.New("shell is required")
	}
	shells, err := s.o.ReadFile("/etc/shells")
	if err != nil || !validShell(shells, p.Shell) {
		return nil, fmt.Errorf("shell %q is not listed in /etc/shells", p.Shell)
	}
	name := s.o.User()
	if name == "" {
		return nil, errors.New("can't determine the current user")
	}
	return s.enqueue([]Job{{ID: newJobID(KindLogin), Kind: KindLogin, Entries: []string{},
		Names: []string{"login shell"}, NeedsRoot: true,
		Argv: []string{"pkexec", s.o.Self(), "sys", "chsh", name, p.Shell}}}), nil
}

var reJobID = regexp.MustCompile(`^[a-z]+-\d+$`)

const maxLogBytes = 256 << 10

func (s *Service) log(params json.RawMessage) (any, error) {
	id, err := jobParam(params)
	if err != nil {
		return nil, err
	}
	if !reJobID.MatchString(id) {
		return nil, errors.New("bad job id")
	}
	data, err := s.o.ReadFile(filepath.Join(s.q.logDir, id+".log"))
	if err != nil {
		return nil, codeOf(ErrUnknownJob)
	}
	if len(data) > maxLogBytes {
		data = data[len(data)-maxLogBytes:]
	}
	return map[string]any{"text": string(data)}, nil
}
