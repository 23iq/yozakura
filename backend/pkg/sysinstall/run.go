package sysinstall

import (
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"

	"yozakura/backend/pkg/svc/extras"
)

// Runner runs a fixed program (bare name, resolved from system dirs) with
// argv args, streaming its output.
type Runner func(name string, args ...string) error

// Helper executes the privileged verbs. All side effects go through Run,
// ReadFile and WriteFile so tests can fake them.
type Helper struct {
	Out       io.Writer
	Run       Runner
	ReadFile  func(path string) ([]byte, error)
	WriteFile func(path string, data []byte) error
	RealPath  func(path string) (string, error) // resolves symlinks
}

// Paths of the system files the helper touches.
const (
	PacmanConf = "/etc/pacman.conf"
	EtcShells  = "/etc/shells"
)

// Install resolves ids to native packages, installs them without syncing
// the database (`-S --needed`, never `-y`) and enables the entries' units.
func (h Helper) Install(c *extras.Catalog, p extras.Platform, ids []string) error {
	pkgs, units, err := ResolveSystemPkgs(c, p, ids)
	if err != nil {
		return err
	}
	switch p.Distro {
	case "arch":
		err = h.Run("pacman", append([]string{"-S", "--needed", "--noconfirm", "--"}, pkgs...)...)
	case "fedora":
		err = h.Run("dnf", append([]string{"install", "-y", "--"}, pkgs...)...)
	default:
		return fmt.Errorf("unsupported distro %q", p.Distro)
	}
	if err != nil {
		return err
	}
	for _, u := range units {
		if err := h.Run("systemctl", "enable", "--now", "--", u); err != nil {
			return err
		}
	}
	return nil
}

// Upgrade runs a full system upgrade.
func (h Helper) Upgrade(distro string) error {
	switch distro {
	case "arch":
		return h.Run("pacman", "-Syu", "--noconfirm")
	case "fedora":
		return h.Run("dnf", "upgrade", "-y")
	}
	return fmt.Errorf("unsupported distro %q", distro)
}

// EnableMultilib enables [multilib] in pacman.conf, keeping the original
// at backup (written once, never overwritten). It does not sync: a sync
// without upgrade is a partial upgrade; the caller's `sys upgrade` (-Syu)
// handles the "target not found" that follows. Already enabled is a no-op.
func (h Helper) EnableMultilib(distro, backup string) error {
	if distro != "arch" {
		return fmt.Errorf("multilib is arch only (distro %q)", distro)
	}
	conf, err := h.RealPath(PacmanConf)
	if err != nil {
		return err
	}
	data, err := h.ReadFile(conf)
	if err != nil {
		return err
	}
	next, changed, err := EnableMultilib(data)
	if err != nil {
		return err
	}
	if !changed {
		fmt.Fprintln(h.Out, "multilib already enabled")
		return nil
	}
	if _, err := h.ReadFile(backup); errors.Is(err, os.ErrNotExist) {
		if err := h.WriteFile(backup, data); err != nil {
			return fmt.Errorf("backup %s: %w", backup, err)
		}
	} else if err != nil {
		return fmt.Errorf("backup %s: %w", backup, err)
	}
	if err := h.WriteFile(conf, next); err != nil {
		return err
	}
	fmt.Fprintln(h.Out, "multilib enabled")
	return nil
}

// Chsh sets the login shell of user, which must already be authorised by
// the caller; shell must be listed in /etc/shells.
func (h Helper) Chsh(user, shell string) error {
	shells, err := h.ReadFile(EtcShells)
	if err != nil {
		return err
	}
	if !ValidShell(shells, shell) {
		return fmt.Errorf("shell %q is not listed in %s", shell, EtcShells)
	}
	return h.Run("usermod", "-s", shell, "--", user)
}

// systemDirs is where ExecRunner looks programs up; PATH is ignored.
var systemDirs = []string{"/usr/bin", "/usr/sbin", "/bin", "/sbin"}

// childEnv is the whole environment of root children: C locale so output
// parsing sees English messages, fixed PATH.
var childEnv = []string{"PATH=/usr/bin:/usr/sbin:/bin:/sbin", "LC_ALL=C", "LANG=C"}

// ExecRunner returns a Runner that executes programs from the system dirs
// with a fixed environment and no stdin, writing their merged stdout and
// stderr to out line by line.
func ExecRunner(out io.Writer) Runner {
	return func(name string, args ...string) error {
		bin, err := lookSystem(name)
		if err != nil {
			return err
		}
		pr, pw, err := os.Pipe()
		if err != nil {
			return err
		}
		cmd := exec.Command(bin, args...)
		cmd.Env = childEnv
		cmd.Dir = "/"
		cmd.Stdout, cmd.Stderr = pw, pw
		if err := cmd.Start(); err != nil {
			pw.Close()
			pr.Close()
			return err
		}
		pw.Close()
		streamLines(pr, func(l string) { fmt.Fprintln(out, l) })
		pr.Close()
		if err := cmd.Wait(); err != nil {
			return fmt.Errorf("%s: %w", name, err)
		}
		return nil
	}
}

func lookSystem(name string) (string, error) {
	if filepath.Base(name) != name {
		return "", fmt.Errorf("program %q must be a bare name", name)
	}
	for _, dir := range systemDirs {
		p := filepath.Join(dir, name)
		if st, err := os.Stat(p); err == nil && st.Mode().IsRegular() && st.Mode()&0o111 != 0 {
			return p, nil
		}
	}
	return "", fmt.Errorf("%s not found", name)
}

// WriteFileAtomic replaces path with data via a temp file in the same dir,
// keeping the existing file's mode (0644 for a new file).
func WriteFileAtomic(path string, data []byte) error {
	mode := os.FileMode(0o644)
	if st, err := os.Stat(path); err == nil {
		mode = st.Mode().Perm()
	} else if !errors.Is(err, os.ErrNotExist) {
		return err
	}
	tmp, err := os.CreateTemp(filepath.Dir(path), "."+filepath.Base(path)+".tmp*")
	if err != nil {
		return err
	}
	defer os.Remove(tmp.Name())
	if _, err := tmp.Write(data); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Chmod(mode); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Sync(); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	return os.Rename(tmp.Name(), path)
}
