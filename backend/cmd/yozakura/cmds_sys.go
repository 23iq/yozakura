package main

import (
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"os/user"
	"path/filepath"
	"regexp"
	"strings"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/svc/extras"
	"yozakura/backend/pkg/sysinstall"
)

const sysHelp = `Usage: pkexec {bin} sys install <id>...
       pkexec {bin} sys upgrade
       pkexec {bin} sys enable-multilib
       pkexec {bin} sys chsh <user> <shell>

Privileged helper used by Settings > Extras. Runs as root and only accepts
extras catalog ids and the fixed verbs above. The catalog is located from
this binary's install dir or the invoking user's recorded shell repo, never
from the environment.
`

// sysEnv is everything runSys reads from the host (faked in tests).
type sysEnv struct {
	euid     int
	getenv   func(string) string
	exe      func() (string, error)
	lookup   func(uid string) (name, home string, err error)
	exists   func(path string) bool
	readFile func(path string) ([]byte, error)
	platform func() extras.Platform
	helper   sysinstall.Helper
}

func defaultSysEnv(out io.Writer) sysEnv {
	return sysEnv{
		euid:   os.Geteuid(),
		getenv: os.Getenv,
		exe: func() (string, error) {
			p, err := os.Executable()
			if err != nil {
				return "", err
			}
			return filepath.EvalSymlinks(p)
		},
		lookup: func(uid string) (string, string, error) {
			u, err := user.LookupId(uid)
			if err != nil {
				return "", "", err
			}
			return u.Username, u.HomeDir, nil
		},
		exists:   fileExists,
		readFile: os.ReadFile,
		platform: func() extras.Platform {
			return extras.DetectPlatform(extras.OSFS{}, func(b string) bool {
				_, err := exec.LookPath(b)
				return err == nil
			})
		},
		helper: sysinstall.Helper{
			Out:       out,
			Run:       sysinstall.ExecRunner(out),
			ReadFile:  os.ReadFile,
			WriteFile: sysinstall.WriteFileAtomic,
		},
	}
}

var reUID = regexp.MustCompile(`^[0-9]+$`)

// runSys dispatches the privileged verbs. It refuses to run unless root.
func runSys(args []string, env sysEnv, out, errOut io.Writer) int {
	if len(args) == 0 || args[0] == "help" || args[0] == "-h" || args[0] == "--help" {
		fmt.Fprint(out, branded(sysHelp))
		return 0
	}
	if env.euid != 0 {
		fmt.Fprintln(errOut, "Error: sys must run as root (via pkexec)")
		return 1
	}
	verb, rest := args[0], args[1:]
	var err error
	switch verb {
	case "install":
		err = sysInstall(rest, env)
	case "upgrade":
		if len(rest) != 0 {
			return sysUsage(errOut, "upgrade takes no arguments")
		}
		err = env.helper.Upgrade(env.platform().Distro)
	case "enable-multilib":
		if len(rest) != 0 {
			return sysUsage(errOut, "enable-multilib takes no arguments")
		}
		backup := sysinstall.PacmanConf + "." + brand.AppID + ".bak"
		err = env.helper.EnableMultilib(env.platform().Distro, backup)
	case "chsh":
		if len(rest) != 2 {
			return sysUsage(errOut, "chsh needs <user> <shell>")
		}
		err = sysChsh(rest[0], rest[1], env)
	default:
		return sysUsage(errOut, fmt.Sprintf("unknown verb %q", verb))
	}
	if err != nil {
		fmt.Fprintf(errOut, "Error: %v\n", err)
		return 1
	}
	return 0
}

func sysUsage(errOut io.Writer, msg string) int {
	fmt.Fprintf(errOut, "Error: %s\n", msg)
	fmt.Fprint(errOut, branded(sysHelp))
	return 2
}

func sysInstall(ids []string, env sysEnv) error {
	if len(ids) == 0 {
		return errors.New("install needs at least one id")
	}
	path, err := sysCatalogPath(env)
	if err != nil {
		return err
	}
	c, err := extras.LoadCatalog(path)
	if err != nil {
		// Root reads this file: do not echo its content back.
		return fmt.Errorf("extras catalog at %s is invalid", path)
	}
	return env.helper.Install(c, env.platform(), ids)
}

// sysInvoker returns the user that ran pkexec (PKEXEC_UID, set by pkexec
// itself and not by the caller).
func sysInvoker(env sysEnv) (name, home string, err error) {
	uid := env.getenv("PKEXEC_UID")
	if !reUID.MatchString(uid) {
		return "", "", errors.New("PKEXEC_UID is not set: run through pkexec")
	}
	name, home, err = env.lookup(uid)
	if err != nil {
		return "", "", fmt.Errorf("unknown invoking user %s", uid)
	}
	return name, home, nil
}

func sysChsh(target, shell string, env sysEnv) error {
	name, _, err := sysInvoker(env)
	if err != nil {
		return err
	}
	if target != name {
		return fmt.Errorf("chsh may only change the invoking user's shell (%s)", name)
	}
	return env.helper.Chsh(name, shell)
}

// sysCatalogPath locates the extras catalog without trusting the
// environment: first the shell tree around this binary, then the shell repo
// recorded in the invoking user's data dir (<home>/.local/share/<app>/shell_repo;
// XDG_DATA_HOME is deliberately ignored).
func sysCatalogPath(env sysEnv) (string, error) {
	var roots []string
	if exe, err := env.exe(); err == nil {
		// Same layouts as paths.FindBaseShellSource: <repo>/, <repo>/backend/,
		// <repo>/backend/bin/.
		dir := filepath.Dir(exe)
		roots = append(roots, dir)
		if filepath.Base(dir) == "backend" {
			roots = append(roots, filepath.Dir(dir))
		}
		if filepath.Base(dir) == "bin" && filepath.Base(filepath.Dir(dir)) == "backend" {
			roots = append(roots, filepath.Dir(filepath.Dir(dir)))
		}
	}
	if _, home, err := sysInvoker(env); err == nil && filepath.IsAbs(home) {
		repoFile := filepath.Join(home, ".local", "share", brand.AppID, "shell_repo")
		if data, err := env.readFile(repoFile); err == nil {
			if dir := strings.TrimSpace(string(data)); filepath.IsAbs(dir) {
				roots = append(roots, filepath.Clean(dir))
			}
		}
	}
	for _, root := range roots {
		catalog := filepath.Join(root, "assets", "catalog", "extras.json")
		if env.exists(filepath.Join(root, "shell.qml")) && env.exists(catalog) {
			return catalog, nil
		}
	}
	return "", errors.New("extras catalog not found")
}
