package agents

import "strings"

// IsSafeCommand reports whether a shell command provably only reads: it
// parses (see parseScript) and every simple command is a known read-only
// program used with explicitly allowed flags. Deny by default: an unknown
// program, flag, long-option abbreviation or argument shape means "ask".
func IsSafeCommand(cmd string) bool {
	segs, ok := parseScript(strings.TrimSpace(cmd))
	if !ok {
		return false
	}
	for _, seg := range segs {
		if !safeArgv(seg.argv) {
			return false
		}
	}
	return true
}

func safeArgv(argv []string) bool {
	prog := programName(argv[0])
	args := argv[1:]
	switch prog {
	case "git":
		return safeGit(args)
	case "find":
		return safeFind(args)
	}
	spec, ok := safePrograms[prog]
	return ok && spec.allows(args)
}

// progSpec lists the options a read-only program may be called with.
type progSpec struct {
	flags    string // boolean options, space separated ("-l --all")
	values   string // options taking exactly one value (next arg, attached or --opt=value)
	optional string // long options taking an optional value only as --opt=value
	pairs    string // long options taking two values (jq --arg NAME VALUE)
	numeric  bool   // accept -NUM (head -20)
	anyArgs  bool   // every argument is inert (echo, true)
	maxPos   int    // maximum positionals; -1 = unlimited
	check    func(pos []string, seen map[string]bool) bool
}

func has(list, name string) bool {
	for _, f := range strings.Fields(list) {
		if f == name {
			return true
		}
	}
	return false
}

func allDigits(s string) bool {
	if s == "" {
		return false
	}
	for _, r := range s {
		if r < '0' || r > '9' {
			return false
		}
	}
	return true
}

// allows parses args GNU-style (options may follow operands, -- ends them,
// short options cluster) and accepts only listed options.
func (sp progSpec) allows(args []string) bool {
	if sp.anyArgs {
		return true
	}
	var pos []string
	seen := map[string]bool{}
	for i := 0; i < len(args); i++ {
		a := args[i]
		switch {
		case a == "--":
			pos = append(pos, args[i+1:]...)
			i = len(args)
		case strings.HasPrefix(a, "--"):
			name, _, hasVal := strings.Cut(a, "=")
			switch {
			case has(sp.flags, name) && !hasVal, has(sp.optional, name):
			case has(sp.values, name):
				if !hasVal {
					if i++; i >= len(args) {
						return false
					}
				}
			case has(sp.pairs, name) && !hasVal:
				if i += 2; i >= len(args) {
					return false
				}
			default:
				return false
			}
			seen[name] = true
		case len(a) > 1 && a[0] == '-':
			if sp.numeric && allDigits(a[1:]) {
				continue
			}
			for j := 1; j < len(a); j++ {
				f := "-" + a[j:j+1]
				seen[f] = true
				if has(sp.values, f) {
					if j == len(a)-1 {
						if i++; i >= len(args) {
							return false
						}
					}
					break
				}
				if !has(sp.flags, f) {
					return false
				}
			}
		default:
			pos = append(pos, a)
		}
	}
	if sp.maxPos >= 0 && len(pos) > sp.maxPos {
		return false
	}
	return sp.check == nil || sp.check(pos, seen)
}

const unlimited = -1

func noPlusArgs(pos []string, _ map[string]bool) bool {
	for _, p := range pos {
		if strings.HasPrefix(p, "+") {
			return false // less +cmd runs commands (incl. !shell)
		}
	}
	return true
}

func onlyFormats(pos []string, _ map[string]bool) bool {
	for _, p := range pos {
		if !strings.HasPrefix(p, "+") {
			return false // date MMDDhhmm sets the clock
		}
	}
	return true
}

