package svc

import (
	"encoding/json"
	"errors"
	"fmt"

	"yozakura/backend/pkg/ipc"
)

// RawParams is the raw JSON params payload type used by handlers.
type RawParams = json.RawMessage

// subID generates a unique subscriber key per goroutine invocation.
func subID(sub *ipc.Subscriber) string {
	return fmt.Sprintf("%p", &sub)
}

func errorsNew(msg string) error { return errors.New(msg) }