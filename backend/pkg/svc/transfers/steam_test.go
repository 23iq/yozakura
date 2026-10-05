package transfers

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func copyFixture(t *testing.T, name, dst string, repl ...string) {
	t.Helper()
	data, err := os.ReadFile(filepath.Join("testdata", "steam", name))
	if err != nil {
		t.Fatal(err)
	}
	text := strings.NewReplacer(repl...).Replace(string(data))
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(dst, []byte(text), 0o644); err != nil {
		t.Fatal(err)
	}
}

func setManifestField(t *testing.T, path, key, value string) {
	t.Helper()
	data, _ := os.ReadFile(path)
	lines := strings.Split(string(data), "\n")
	for i, l := range lines {
		if strings.HasPrefix(strings.TrimSpace(l), `"`+key+`"`) {
			lines[i] = "\t\"" + key + "\"\t\t\"" + value + "\""
		}
	}
	// Different size/mtime so the cache re-reads it
	os.WriteFile(path, []byte(strings.Join(lines, "\n")+"\n"), 0o644)
	future := time.Now().Add(time.Duration(len(value)) * time.Second)
	os.Chtimes(path, future, future)
}

func appendLog(t *testing.T, path string, lines ...string) {
	t.Helper()
	f, err := os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0o644)
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	for _, l := range lines {
		f.WriteString(l + "\n")
	}
}

func TestParseVDFAndManifest(t *testing.T) {
	data, _ := os.ReadFile("testdata/steam/appmanifest_1449560.acf")
	m, err := parseAppManifest(string(data))
	if err != nil {
		t.Fatal(err)
	}
	if m.AppID != "1449560" || m.Name != "Metaphor: ReFantazio" || m.Flags != 1030 ||
		m.BytesToDownload != 717637936 || m.BytesToStage != 862427602 || m.InstallDir != "Metaphor ReFantazio" {
		t.Fatalf("manifest %+v", m)
	}
	root, err := parseVDF(`"a" { "Key" "v\"q" // comment
	  "b" { } "c" "x" [$WIN32] }`)
	if err != nil || root.Child("a").Str("key") != `v"q` || root.Child("a").Child("b") == nil || root.Child("A").Str("C") != "x" {
		t.Fatalf("vdf parse: %v", err)
	}
	if _, err := parseVDF(`"a" { "b" "c"`); err == nil {
		t.Fatal("unterminated block must fail")
	}
	libs, _ := os.ReadFile("testdata/steam/libraryfolders.vdf")
	if got := parseLibraryFolders(string(libs)); len(got) != 2 || got[0] != "ROOT" || got[1] != "LIB2" {
		t.Fatalf("libraries %v", got)
	}
	if got := parseLibraryFolders(`"LibraryFolders" { "TimeNextStatsReport" "1" "1" "/mnt/games" }`); len(got) != 1 || got[0] != "/mnt/games" {
		t.Fatalf("old format libraries %v", got)
	}
}

func TestSteamLogParsing(t *testing.T) {
	l := newSteamLog()
	l.location = time.UTC
	data, _ := os.ReadFile("testdata/steam/content_log.txt")
	for _, line := range strings.Split(string(data), "\n") {
		l.Feed(line)
	}
	a := l.Apps["1449560"]
	if a == nil || !a.State["Update Running"] || !a.Phase["Downloading"] || a.DownTotal != 717637936 || a.StageTotal != 862427602 {
		t.Fatalf("app state %+v", a)
	}
	if a.ShaderDown != 4117320 || len(a.Shader) != 0 {
		t.Fatalf("shader state %+v", a)
	}
	if l.Rate != 182.66e6/8 || l.RateAt.Format("15:04:05") != "01:04:01" {
		t.Fatalf("rate %v at %v", l.Rate, l.RateAt)
	}
	l.Feed("[2026-10-05 01:06:00] AppID 1449560 state changed : Update Required,Fully Installed,Update Paused, (Update delayed for 372379 secs)")
	if !a.State["Update Paused"] || a.State["Update Running"] {
		t.Fatalf("flags with a trailing note: %+v", a.State)
	}
}

