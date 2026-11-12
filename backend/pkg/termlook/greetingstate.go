package termlook

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"slices"
)

// The greeting's own machine-local record (<data>/<app>/greeting.json,
// never in a config domain, so no preset or config edit carries it):
//
//	shells: "all" once the user switched the greeting on in this version
//	        (Settings, the setup wizard, `term greeting on`). Without it
//	        the greeting stays in fish, as it was before bash and zsh were
//	        supported, and ~/.bashrc / ~/.zshrc are never edited.
//	dirs:   directories the fish file needed and the greeting created
//	        (~/.config/fish, its conf.d); removed again when empty.

type greetingRecord struct {
	Shells string   `json:"shells,omitempty"`
	Dirs   []string `json:"dirs,omitempty"`
}

const shellsAll = "all"

func greetingRecordFile(env Env) string {
	return filepath.Join(env.hooksEnv().DataDir, "greeting.json")
}

func readGreetingRecord(env Env) greetingRecord {
	var r greetingRecord
	if data, err := os.ReadFile(greetingRecordFile(env)); err == nil {
		_ = json.Unmarshal(data, &r)
	}
	return r
}

func writeGreetingRecord(env Env, r greetingRecord) error {
	data, err := json.MarshalIndent(r, "", "  ")
	if err != nil {
		return err
	}
	return writeAtomic(greetingRecordFile(env), append(data, '\n'))
}

// GreetingAllShells reports whether the user let the greeting into bash and
// zsh (their rc files); false: fish only.
func GreetingAllShells(env Env) bool { return readGreetingRecord(env).Shells == shellsAll }

// AllowGreetingShells records the user's choice of the greeting in every
// shell (an explicit action: the Settings switch, the wizard, the CLI).
func AllowGreetingShells(env Env) error {
	r := readGreetingRecord(env)
	if r.Shells == shellsAll {
		return nil
	}
	r.Shells = shellsAll
	return writeGreetingRecord(env, r)
}

// writeOwnedFile writes path, recording the directories above it (up to
// stop) that it creates.
func writeOwnedFile(env Env, path, stop string, data []byte) error {
	var created []string
	for d := filepath.Dir(path); d != stop && len(d) > len(stop); d = filepath.Dir(d) {
		if _, err := os.Stat(d); err == nil {
			break
		}
		created = append(created, d)
	}
	if len(created) > 0 {
		r := readGreetingRecord(env)
		for _, d := range created {
			if !slices.Contains(r.Dirs, d) {
				r.Dirs = append(r.Dirs, d)
			}
		}
		if err := writeGreetingRecord(env, r); err != nil {
			return err
		}
	}
	return writeAtomic(path, data)
}

// removeOwnedDirs removes the recorded directories that are empty now
// (deepest first) and forgets them.
func removeOwnedDirs(env Env) {
	r := readGreetingRecord(env)
	if len(r.Dirs) == 0 {
		return
	}
	dirs := slices.Clone(r.Dirs)
	slices.SortFunc(dirs, func(a, b string) int { return len(b) - len(a) })
	var kept []string
	for _, d := range dirs {
		err := os.Remove(d)
		if err != nil && !errors.Is(err, os.ErrNotExist) {
			kept = append(kept, d) // not empty (theirs now) or not ours to remove
		}
	}
	r.Dirs = kept
	_ = writeGreetingRecord(env, r)
}
