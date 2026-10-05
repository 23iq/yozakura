package transfers

import (
	"path/filepath"
	"strings"
)

// fileOps: long file operations in any terminal or script, the way
// Xfennec's `progress` does it: for cp, mv, dd, rsync, tar, compressors,
// archivers, scp, pv and ffmpeg, the largest regular file opened read-only
// is the input; its fdinfo offset ("pos") against its size gives exact
// progress, and the offset delta gives the rate. The largest file opened
// for writing (when any) is shown as the destination. Inputs under 1 MiB
// are ignored, as are other users' processes.

func init() { register("fileOps", func() Source { return newProcSource(fileOpTools, fileOpPick) }) }

const fileOpMinSize = 1 << 20

// comm -> default verb
var fileOpTools = map[string]string{
	"cp":      "Copying",
	"mv":      "Moving",
	"dd":      "Copying",
	"rsync":   "Copying",
	"scp":     "Copying",
	"pv":      "Copying",
	"tar":     "Archiving",
	"bsdtar":  "Archiving",
	"gzip":    "Compressing",
	"pigz":    "Compressing",
	"bzip2":   "Compressing",
	"pbzip2":  "Compressing",
	"xz":      "Compressing",
	"zstd":    "Compressing",
	"lz4":     "Compressing",
	"gunzip":  "Extracting",
	"unxz":    "Extracting",
	"unzstd":  "Extracting",
	"bunzip2": "Extracting",
	"7z":      "Compressing",
	"7za":     "Compressing",
	"7zz":     "Compressing",
	"zip":     "Compressing",
	"unzip":   "Extracting",
	"unrar":   "Extracting",
	"ffmpeg":  "Converting",
}

// fileOpVerb refines the default verb from the command line.
func fileOpVerb(p Proc) string {
	verb := fileOpTools[p.Comm]
	args := p.Args
	if len(args) > 0 {
		args = args[1:]
	}
	switch p.Comm {
	case "tar", "bsdtar":
		for _, a := range args {
			if a == "-x" || a == "--extract" || a == "--get" ||
				(strings.HasPrefix(a, "-") && !strings.HasPrefix(a, "--") && strings.Contains(a, "x")) ||
				(!strings.HasPrefix(a, "-") && strings.HasPrefix(a, "x")) {
				return "Extracting"
			}
		}
	case "gzip", "pigz", "bzip2", "pbzip2", "xz", "zstd", "lz4":
		for _, a := range args {
			if a == "-d" || a == "--decompress" || a == "--uncompress" ||
				(strings.HasPrefix(a, "-") && !strings.HasPrefix(a, "--") && strings.Contains(a, "d")) {
				return "Extracting"
			}
		}
	case "7z", "7za", "7zz":
		if len(args) > 0 && (args[0] == "x" || args[0] == "e") {
			return "Extracting"
		}
	}
	return verb
}

// fileOpPick reads the input's offset against its size.
func fileOpPick(p Proc, fds []FD) *procPick {
	var in, out *FD
	inSize, outSize := int64(-1), int64(-1)
	for i := range fds {
		fd := fds[i]
		size := FileSize(fd.Target)
		if size < 0 {
			continue
		}
		if fd.ReadOnly() && size >= fileOpMinSize && size > inSize {
			in, inSize = &fds[i], size
		}
		if fd.Writable() && size > outSize {
			out, outSize = &fds[i], size
		}
	}
	if in == nil {
		return nil
	}
	pos := in.Pos
	if pos > inSize {
		pos = inSize
	}
	pick := &procPick{
		key:       in.Target,
		title:     filepath.Base(in.Target),
		path:      in.Target,
		detail:    fileOpVerb(p),
		processed: pos,
		total:     inSize,
		kind:      KindCopy,
		app:       p.Comm,
		icon:      "system-file-manager",
	}
	if out != nil {
		pick.path = out.Target
	}
	return pick
}
