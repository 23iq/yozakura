package voice

import (
	"os"
	"path/filepath"
	"strings"
)

// VADModelFile is the Silero VAD model scripts/voice_setup.sh downloads.
const VADModelFile = "ggml-silero-v6.2.0.bin"

// Install describes the user-local whisper.cpp install created by
// scripts/voice_setup.sh under <data>/whisper.
type Install struct {
	Root string
}

// NewInstall resolves the install under the yozakura data dir.
func NewInstall(dataDir string) Install {
	return Install{Root: filepath.Join(dataDir, "whisper")}
}

func (i Install) ServerBin() string { return filepath.Join(i.Root, "bin", "whisper-server") }
func (i Install) ModelsDir() string { return filepath.Join(i.Root, "models") }
func (i Install) VADModel() string  { return filepath.Join(i.ModelsDir(), VADModelFile) }

// ModelPath maps a model name ("large-v3-turbo-q5_0") or a file name
// ("ggml-foo.bin") or an absolute path to the model file.
func (i Install) ModelPath(name string) string {
	if filepath.IsAbs(name) {
		return name
	}
	if strings.HasSuffix(name, ".bin") {
		return filepath.Join(i.ModelsDir(), name)
	}
	return filepath.Join(i.ModelsDir(), "ggml-"+name+".bin")
}

// Backend reports "cuda", "vulkan" or "cpu" from BUILD_INFO, "" when not installed.
func (i Install) Backend() string {
	data, err := os.ReadFile(filepath.Join(i.Root, "BUILD_INFO"))
	if err != nil {
		return ""
	}
	for _, line := range strings.Split(string(data), "\n") {
		if v, ok := strings.CutPrefix(line, "backend="); ok {
			return strings.TrimSpace(v)
		}
	}
	return ""
}

// Models lists installed whisper models by name (without ggml-/.bin).
func (i Install) Models() []string {
	entries, err := os.ReadDir(i.ModelsDir())
	if err != nil {
		return []string{}
	}
	out := []string{}
	for _, e := range entries {
		n := e.Name()
		if e.IsDir() || !strings.HasPrefix(n, "ggml-") || !strings.HasSuffix(n, ".bin") || strings.Contains(n, "silero") {
			continue
		}
		out = append(out, strings.TrimSuffix(strings.TrimPrefix(n, "ggml-"), ".bin"))
	}
	return out
}

func fileExists(p string) bool {
	st, err := os.Stat(p)
	return err == nil && !st.IsDir()
}
