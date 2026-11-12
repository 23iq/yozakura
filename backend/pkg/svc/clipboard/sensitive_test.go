package clipboard

import (
	"errors"
	"os"
	"strings"
	"testing"
)

func TestIsSensitiveOffer(t *testing.T) {
	hint := func(val string, err error) func(string) ([]byte, error) {
		return func(mime string) ([]byte, error) {
			if mime != sensitiveHintMime {
				t.Fatalf("read %q, only the hint may be read", mime)
			}
			return []byte(val), err
		}
	}
	cases := []struct {
		name  string
		types string
		read  func(string) ([]byte, error)
		want  bool
	}{
		{"secret", "text/plain\nx-kde-passwordManagerHint\n", hint("secret\n", nil), true},
		{"other value", "text/plain\nx-kde-passwordManagerHint\n", hint("public", nil), false},
		{"unreadable hint", "x-kde-passwordManagerHint", hint("", errors.New("gone")), false},
		{"no hint", "text/plain;charset=utf-8\ntext/plain\n", hint("secret", nil), false},
	}
	for _, c := range cases {
		if got := isSensitiveOffer(c.types, c.read); got != c.want {
			t.Errorf("%s: got %v, want %v", c.name, got, c.want)
		}
	}
}

// wlPasteOffer serves $TYPES (space separated) as the current offer: the
// hint answers "secret", text answers "hunter2"; every --type read is
// logged to $COUNT.
const wlPasteOffer = `case "$1" in
--list-types) printf '%s\n' $TYPES ;;
--type)
	echo "$2" >> "$COUNT"
	case "$2" in
	x-kde-passwordManagerHint) printf 'secret' ;;
	text/plain*) printf 'hunter2' ;;
	*) exit 1 ;;
	esac ;;
*) exit 1 ;;
esac`

func TestCheckAndInsertSkipsPasswordManagerCopies(t *testing.T) {
	count := fakeWlPaste(t, wlPasteOffer)
	svc := NewService(testPaths(t))
	defer svc.Close()

	t.Setenv("TYPES", "text/plain;charset=utf-8 text/plain x-kde-passwordManagerHint")
	if svc.checkAndInsert() {
		t.Fatal("password-manager copy was recorded")
	}
	reads, _ := os.ReadFile(count)
	if strings.Contains(string(reads), "text/plain") {
		t.Fatalf("secret content was read: %q", reads)
	}

	// An ordinary copy is still recorded.
	t.Setenv("TYPES", "text/plain;charset=utf-8 text/plain")
	if !svc.checkAndInsert() {
		t.Fatal("ordinary copy not recorded")
	}
	st, err := svc.getStore()
	if err != nil {
		t.Fatal(err)
	}
	items := st.listItems()
	if len(items) != 1 || items[0]["preview"] != "hunter2" {
		t.Fatalf("history = %v", items)
	}
}