func TestSteamSourceLifecycle(t *testing.T) {
	root := t.TempDir()
	lib2 := t.TempDir()
	apps := filepath.Join(root, "steamapps")
	copyFixture(t, "libraryfolders.vdf", filepath.Join(apps, "libraryfolders.vdf"), "ROOT", root, "LIB2", lib2)
	copyFixture(t, "appmanifest_1449560.acf", filepath.Join(apps, "appmanifest_1449560.acf"))
	copyFixture(t, "appmanifest_228980.acf", filepath.Join(apps, "appmanifest_228980.acf"))
	copyFixture(t, "appmanifest_1245620.acf", filepath.Join(lib2, "steamapps", "appmanifest_1245620.acf"))
	os.MkdirAll(filepath.Join(lib2, "steamapps", "downloading", "1245620"), 0o755)
	logPath := filepath.Join(root, "logs", "content_log.txt")
	copyFixture(t, "content_log.txt", logPath)

	s := newSteamSource()
	s.log.location = time.UTC
	now := time.Date(2026, 10, 5, 1, 4, 5, 0, time.UTC)
	s.now = func() time.Time { return now }
	s.roots = steamRoots(Options{SteamRoots: []string{root, root + "/."}})
	if len(s.roots) != 1 {
		t.Fatalf("roots %v", s.roots)
	}
	libs := steamLibraries(s.roots)
	if len(libs) != 2 {
		t.Fatalf("libraries %v", libs)
	}

	items := s.scan(libs)
	if len(items) != 2 {
		t.Fatalf("want metaphor + elden ring, got %+v", items)
	}
	byKey := map[string]Transfer{}
	for _, it := range items {
		byKey[it.Key] = it
	}
	mp := byKey["1449560"]
	if mp.State != StateRunning || mp.Kind != KindUpdate || mp.Total != 717637936 || mp.Processed != 0 ||
		mp.Rate != 182.66e6/8 || mp.Title != "Metaphor: ReFantazio" || mp.OpenURL != "steam://nav/downloads" || mp.AppIcon != "steam" {
		t.Fatalf("metaphor %+v", mp)
	}
	er := byKey["1245620"]
	if er.State != StateQueued || er.Kind != KindDownload || er.Processed != 13100000000 || er.Rate != -1 {
		t.Fatalf("elden ring %+v", er)
	}

	// Progress moves; the rate line goes stale after 15s
	setManifestField(t, filepath.Join(apps, "appmanifest_1449560.acf"), "BytesDownloaded", "358818968")
	now = now.Add(20 * time.Second)
	items = s.scan(libs)
	for _, it := range items {
		if it.Key == "1449560" && (it.Processed != 358818968 || it.Rate != -1) {
			t.Fatalf("progress %+v", it)
		}
	}

	// Download done, now staging (installing)
	setManifestField(t, filepath.Join(apps, "appmanifest_1449560.acf"), "BytesDownloaded", "717637936")
	setManifestField(t, filepath.Join(apps, "appmanifest_1449560.acf"), "BytesStaged", "431213801")
	appendLog(t, logPath, "[2026-10-05 01:04:25] Current download rate: 80.000 Mbps")
	now = time.Date(2026, 10, 5, 1, 4, 30, 0, time.UTC)
	for _, it := range s.scan(libs) {
		if it.Key == "1449560" && (it.Detail != "Installing" || it.Processed != 431213801 || it.Total != 862427602 || it.Rate != 1e7) {
			t.Fatalf("staging %+v", it)
		}
	}

	// Finished: log + manifest say fully installed
	setManifestField(t, filepath.Join(apps, "appmanifest_1449560.acf"), "StateFlags", "4")
	appendLog(t, logPath,
		"[2026-10-05 01:05:00] AppID 1449560 App update changed : None",
		"[2026-10-05 01:05:00] AppID 1449560 state changed : Fully Installed,")
	now = now.Add(time.Second)
	var done *Transfer
	for _, it := range s.scan(libs) {
		if it.Key == "1449560" {
			it := it
			done = &it
		}
	}
	if done == nil || done.State != StateDone {
		t.Fatalf("expected a done item, got %+v", done)
	}
	now = now.Add(steamDoneHold + time.Second)
	for _, it := range s.scan(libs) {
		if it.Key == "1449560" {
			t.Fatalf("done item must disappear, got %+v", it)
		}
		if it.Key == "1245620" {
			t.Fatalf("an idle queue (nothing running) is hidden, got %+v", it)
		}
	}

	// Elden Ring resumes: log says running
	appendLog(t, logPath, "[2026-10-05 01:06:00] AppID 1245620 state changed : Update Required,Update Queued,Update Running,Update Started,")
	for _, it := range s.scan(libs) {
		if it.Key == "1245620" && it.State != StateRunning {
			t.Fatalf("resumed %+v", it)
		}
	}
	// ... and is paused by the user
	appendLog(t, logPath, "[2026-10-05 01:07:00] AppID 1245620 state changed : Update Required,Update Started,Update Paused,")
	for _, it := range s.scan(libs) {
		if it.Key == "1245620" && it.State != StatePaused {
			t.Fatalf("paused %+v", it)
		}
	}
}

