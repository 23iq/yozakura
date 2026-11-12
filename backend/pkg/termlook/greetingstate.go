package termlook

import (
	"encoding/json"
	"os"
	"path/filepath"
)

// The greeting's own machine-local record (<data>/<app>/greeting.json,
// never in a config domain, so no preset or config edit carries it):
//
//	shells: "all" once the user switched the greeting on in this version
//	        (Settings, the setup wizard, `term greeting on`). Without it
//	        the greeting stays in fish, as it was before bash and zsh were
//	        supported, and ~/.bashrc / ~/.zshrc are never edited.

type greetingRecord struct {
	Shells string `json:"shells,omitempty"`
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
