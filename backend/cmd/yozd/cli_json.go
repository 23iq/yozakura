package main

import (
	"encoding/json"
	"fmt"
)

// mergeJSONParams decodes a JSON object argument into params, so
// `yozd monitor apply '{"name":"DP-1",...}'` sends those fields as the
// request params.
func mergeJSONParams(params map[string]interface{}, arg string) error {
	var obj map[string]interface{}
	if err := json.Unmarshal([]byte(arg), &obj); err != nil {
		return fmt.Errorf("invalid JSON argument: %v", err)
	}
	for k, v := range obj {
		params[k] = v
	}
	return nil
}
