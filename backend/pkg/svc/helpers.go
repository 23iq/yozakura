package svc

import (
	"encoding/json"
	"errors"
	"fmt"

	"yozakura/backend/pkg/ipc"
)

// RawParams is the raw JSON params payload type used by handlers.
type RawParams = json.RawMessage

// subID keys a subscriber by its own pointer (stable, unique while it is alive).
func subID(sub *ipc.Subscriber) string {
	return fmt.Sprintf("%p", sub)
}

func errorsNew(msg string) error { return errors.New(msg) }