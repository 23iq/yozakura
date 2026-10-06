package term

import (
	"encoding/json"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"yozakura/backend/pkg/termlook"
)

// Status is the state the settings page shows.
type Status struct {
	Enabled           bool            `json:"enabled"`
	Engine            string          `json:"engine"`
	FishInstalled     bool            `json:"fishInstalled"`
	FishIsLoginShell  bool            `json:"fishIsLoginShell"`
	EngineInstalled   map[string]bool `json:"engineInstalled"`
	ForeignPromptInit bool            `json:"foreignPromptInit"`
	ForeignFile       string          `json:"foreignFile,omitempty"`
	HookSkipped       bool            `json:"hookSkipped"`
	HookPath          string          `json:"hookPath"`
	HookPresent       bool            `json:"hookPresent"`
}

func (s *Service) status(json.RawMessage) (any, error) { return s.currentStatus(), nil }

var foreignInit = regexp.MustCompile(`(^|[^\w-])(starship|oh-my-posh)\s+init\s+fish\b`)

func (s *Service) currentStatus() Status {
	cfg := s.config()
	env := s.o.Env
	st := Status{Enabled: cfg.Enabled, Engine: cfg.Engine, EngineInstalled: map[string]bool{}, HookPath: termlook.HookFile(env)}
	_, st.FishInstalled = env.LookPath("fish")
	_, st.EngineInstalled[termlook.EngineStarship] = env.LookPath("starship")
	_, st.EngineInstalled[termlook.EngineOMP] = env.LookPath("oh-my-posh")
	_, err := os.Stat(st.HookPath)
	st.HookPresent = err == nil
	st.FishIsLoginShell = s.fishIsLoginShell()
	st.ForeignFile = s.foreignFile()
	st.ForeignPromptInit = st.ForeignFile != ""
	st.HookSkipped = cfg.Enabled && st.ForeignPromptInit
	return st
}

// foreignFile is the fish file that starts a prompt engine itself ("").
func (s *Service) foreignFile() string {
	return foreignPromptFile(filepath.Join(s.o.Env.ConfigHome, "fish"), termlook.HookFile(s.o.Env))
}

// fishIsLoginShell reads the user's passwd entry.
func (s *Service) fishIsLoginShell() bool {
	if s.o.Passwd == nil || s.o.User == nil {
		return false
	}
	name := s.o.User()
	data, err := s.o.Passwd()
	if name == "" || err != nil {
		return false
	}
	for _, line := range strings.Split(string(data), "\n") {
		f := strings.Split(line, ":")
		if len(f) >= 7 && f[0] == name {
			return filepath.Base(f[6]) == "fish"
		}
	}
	return false
}

// foreignPromptFile returns the first of config.fish and conf.d/*.fish
// (other than our hook) that initializes starship or oh-my-posh itself.
func foreignPromptFile(fishDir, hook string) string {
	files := []string{filepath.Join(fishDir, "config.fish")}
	if more, err := filepath.Glob(filepath.Join(fishDir, "conf.d", "*.fish")); err == nil {
		files = append(files, more...)
	}
	for _, f := range files {
		if f == hook {
			continue
		}
		data, err := os.ReadFile(f)
		if err != nil {
			continue
		}
		for _, line := range strings.Split(string(data), "\n") {
			if t := strings.TrimSpace(line); !strings.HasPrefix(t, "#") && foreignInit.MatchString(t) {
				return f
			}
		}
	}
	return ""
}
