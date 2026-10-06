package main

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"

	"yozakura/backend/pkg/brand"
)

// fakeDryRunHome lays out a user's dirs and a fake qs that records what it
// was started with, changes the (sandboxed) config and writes a journal.
func fakeDryRunHome(t *testing.T) (dryRunEnv, string) {
	t.Helper()
	root := t.TempDir()
	home := filepath.Join(root, "home")
	write := func(rel, text string) {
		p := filepath.Join(home, rel)
		mustOK(t, os.MkdirAll(filepath.Dir(p), 0o755))
		mustOK(t, os.WriteFile(p, []byte(text), 0o644))
	}
	write(".config/"+brand.AppID+"/config/general.json", `{"onboardingDone":true}`)
	write(".config/fontconfig/fonts.conf", "<fontconfig/>")
	write(".cache/"+brand.AppID+"/wallpapers.json", `{"currentWall":"/w/a.png"}`)
	write(".cache/"+brand.AppID+"/thumbnails/a.png.jpg", "jpg")
	write(".local/state/"+brand.AppID+"/states.json", `{"onboarding":{"step":"look"}}`)

	shell := filepath.Join(root, "shell")
	mustOK(t, os.MkdirAll(shell, 0o755))
	mustOK(t, os.WriteFile(filepath.Join(shell, "onboarding-dryrun.qml"), []byte("ShellRoot {}"), 0o644))

	seen := filepath.Join(root, "seen.txt")
	qs := filepath.Join(root, "qs")
	p := brand.EnvPrefix
	script := `#!/bin/sh
{
  echo "args=$*"
  echo "dryrun=$` + p + `DRYRUN"
  echo "dir=$` + p + `DRYRUN_DIR"
  echo "config=$XDG_CONFIG_HOME"
  echo "cache=$XDG_CACHE_HOME"
  echo "state=$XDG_STATE_HOME"
  echo "general=$(cat "$XDG_CONFIG_HOME/` + brand.AppID + `/config/general.json")"
  echo "wall=$(cat "$XDG_CACHE_HOME/` + brand.AppID + `/wallpapers.json")"
  echo "states=$(cat "$XDG_STATE_HOME/` + brand.AppID + `/states.json")"
  echo "font=$(cat "$XDG_CONFIG_HOME/fontconfig/fonts.conf")"
  echo "thumb=$(cat "$XDG_CACHE_HOME/` + brand.AppID + `/thumbnails/a.png.jpg")"
} > "` + seen + `"
echo '{"onboardingDone":false}' > "$XDG_CONFIG_HOME/` + brand.AppID + `/config/general.json"
printf 'apply display DP-1 2560x1440@165\ninstall firefox, steam\n' > "$` + p + `DRYRUN_DIR/dryrun.log"
`
	mustOK(t, os.WriteFile(qs, []byte(script), 0o755))

	tmp := filepath.Join(root, "tmp")
	mustOK(t, os.MkdirAll(tmp, 0o755))
	return dryRunEnv{
		configHome: filepath.Join(home, ".config"),
		cacheHome:  filepath.Join(home, ".cache"),
		stateHome:  filepath.Join(home, ".local/state"),
		tmpParent:  tmp,
		qs:         qs,
		shellDir:   shell,
		environ:    []string{"PATH=" + os.Getenv("PATH"), "HOME=" + home},
	}, seen
}

func mustOK(t *testing.T, err error) {
	t.Helper()
	if err != nil {
		t.Fatal(err)
	}
}

func codeErr(code int) error {
	if code != 0 {
		return fmt.Errorf("exit code %d", code)
	}
	return nil
}

func seenValues(t *testing.T, path string) map[string]string {
	t.Helper()
	data, err := os.ReadFile(path)
	mustOK(t, err)
	out := map[string]string{}
	for _, line := range strings.Split(strings.TrimSpace(string(data)), "\n") {
		k, v, _ := strings.Cut(line, "=")
		out[k] = v
	}
	return out
}

