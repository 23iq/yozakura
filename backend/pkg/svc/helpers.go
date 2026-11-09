package svc

import (
	"encoding/json"
	"errors"
)

// RawParams is the raw JSON params payload type used by handlers.
type RawParams = json.RawMessage

func errorsNew(msg string) error { return errors.New(msg) }