var safePrograms = map[string]progSpec{
	"ls": {flags: "-a -A -b -B -c -C -d -F -g -G -h -H -i -k -l -L -m -n -N -o -p -q -Q -r -R -s -S -t -u -U -v -x -X -Z -1 " +
		"--all --almost-all --escape --ignore-backups --directory --dereference --dereference-command-line --no-group " +
		"--human-readable --si --inode --kibibytes --numeric-uid-gid --literal --hide-control-chars --show-control-chars " +
		"--quote-name --reverse --recursive --size --full-time --group-directories-first --context",
		values:   "-I -T -w --ignore --hide --block-size --sort --time --time-style --format --width --tabsize --indicator-style --quoting-style",
		optional: "--color --colour --classify --hyperlink", maxPos: unlimited},
	"cat": {flags: "-A -b -e -E -n -s -t -T -u -v --show-all --number-nonblank --show-ends --number --squeeze-blank --show-tabs --show-nonprinting",
		maxPos: unlimited},
	"head": {flags: "-q -v -z --quiet --silent --verbose --zero-terminated", values: "-n -c --lines --bytes",
		numeric: true, maxPos: unlimited},
	"tail": {flags: "-q -v -z --quiet --silent --verbose --zero-terminated", values: "-n -c --lines --bytes",
		numeric: true, maxPos: unlimited},
	"wc": {flags: "-c -m -l -L -w --bytes --chars --lines --max-line-length --words", optional: "--total", maxPos: unlimited},
	"grep": {flags: "-a -b -c -E -F -G -h -H -i -I -l -L -n -o -P -q -r -R -s -T -U -v -w -x -y -z -Z " +
		"--text --byte-offset --count --extended-regexp --fixed-strings --basic-regexp --no-filename --with-filename " +
		"--ignore-case --no-ignore-case --files-with-matches --files-without-match --line-number --only-matching " +
		"--perl-regexp --quiet --silent --recursive --dereference-recursive --no-messages --initial-tab --invert-match " +
		"--word-regexp --line-regexp --null-data --null --line-buffered",
		values: "-A -B -C -e -f -m -d --after-context --before-context --context --regexp --file --max-count " +
			"--include --exclude --exclude-dir --exclude-from --label --binary-files --directories",
		optional: "--color --colour", numeric: true, maxPos: unlimited},
	"rg": {flags: "-a -b -c -F -H -i -I -l -L -n -N -o -P -q -s -S -u -U -v -w -x -0 " +
		"--text --byte-offset --count --count-matches --fixed-strings --with-filename --no-filename --ignore-case " +
		"--smart-case --case-sensitive --files --files-with-matches --files-without-match --follow --line-number " +
		"--no-line-number --only-matching --pcre2 --quiet --unrestricted --multiline --invert-match --word-regexp " +
		"--line-regexp --null --hidden --no-hidden --no-ignore --no-ignore-vcs --no-ignore-parent --no-ignore-dot " +
		"--no-ignore-global --heading --no-heading --json --vimgrep --column --no-column --no-messages --stats " +
		"--trim --type-list --passthru --sort-files --no-config --no-filename --glob-case-insensitive",
		values: "-A -B -C -e -f -g -m -M -t -T -d -j -r -E --after-context --before-context --context --regexp " +
			"--file --glob --iglob --max-count --max-columns --type --type-not --max-depth --threads --replace " +
			"--encoding --sort --sortr --max-filesize --color --colors --path-separator",
		numeric: false, maxPos: unlimited},
	"fd": {flags: "-0 -1 -a -F -g -H -i -I -l -L -p -q -s -u --absolute-path --fixed-strings --glob --regex --hidden " +
		"--ignore-case --case-sensitive --no-ignore --no-ignore-vcs --no-ignore-parent --unrestricted --list-details " +
		"--follow --full-path --print0 --quiet --show-errors --prune",
		values: "-c -d -e -E -j -t -S --color --max-depth --min-depth --exact-depth --extension --exclude --threads " +
			"--type --size --changed-within --changed-before --owner --max-results --base-directory --search-path",
		maxPos: unlimited},
	"tree": {flags: "-a -A -c -C -d -D -f -F -g -h -i -J -l -n -N -p -q -Q -r -s -S -t -u -U -v -x -X " +
		"--noreport --dirsfirst --du --si --gitignore --prune --inodes --device",
		values: "-I -L -P --filelimit --sort --charset --timefmt", maxPos: unlimited},
	"sort": {flags: "-b -c -C -d -f -g -h -i -m -M -n -r -R -s -u -V -z --ignore-leading-blanks --check " +
		"--dictionary-order --ignore-case --general-numeric-sort --human-numeric-sort --ignore-nonprinting --merge " +
		"--month-sort --numeric-sort --reverse --random-sort --stable --unique --version-sort --zero-terminated",
		values: "-k -S -t --key --buffer-size --field-separator --sort --parallel", maxPos: unlimited},
	// uniq's second operand is an OUTPUT file.
	"uniq": {flags: "-c -d -D -i -u -z --count --repeated --ignore-case --unique --zero-terminated",
		values: "-f -s -w --skip-fields --skip-chars --check-chars", optional: "--all-repeated --group", maxPos: 1},
	"cut": {flags: "-n -s -z --complement --only-delimited --zero-terminated",
		values: "-b -c -d -f --bytes --characters --delimiter --fields --output-delimiter", maxPos: unlimited},
	"diff": {flags: "-a -b -B -c -d -E -i -N -p -q -r -s -t -T -u -w -y -Z --text --ignore-space-change " +
		"--ignore-blank-lines --ignore-case --new-file --show-c-function --brief --recursive --report-identical-files " +
		"--expand-tabs --initial-tab --ignore-all-space --side-by-side --minimal --strip-trailing-cr " +
		"--suppress-common-lines --no-dereference --ignore-tab-expansion --ignore-trailing-space",
		values:   "-C -F -I -U -W -x --label --exclude --width --ignore-matching-lines --show-function-line",
		optional: "--color --unified --context", maxPos: 2},
	"echo":     {anyArgs: true},
	"true":     {anyArgs: true},
	"pwd":      {flags: "-L -P", maxPos: 0},
	"whoami":   {maxPos: 0},
	"date":     {flags: "-u -R --utc --universal --rfc-email", values: "-d -r --date --reference", optional: "--iso-8601 --rfc-3339", maxPos: 1, check: onlyFormats},
	"uname":    {flags: "-a -i -m -n -o -p -r -s -v --all --kernel-name --nodename --kernel-release --kernel-version --machine --processor --hardware-platform --operating-system", maxPos: 0},
	"which":    {flags: "-a", maxPos: unlimited},
	"type":     {flags: "-a -f -p -P -t", maxPos: unlimited},
	"file":     {flags: "-b -E -h -i -k -L -N -r -s --brief --dereference --no-dereference --keep-going --mime --mime-type --mime-encoding --raw --special-files", values: "-F --separator", maxPos: unlimited},
	"stat":     {flags: "-f -L -t --dereference --file-system --terse", values: "-c --format --printf", maxPos: unlimited},
	"du":       {flags: "-0 -a -b -c -D -h -H -k -l -L -m -P -s -S -x --all --apparent-size --bytes --total --dereference-args --human-readable --si --count-links --dereference --no-dereference --null --separate-dirs --summarize --one-file-system --inodes", values: "-B -d -t --block-size --max-depth --threshold --exclude --time-style", optional: "--time", maxPos: unlimited},
	"df":       {flags: "-a -h -H -i -k -l -P -T --all --human-readable --si --inodes --local --portability --print-type --total", values: "-B -t -x --block-size --type --exclude-type", optional: "--output", maxPos: unlimited},
	"basename": {flags: "-a -z --multiple --zero", values: "-s --suffix", maxPos: unlimited},
	"dirname":  {flags: "-z --zero", maxPos: unlimited},
	"realpath": {flags: "-e -L -m -P -q -s -z --canonicalize-existing --canonicalize-missing --logical --physical --quiet --strip --no-symlinks --zero", values: "--relative-to --relative-base", maxPos: unlimited},
	"readlink": {flags: "-e -f -m -n -q -s -v -z --canonicalize --canonicalize-existing --canonicalize-missing --no-newline --quiet --silent --verbose --zero", maxPos: unlimited},
	"nl":       {flags: "-p --no-renumber", values: "-b -d -f -h -i -l -n -s -v -w", maxPos: 1},
	"jq": {flags: "-a -C -c -e -j -M -n -r -R -s -S --ascii-output --color-output --compact-output --exit-status " +
		"--join-output --monochrome-output --null-input --raw-output --raw-input --slurp --sort-keys --tab --seq --stream",
		values: "--indent", pairs: "--arg --argjson", maxPos: unlimited},
	"less": {flags: "-E -e -F -i -I -K -m -M -n -N -R -r -S -s -X --quit-at-eof --quit-if-one-screen --ignore-case " +
		"--IGNORE-CASE --LINE-NUMBERS --RAW-CONTROL-CHARS --chop-long-lines --no-init --squeeze-blank-lines",
		maxPos: unlimited, check: noPlusArgs},
}

