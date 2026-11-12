package updatechannel

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
)

// fixture is tests/fixtures/update-channels.json: the cases the Go, JS and
// install.sh implementations share.
type fixture struct {
	Parse []struct {
		Tag     string  `json:"tag"`
		Version *string `json:"version"`
		Beta    bool    `json:"beta"`
	} `json:"parse"`
	Compare [][3]any `json:"compare"`
	Select  []struct {
		Channel string   `json:"channel"`
		Tags    []string `json:"tags"`
		Want    string   `json:"want"`
	} `json:"select"`
}

func loadFixture(t *testing.T) fixture {
	t.Helper()
	data, err := os.ReadFile(filepath.Join("..", "..", "..", "tests", "fixtures", "update-channels.json"))
	mustOK(t, err)
	var f fixture
	mustOK(t, json.Unmarshal(data, &f))
	if len(f.Parse) == 0 || len(f.Compare) == 0 || len(f.Select) == 0 {
		t.Fatal("empty fixture section")
	}
	return f
}

// mustOK stops the test on an error (testify's require is not vendored).
func mustOK(t *testing.T, err error, msg ...any) {
	t.Helper()
	if err != nil {
		t.Fatal(append([]any{err}, msg...)...)
	}
}

func TestParseFixture(t *testing.T) {
	for _, c := range loadFixture(t).Parse {
		v, ok := Parse(c.Tag)
		if c.Version == nil {
			assert.False(t, ok, "%q is not a version", c.Tag)
			continue
		}
		if assert.True(t, ok, "%q parses", c.Tag) {
			assert.Equal(t, *c.Version, v.String(), c.Tag)
			assert.Equal(t, c.Beta, v.IsBeta(), c.Tag)
		}
	}
}

func TestCompareFixture(t *testing.T) {
	for _, c := range loadFixture(t).Compare {
		a, b, want := c[0].(string), c[1].(string), int(c[2].(float64))
		got, ok := Compare(a, b)
		assert.True(t, ok)
		assert.Equal(t, want, got, "%s vs %s", a, b)
		back, _ := Compare(b, a)
		assert.Equal(t, -want, back, "%s vs %s (reversed)", b, a)
	}
}

func TestSelectFixture(t *testing.T) {
	for _, c := range loadFixture(t).Select {
		assert.Equal(t, c.Want, Select(c.Tags, c.Channel), "%s %v", c.Channel, c.Tags)
		// The order of the tags never matters.
		rev := make([]string, len(c.Tags))
		for i, tag := range c.Tags {
			rev[len(c.Tags)-1-i] = tag
		}
		assert.Equal(t, c.Want, Select(rev, c.Channel), "%s %v (reversed)", c.Channel, rev)
	}
}

func TestCompareRejectsNonVersions(t *testing.T) {
	_, ok := Compare("0.3.1", "nightly")
	assert.False(t, ok)
	_, ok = Compare("0.3.2-rc1", "0.3.1")
	assert.False(t, ok)
}

func TestValid(t *testing.T) {
	for _, c := range []string{"stable", "beta", "git"} {
		assert.True(t, Valid(c))
	}
	for _, c := range []string{"", "Stable", "nightly", "main"} {
		assert.False(t, Valid(c))
	}
	assert.Equal(t, Stable, Default)
}

func TestParseLsRemoteTags(t *testing.T) {
	out := "aaa\trefs/tags/0.3.1\n" +
		"bbb\trefs/tags/0.3.2-beta.1\n" +
		"ccc\trefs/tags/0.3.2-beta.1^{}\n" +
		"ddd\trefs/heads/main\n"
	assert.Equal(t, map[string]string{"0.3.1": "aaa", "0.3.2-beta.1": "ccc"}, parseLsRemoteTags(out))
	// The peeled line may come first.
	out = "ccc\trefs/tags/x^{}\nbbb\trefs/tags/x\n"
	assert.Equal(t, map[string]string{"x": "ccc"}, parseLsRemoteTags(out))
}
