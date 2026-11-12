// Package client holds the client side of the daemon's socket protocol that
// is shared by the daemon CLI (`subscribe`) and in-process callers such as the
// backend's compositor service.
package client

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"math"
	"net"
)

// SubscribeMethod is the request that turns a connection into an event
// stream: the daemon answers with a State.Dump notification and then pushes
// one notification line per compositor event.
const SubscribeMethod = "System.Subscribe"

// initialLineBuf is the scanner's starting buffer; it grows up to maxLine.
const initialLineBuf = 64 * 1024

// Subscribe dials the daemon socket, sends System.Subscribe and calls onLine
// with every non-empty line the daemon writes (the subscribe reply and each
// notification, one JSON value per line). The slice passed to onLine is only
// valid during the call.
//
// It returns when the connection ends: io.EOF when the daemon closed it, the
// read error otherwise (bufio.ErrTooLong for a line over maxLine; maxLine <= 0
// means no limit), or ctx.Err() once ctx is cancelled, which also closes the
// connection so a blocked read returns at once.
func Subscribe(ctx context.Context, socketPath string, maxLine int, onLine func([]byte)) error {
	var d net.Dialer
	conn, err := d.DialContext(ctx, "unix", socketPath)
	if err != nil {
		return err
	}
	defer conn.Close()
	stop := context.AfterFunc(ctx, func() { _ = conn.Close() })
	defer stop()

	req, _ := json.Marshal(map[string]any{
		"id":     1,
		"method": SubscribeMethod,
		"params": map[string]any{},
	})
	if _, err := conn.Write(append(req, '\n')); err != nil {
		if ctx.Err() != nil {
			return ctx.Err()
		}
		return fmt.Errorf("send subscribe: %w", err)
	}

	err = ReadLines(conn, maxLine, onLine)
	if ctx.Err() != nil {
		return ctx.Err()
	}
	return err
}

// ReadLines calls onLine for each non-empty line of r until r ends (io.EOF)
// or fails. A line longer than maxLine (maxLine <= 0: unlimited) stops it
// with bufio.ErrTooLong.
func ReadLines(r io.Reader, maxLine int, onLine func([]byte)) error {
	if maxLine <= 0 {
		maxLine = math.MaxInt
	}
	sc := bufio.NewScanner(r)
	sc.Buffer(make([]byte, 0, min(initialLineBuf, maxLine)), maxLine)
	for sc.Scan() {
		if line := sc.Bytes(); len(line) > 0 {
			onLine(line)
		}
	}
	if err := sc.Err(); err != nil {
		return err
	}
	return io.EOF
}