// --- git ---

// gitHistory covers log/show/diff: history and diff output to stdout only
// (no --output, no external diff drivers).
var gitHistory = progSpec{
	flags: "-a -b -c -C -E -F -g -i -m -M -p -R -s -u -w -z " +
		"--oneline --patch --no-patch --stat --shortstat --numstat --name-only --name-status --summary --raw --check " +
		"--graph --all --branches --tags --remotes --not --reverse --no-merges --merges --first-parent --follow " +
		"--full-history --topo-order --date-order --left-right --cherry-pick --cherry-mark --source --boundary " +
		"--ancestry-path --simplify-by-decoration --walk-reflogs --abbrev-commit --no-abbrev-commit --no-color " +
		"--no-renames --minimal --patience --histogram --ignore-all-space --ignore-space-change --ignore-blank-lines " +
		"--regexp-ignore-case --extended-regexp --fixed-strings --all-match --invert-grep --no-ext-diff --no-textconv " +
		"--cc --full-diff --full-index --no-prefix --text --cached --staged --merge-base --exit-code --quiet",
	values: "-n -S -G -L -U --max-count --skip --since --after --until --before --author --committer --grep " +
		"--diff-filter --src-prefix --dst-prefix",
	optional: "--pretty --format --decorate --color --abbrev --word-diff --stat --dirstat --relative --find-renames " +
		"--date --unified",
	numeric: true, maxPos: unlimited,
}

