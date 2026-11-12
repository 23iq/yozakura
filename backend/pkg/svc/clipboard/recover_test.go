package clipboard

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// A regenerated key (the state dir was wiped, the data dir was not) must not
// leave clipboard history dead: the unreadable stores are moved aside, never
// deleted, and fresh ones are created.
func TestNewStoreRecoversFromLostKey(t *testing.T) {
	p := testPaths(t)
	st, err := newStore(p)
	if err != nil {
		t.Fatal(err)
	}
	if ok, err := st.insertUnpinned("text/plain", []byte("secret history"), false, 14); !ok || err != nil {
		t.Fatalf("insert: %v %v", ok, err)
	}
	if err := st.togglePin(itemID{id: 1}); err != nil {
		t.Fatal(err)
	}
	if ok, err := st.insertUnpinned("text/plain", []byte("unpinned"), false, 8); !ok || err != nil {
		t.Fatalf("insert: %v %v", ok, err)
	}
	st.close()
	pinnedBefore, err := os.ReadFile(p.ClipboardPinnedDB())
	if err != nil {
		t.Fatal(err)
	}

	if err := os.Remove(p.ClipboardKeyFile()); err != nil {
		t.Fatal(err)
	}

	st, err = newStore(p)
	if err != nil {
		t.Fatalf("store with a regenerated key: %v", err)
	}
	defer st.close()
	if items := st.listItems(); len(items) != 0 {
		t.Fatalf("fresh store not empty: %v", items)
	}
	if ok, err := st.insertUnpinned("text/plain", []byte("new"), false, 3); !ok || err != nil {
		t.Fatalf("insert into recreated store: %v %v", ok, err)
	}

	for _, db := range []string{p.ClipboardPinnedDB(), p.ClipboardUnpinnedDB()} {
		moved, _ := filepath.Glob(db + ".unreadable-*")
		if len(moved) != 1 {
			t.Fatalf("%s: moved-aside files = %v", filepath.Base(db), moved)
		}
		if db == p.ClipboardPinnedDB() {
			data, err := os.ReadFile(moved[0])
			if err != nil || string(data) != string(pinnedBefore) {
				t.Fatalf("pinned store not preserved byte for byte (%v)", err)
			}
		}
	}
}

// A store the current key does read is never touched.
func TestOpenStoreDBKeepsReadableStore(t *testing.T) {
	p := testPaths(t)
	st, err := newStore(p)
	if err != nil {
		t.Fatal(err)
	}
	if ok, _ := st.insertUnpinned("text/plain", []byte("kept"), false, 4); !ok {
		t.Fatal("insert failed")
	}
	st.close()
	st, err = newStore(p)
	if err != nil {
		t.Fatal(err)
	}
	defer st.close()
	if items := st.listItems(); len(items) != 1 {
		t.Fatalf("items after reopen = %v", items)
	}
	if moved, _ := filepath.Glob(filepath.Join(p.DataDir, "*.unreadable-*")); len(moved) != 0 {
		t.Fatalf("readable store moved aside: %v", moved)
	}
}

func TestMoveAsideKeepsEarlierCopies(t *testing.T) {
	dir := t.TempDir()
	db := filepath.Join(dir, "x.db")
	now := time.Date(2026, 1, 2, 3, 4, 5, 0, time.UTC)
	var got []string
	for i := 0; i < 2; i++ {
		if err := os.WriteFile(db, []byte{byte(i)}, 0o600); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(db+"-wal", []byte{byte(i)}, 0o600); err != nil {
			t.Fatal(err)
		}
		dst, err := moveAside(db, now)
		if err != nil {
			t.Fatal(err)
		}
		if _, err := os.Stat(dst + "-wal"); err != nil {
			t.Fatalf("wal not moved with %s: %v", dst, err)
		}
		got = append(got, filepath.Base(dst))
	}
	if got[0] != "x.db.unreadable-20260102-030405" || !strings.HasPrefix(got[1], got[0]+".") {
		t.Fatalf("moved names = %v", got)
	}
	if _, err := os.Stat(db); !os.IsNotExist(err) {
		t.Fatal("original still present")
	}
}
