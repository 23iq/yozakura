package extras

import "testing"

// An npm registry "401 Not authorized" is a plain failure, not a dismissed
// polkit dialog: it must not cancel the rest of the batch.
func TestQueueNpmNotAuthorizedIsPlainFailure(t *testing.T) {
	f := &fakeRunner{steps: map[string]fakeStep{"npm i": {
		lines: []string{"npm error code E401", "npm error Not authorized to access package"}, code: 1,
	}}}
	q, r := newTestQueue(t, f)
	q.Enqueue([]Job{job("n", KindNpm, "npm", "i"), job("m", KindNpm, "npm", "j")})
	q.Wait()
	fin := r.final()
	if fin["n"].State != JobFailed || fin["n"].Reason != ReasonError {
		t.Errorf("n = %+v", fin["n"])
	}
	if fin["m"].State != JobDone {
		t.Errorf("rest of the batch = %+v", fin["m"])
	}
}

func TestQueueLoginShellDismissCancels(t *testing.T) {
	f := &fakeRunner{steps: map[string]fakeStep{"pkexec y sys chsh a /bin/fish": {lines: []string{"Error: Not authorized"}, code: 1}}}
	q, r := newTestQueue(t, f)
	q.Enqueue([]Job{job("c", KindLogin, "pkexec", "y", "sys", "chsh", "a", "/bin/fish")})
	q.Wait()
	if p := r.final()["c"]; p.State != JobCancelled || p.Reason != ReasonAuthCancelled {
		t.Errorf("c = %+v", p)
	}
}

func TestParseLineOllama(t *testing.T) {
	cases := []struct {
		line  string
		pct   int
		phase string
		ok    bool
	}{
		{"\x1b[?25lpulling 8eeb52dfb3bb:  45% ▕██████    ▏ 2.1 GB/4.7 GB  12 MB/s", 45, "pulling 8eeb52dfb3bb", true},
		{"pulling 8eeb52dfb3bb: 100% ▕████████████████▏ 4.7 GB", 100, "pulling 8eeb52dfb3bb", true},
		{"pulling manifest", -1, "pulling manifest", true},
		{"verifying sha256 digest", -1, "verifying sha256 digest", true},
		{"success", -1, "success", true},
		{"\x1b[2K", -1, "", false},
		{"Error: pull model manifest: file does not exist", -1, "", false},
	}
	for _, c := range cases {
		pct, phase, ok := ParseLine(KindOllama, c.line)
		if pct != c.pct || phase != c.phase || ok != c.ok {
			t.Errorf("ParseLine(%q) = %d %q %v", c.line, pct, phase, ok)
		}
	}
}
