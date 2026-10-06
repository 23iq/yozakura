package main

import (
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"os/signal"
	"os/user"
	"path/filepath"
	"regexp"
	"syscall"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/extrascatalog"
	"yozakura/backend/pkg/svc/extras"
	"yozakura/backend/pkg/sysinstall"
)

const sysHelp = `Usage: pkexec {bin} sys install <id>...
       pkexec {bin} sys upgrade
       pkexec {bin} sys enable-multilib
       pkexec {bin} sys chsh <user> <shell>

Privileged helper used by Settings > Extras. Runs as root and only accepts
extras catalog ids and the fixed verbs above. The catalog is the copy
embedded in this binary; no file or environment variable is consulted.
`

// sysEnv is everything runSys reads from the host (faked in tests).
type sysEnv struct {
	euid     int
	getenv   func(string) string
	lookup   func(uid string) (name string, err error)
	catalog  func() (*extras.Catalog, error)
	platform func() extras.Platform
	helper   sysinstall.Helper
}

func defaultSysEnv(out io.Writer) sysEnv {
	return sysEnv{
		euid:   os.Geteuid(),
		getenv: os.Getenv,
		lookup: func(uid string) (string, error) {
			u, err := user.LookupId(uid)
			if err != nil {
				return "", err
			}
			return u.Username, nil
		},
		catalog: extrascatalog.Load,
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
			RealPath:  filepath.EvalSymlinks,
		},
	}
}

// ignoreSIGPIPE keeps the helper alive when the daemon reading its output
// goes away (reload, crash): writes then fail with EPIPE instead of killing
// the process, and ExecRunner keeps draining the child's pipe, so the
// package manager is never cut off mid-transaction.
func ignoreSIGPIPE() { signal.Ignore(syscall.SIGPIPE) }

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
	ignoreSIGPIPE()
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
	c, err := env.catalog()
	if err != nil {
		return err
	}
	return env.helper.Install(c, env.platform(), ids)
}

// sysInvoker returns the user that ran pkexec (PKEXEC_UID, set by pkexec
// itself and not by the caller).
func sysInvoker(env sysEnv) (string, error) {
	uid := env.getenv("PKEXEC_UID")
	if !reUID.MatchString(uid) {
		return "", errors.New("PKEXEC_UID is not set: run through pkexec")
	}
	name, err := env.lookup(uid)
	if err != nil {
		return "", fmt.Errorf("unknown invoking user %s", uid)
	}
	return name, nil
}

func sysChsh(target, shell string, env sysEnv) error {
	name, err := sysInvoker(env)
	if err != nil {
		return err
	}
	if target != name {
		return fmt.Errorf("chsh may only change the invoking user's shell (%s)", name)
	}
	return env.helper.Chsh(name, shell)
}