func TestOnboardingDryRunSandboxAndJournal(t *testing.T) {
	env, seenFile := fakeDryRunHome(t)
	var out, errOut bytes.Buffer
	code := runOnboardingDryRun([]string{"--dry-run"}, env, &out, &errOut)
	if !assert.Equal(t, 0, code, errOut.String()) {
		t.FailNow()
	}

	seen := seenValues(t, seenFile)
	dir := seen["dir"]
	assert.Equal(t, "-p "+filepath.Join(env.shellDir, "onboarding-dryrun.qml"), seen["args"])
	assert.Equal(t, "1", seen["dryrun"])
	assert.True(t, strings.HasPrefix(dir, env.tmpParent+"/"), dir)
	assert.Equal(t, filepath.Join(dir, "config"), seen["config"])
	assert.Equal(t, filepath.Join(dir, "cache"), seen["cache"])
	assert.Equal(t, filepath.Join(dir, "state"), seen["state"])
	assert.Equal(t, `{"onboardingDone":true}`, seen["general"], "config copied")
	assert.Equal(t, `{"currentWall":"/w/a.png"}`, seen["wall"], "wallpapers.json copied")
	assert.Equal(t, `{"onboarding":{"step":"look"}}`, seen["states"], "state file copied")
	assert.Equal(t, "<fontconfig/>", seen["font"], "other apps' config stays readable")
	assert.Equal(t, "jpg", seen["thumb"], "cache folders stay readable")

	real, err := os.ReadFile(filepath.Join(env.configHome, brand.AppID, "config/general.json"))
	mustOK(t, err)
	assert.Equal(t, `{"onboardingDone":true}`, string(real), "the real config is untouched")

	assert.Contains(t, out.String(), "apply display DP-1 2560x1440@165")
	assert.Contains(t, out.String(), "install firefox, steam")
	_, err = os.Stat(dir)
	assert.True(t, os.IsNotExist(err), "temp dir removed")
}

func TestOnboardingDryRunKeep(t *testing.T) {
	env, seenFile := fakeDryRunHome(t)
	var out, errOut bytes.Buffer
	mustOK(t, codeErr(runOnboardingDryRun([]string{"--dry-run", "--keep"}, env, &out, &errOut)))
	dir := seenValues(t, seenFile)["dir"]
	_, err := os.Stat(filepath.Join(dir, "dryrun.log"))
	assert.NoError(t, err, "--keep keeps the temp dir")
	assert.Contains(t, out.String(), dir)
}

func TestOnboardingDryRunEmptyJournal(t *testing.T) {
	env, _ := fakeDryRunHome(t)
	mustOK(t, os.WriteFile(env.qs, []byte("#!/bin/sh\nexit 0\n"), 0o755))
	var out, errOut bytes.Buffer
	mustOK(t, codeErr(runOnboardingDryRun([]string{"--dry-run"}, env, &out, &errOut)))
	assert.Contains(t, out.String(), "nothing")
}

func TestOnboardingDryRunErrors(t *testing.T) {
	env, _ := fakeDryRunHome(t)
	var out, errOut bytes.Buffer
	assert.Equal(t, 2, runOnboardingDryRun([]string{"--dry-run", "--bogus"}, env, &out, &errOut))

	mustOK(t, os.Remove(filepath.Join(env.shellDir, "onboarding-dryrun.qml")))
	errOut.Reset()
	assert.Equal(t, 1, runOnboardingDryRun([]string{"--dry-run"}, env, &out, &errOut))
	assert.Contains(t, errOut.String(), "onboarding-dryrun.qml")
	left, _ := os.ReadDir(env.tmpParent)
	assert.Empty(t, left, "no temp dir left behind")
}

func TestIsDryRunArgs(t *testing.T) {
	assert.True(t, isDryRunArgs([]string{"--dry-run"}))
	assert.True(t, isDryRunArgs([]string{"--keep", "--dry-run"}))
	assert.False(t, isDryRunArgs(nil))
}
