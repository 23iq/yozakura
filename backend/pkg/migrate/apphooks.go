package migrate

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"

	"yozakura/backend/pkg/apphooks"
	"yozakura/backend/pkg/catalog"
	"yozakura/backend/pkg/fsutil"
	"yozakura/backend/pkg/paths"
)

// App hooks edit third-party configs (kitty.conf, ...). A fresh install
// connects the themed apps on its own; an existing install upgraded to a
// build with hooks must not have its configs edited behind its back: once,
// every app whose config already exists and is not connected gets
// apps.theming.<id> = false (Settings shows "Connect"). The legacy Qt file
// in environment.d (older builds) is removed there too.

// AppHooksMarker records that the consent migration ran (data dir). Until
// it exists the apphooks service connects nothing automatically.
const AppHooksMarker = ".apphooks-consent"

// errMalformedApps: apps.json cannot be parsed, so the toggles cannot be
// switched off; the migration is retried on the next start (no marker).
var errMalformedApps = errors.New("apps.json is malformed; app theming stays off until it is fixed")

// EnsureAppHooksConsent runs on every start before the shell. It returns
// the app ids switched off (nil on a fresh install or a later start). A
// failure to remove the legacy Qt file is reported but never stops the
// consent step; a malformed apps.json leaves the marker unwritten.
func EnsureAppHooksConsent(p paths.Paths, env apphooks.Env) ([]string, error) {
	if p.ConfigDir == "" || p.DataDir == "" {
		return nil, nil
	}
	_, qtErr := apphooks.RemoveLegacyQtEnv(env)
	if qtErr != nil {
		qtErr = fmt.Errorf("legacy Qt environment file: %w", qtErr)
	}
	marker := filepath.Join(p.DataDir, AppHooksMarker)
	if _, err := os.Stat(marker); err == nil {
		return nil, qtErr
	}
	var off []string
	if existingInstall(p) {
		for _, h := range apphooks.All() {
			st := h.Status(env)
			if st.State == apphooks.StateDisconnected && anyExists(st.Files) {
				off = append(off, h.ID())
			}
		}
		if err := setThemingOff(p.Config("apps"), off); err != nil {
			return nil, errors.Join(err, qtErr)
		}
	}
	if err := os.MkdirAll(p.DataDir, 0o755); err != nil {
		return off, errors.Join(err, qtErr)
	}
	return off, errors.Join(fsutil.WriteFile(marker, []byte("1\n"), 0o644), qtErr)
}

// AppHooksConsented reports whether the consent migration ran (dataDir is
// the app's data dir): before that nothing is connected automatically.
func AppHooksConsented(dataDir string) bool {
	_, err := os.Stat(filepath.Join(dataDir, AppHooksMarker))
	return err == nil
}

// existingInstall: general.json says onboarding is done (an install from
// before this build; a fresh one only gets there after its first start,
// when the marker already exists).
func existingInstall(p paths.Paths) bool {
	data, err := os.ReadFile(p.Config("general"))
	if err != nil {
		return false
	}
	var g map[string]any
	return json.Unmarshal(data, &g) == nil && g[OnboardingKey] == true
}

func anyExists(files []string) bool {
	for _, f := range files {
		if _, err := os.Stat(f); err == nil {
			return true
		}
	}
	return false
}

// setThemingOff sets theming.<id> = false in apps.json (created when
// missing), keeping the rest of the file and its key order.
func setThemingOff(path string, ids []string) error {
	if len(ids) == 0 {
		return nil
	}
	doc := catalog.NewObject()
	if data, err := os.ReadFile(path); err == nil {
		v, err := catalog.DecodeOrdered(data)
		o, ok := v.(*catalog.Object)
		if err != nil || !ok {
			return errMalformedApps
		}
		doc = o
	} else if !os.IsNotExist(err) {
		return err
	}
	theming, _ := doc.Get("theming")
	t, ok := theming.(*catalog.Object)
	if !ok {
		t = catalog.NewObject()
	}
	for _, id := range ids {
		t.Set(id, false)
	}
	doc.Set("theming", t)
	out, err := json.MarshalIndent(doc, "", "  ")
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	return fsutil.WriteFile(path, out, 0o644)
}