func listOnly(pos []string, seen map[string]bool) bool {
	// Without --list an operand creates a branch/tag.
	return len(pos) == 0 || seen["--list"] || seen["-l"]
}

var gitCommands = map[string]progSpec{
	"log": gitHistory, "show": gitHistory, "diff": gitHistory,
	"status": {flags: "-b -s -u -v -z --short --branch --long --verbose --show-stash --ahead-behind --no-ahead-behind --renames --no-renames",
		optional: "--porcelain --untracked-files --ignored --ignore-submodules --column", maxPos: unlimited},
	"branch": {flags: "-a -i -l -r -v --all --ignore-case --list --remotes --verbose --show-current --no-color --omit-empty",
		values: "--sort --format", optional: "--color --abbrev --contains --no-contains --merged --no-merged --points-at",
		maxPos: unlimited, check: listOnly},
	"tag": {flags: "-i -l -n --ignore-case --list --no-color --omit-empty", values: "--sort --format",
		optional: "--color --contains --no-contains --merged --no-merged --points-at", maxPos: unlimited, check: listOnly},
	"remote": {flags: "-v --verbose --all --push", maxPos: 2, check: func(pos []string, _ map[string]bool) bool {
		return len(pos) == 0 || (pos[0] == "get-url" && len(pos) == 2)
	}},
	"rev-parse": {flags: "-q --show-toplevel --git-dir --git-common-dir --absolute-git-dir --is-inside-work-tree " +
		"--is-inside-git-dir --is-bare-repository --verify --quiet --symbolic --symbolic-full-name --show-prefix --show-cdup " +
		"--all --branches --tags --remotes", optional: "--short --abbrev-ref", maxPos: unlimited},
	"ls-files": {flags: "-c -d -i -k -m -o -s -t -u -v -z --cached --deleted --modified --others --ignored --stage --unmerged " +
		"--killed --directory --no-empty-directory --exclude-standard --full-name --error-unmatch --eol --recurse-submodules",
		values: "-x --exclude", optional: "--abbrev", maxPos: unlimited},
	"blame": {flags: "-b -c -e -f -l -M -C -n -p -s -t -w --porcelain --line-porcelain --show-email --show-name " +
		"--show-number --root --incremental", values: "-L --date", optional: "--abbrev", maxPos: unlimited},
	"describe": {flags: "--all --tags --always --long --exact-match --first-parent --contains", values: "--match --exclude --candidates",
		optional: "--abbrev --dirty --broken", maxPos: unlimited},
	"shortlog": {flags: "-c -e -n -s --summary --numbered --email --committer --all --no-merges --merges",
		values: "--since --until --author --format --group", maxPos: unlimited},
}

// safeGit accepts `git [--no-pager] SUBCOMMAND args` for read-only
// subcommands. Global options that change config, exec path or repo
// location (-c, --exec-path, -C, --git-dir, ...) are refused.
func safeGit(args []string) bool {
	for len(args) > 0 && args[0] == "--no-pager" {
		args = args[1:]
	}
	if len(args) == 0 {
		return false
	}
	spec, ok := gitCommands[args[0]]
	return ok && spec.allows(args[1:])
}

// --- find ---

var (
	findValueTests = " -name -iname -path -ipath -wholename -iwholename -regex -iregex -regextype -type -xtype -size " +
		"-mtime -mmin -atime -amin -ctime -cmin -newer -anewer -cnewer -user -group -uid -gid -perm -links -inum " +
		"-samefile -maxdepth -mindepth -used -printf "
	findFlagTests = " -print -print0 -ls -empty -o -or -a -and -not -prune -readable -writable -executable -xdev -mount " +
		"-follow -true -false -nouser -nogroup -depth -daystart -noleaf -quit ( ) ! "
)

// safeFind accepts paths followed by an expression made only of tests and
// stdout actions; -exec/-ok/-delete/-fprint*/-fls are not in the lists.
func safeFind(args []string) bool {
	i := 0
	for i < len(args) && (args[i] == "-H" || args[i] == "-L" || args[i] == "-P") {
		i++
	}
	for i < len(args) && !strings.HasPrefix(args[i], "-") && args[i] != "(" && args[i] != "!" {
		i++ // starting points
	}
	for ; i < len(args); i++ {
		a := args[i]
		switch {
		case strings.Contains(findValueTests, " "+a+" "):
			if i++; i >= len(args) {
				return false
			}
		case strings.Contains(findFlagTests, " "+a+" "):
		default:
			return false
		}
	}
	return true
}
