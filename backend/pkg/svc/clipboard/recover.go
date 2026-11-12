package clipboard

import (
	"database/sql"
	"errors"
	"fmt"
	"log"
	"os"
	"time"

	sqlite3 "github.com/ncruces/go-sqlite3"
)

// openStoreDB opens one of the clipboard stores. A store the current key
// cannot decrypt (the key file in the state dir was lost and regenerated,
// or the file is not a database at all) would otherwise fail every open
// and leave clipboard history dead until the user deleted files by hand:
// it is moved aside (never deleted) and a fresh store is created in its
// place.
func openStoreDB(path, hexKey string) (*sql.DB, error) {
	db, err := openDB(path, hexKey)
	if err == nil || !isUnreadableDB(err) {
		return db, err
	}
	moved, mvErr := moveAside(path, time.Now())
	if mvErr != nil {
		return nil, fmt.Errorf("%w (moving it aside failed: %v)", err, mvErr)
	}
	log.Printf("[clipboard] %s cannot be read with the current key (%v); moved it to %s and started an empty store", path, err, moved)
	return openDB(path, hexKey)
}

// isUnreadableDB reports a decrypt/key mismatch: with the adiantum VFS a
// wrong key yields pages SQLite does not recognise as a database.
func isUnreadableDB(err error) bool {
	return errors.Is(err, sqlite3.NOTADB)
}

// moveAside renames the database and its journal files to
// "<name>.unreadable-<timestamp>" and returns the new database path.
func moveAside(path string, now time.Time) (string, error) {
	suffix := ".unreadable-" + now.Format("20060102-150405")
	dst := path + suffix
	for i := 1; ; i++ {
		if _, err := os.Lstat(dst); os.IsNotExist(err) {
			break
		}
		dst = fmt.Sprintf("%s%s.%d", path, suffix, i)
	}
	if err := os.Rename(path, dst); err != nil {
		return "", err
	}
	for _, ext := range []string{"-wal", "-shm", "-journal"} {
		if _, err := os.Lstat(path + ext); err == nil {
			if err := os.Rename(path+ext, dst+ext); err != nil {
				return dst, err
			}
		}
	}
	return dst, nil
}
