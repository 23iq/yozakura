package yozakura

import "io"

func pipes() (*io.PipeReader, *io.PipeWriter, *io.PipeReader, *io.PipeWriter) {
	cr, sw := io.Pipe()
	sr, cw := io.Pipe()
	return cr, sw, sr, cw
}