func TestSteamShaderItemAndTailer(t *testing.T) {
	dir := t.TempDir()
	logPath := filepath.Join(dir, "content_log.txt")
	os.WriteFile(logPath, []byte("[2026-10-05 01:00:00] old line\n"), 0o644)
	tl := &tailer{path: logPath}
	if got := tl.Read(); len(got) != 1 {
		t.Fatalf("first read %v", got)
	}
	appendLog(t, logPath, "[2026-10-05 01:00:01] a")
	f, _ := os.OpenFile(logPath, os.O_APPEND|os.O_WRONLY, 0o644)
	f.WriteString("[2026-10-05 01:00:02] partial")
	f.Close()
	if got := tl.Read(); len(got) != 1 || !strings.HasSuffix(got[0], "a") {
		t.Fatalf("partial line kept back: %v", got)
	}
	appendLog(t, logPath, " line")
	if got := tl.Read(); len(got) != 1 || !strings.HasSuffix(got[0], "partial line") {
		t.Fatalf("completed line: %v", got)
	}
	// Rotation: a new, smaller file
	os.Remove(logPath)
	os.WriteFile(logPath, []byte("[2026-10-05 02:00:00] new\n"), 0o644)
	if got := tl.Read(); len(got) != 1 || !strings.HasSuffix(got[0], "new") {
		t.Fatalf("after rotation: %v", got)
	}

	s := newSteamSource()
	s.log.Feed("[2026-10-05 01:02:59] AppID 1449560 Shader update changed : Running Update,Preallocating,")
	s.log.Feed("[2026-10-05 01:02:59] AppID 1449560 update started : download 0/4117320, store 0/0, reuse 0/0, delta 0/0, stage 0/5134222 ")
	s.log.Feed("[2026-10-05 01:02:59] AppID 1449560 Shader update changed : Running Update,Downloading,Staging,")
	it, ok := s.shaderItem(&steamManifest{AppID: "1449560", Name: "Metaphor"})
	if !ok || it.Title != "Metaphor shaders" || it.Total != 4117320 || it.Kind != KindUpdate {
		t.Fatalf("shader item %+v %v", it, ok)
	}
	if s.log.Apps["1449560"].DownTotal != 0 {
		t.Fatal("shader totals must not leak into the app totals")
	}
}

func TestSteamNotInstalled(t *testing.T) {
	if r := steamRoots(Options{SteamRoots: []string{t.TempDir() + "/missing"}}); len(r) != 0 {
		t.Fatalf("roots %v", r)
	}
}
