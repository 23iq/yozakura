package convert

import (
	"context"
	"errors"
	"fmt"
)

// Error codes: the stable, machine-readable cause of a conversion error,
// sent next to its English message (IPC responses, Job, File). The window
// translates a code (converter.error.<code>, %1.. = Args); for the codes
// in DetailCodes the message is a tool's or parser's own words and is
// shown as it is.
const (
	CodeNotFound             = "not_found"             // the file does not exist
	CodeFolder               = "folder"                // a folder, not a file
	CodeNotRegular           = "not_regular"           // a FIFO, a device...
	CodeUnknownFormat        = "unknown_format"        // neither name nor content tell
	CodeUnknownTarget        = "unknown_target"        // Args: the target asked for
	CodeUnsupported          = "unsupported"           // Args: source label, target label
	CodeToolMissing          = "tool_missing"          // Args: target label, tool
	CodeTooLarge             = "too_large"             // the file or image exceeds a limit
	CodeTimeout              = "timeout"               // Args: program
	CodeCancelled            = "cancelled"             // stopped by the user
	CodeToolFailed           = "tool_failed"           // detail: the tool's own message
	CodeBadInput             = "bad_input"             // detail: what the parser said
	CodeNoOutput             = "no_output"             // the tool wrote nothing
	CodeCrashed              = "crashed"               // a panic, turned into an error
	CodeNoWrite              = "no_write"              // Args: folder
	CodeExists               = "exists"                // Args: name, folder (no free name)
	CodeOutDir               = "out_dir"               // Args: folder
	CodeStopping             = "stopping"              // the service is shutting down
	CodeClipboardEmpty       = "clipboard_empty"       // nothing is copied
	CodeClipboardUnavailable = "clipboard_unavailable" // wl-clipboard is not installed
	CodeClipboardNoFile      = "clipboard_no_file"     // something is copied, not a file
	CodeBadRequest           = "bad_request"           // malformed IPC parameters
	CodeUnknownJob           = "unknown_job"           // Args: job id
)

// DetailCodes carry a message that is the detail itself (shown as is).
var DetailCodes = map[string]bool{CodeToolFailed: true, CodeBadInput: true}

// Error is a conversion error with its code and the arguments of its
// translation.
type Error struct {
	Code string
	Args []string
	Msg  string
	Err  error
}

func (e *Error) Error() string { return e.Msg }

func (e *Error) Unwrap() error { return e.Err }

// ErrorCode and ErrorArgs let the IPC server send the code next to the
// message.
func (e *Error) ErrorCode() string   { return e.Code }
func (e *Error) ErrorArgs() []string { return e.Args }

// Errorf builds a coded error; args are the translation's %1, %2...
func Errorf(code string, args []string, format string, a ...any) *Error {
	return &Error{Code: code, Args: args, Msg: fmt.Sprintf(format, a...)}
}

// Wrap codes err (its message kept), unless it already has a code.
func Wrap(code string, err error, args ...string) error {
	if err == nil {
		return nil
	}
	var e *Error
	if errors.As(err, &e) {
		return err
	}
	return &Error{Code: code, Args: args, Msg: err.Error(), Err: err}
}

// CodeOf returns the code and arguments of err: its own, cancelled or
// timeout for context errors, else fallback.
func CodeOf(err error, fallback string) (string, []string) {
	var e *Error
	switch {
	case err == nil:
		return "", nil
	case errors.As(err, &e):
		return e.Code, e.Args
	case errors.Is(err, context.Canceled):
		return CodeCancelled, nil
	case errors.Is(err, context.DeadlineExceeded):
		return CodeTimeout, nil
	}
	return fallback, nil
}
