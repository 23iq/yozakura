package mcp

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
)

// ImportCodex reads [mcp_servers.<name>] tables from Codex's config.toml.
func ImportCodex(path string) ([]ServerSpec, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	doc, err := ParseTOML(string(data))
	if err != nil {
		return nil, fmt.Errorf("%s: %w", path, err)
	}
	servers, _ := doc["mcp_servers"].(map[string]any)
	names := make([]string, 0, len(servers))
	for n := range servers {
		names = append(names, n)
	}
	sort.Strings(names)
	var out []ServerSpec
	for _, n := range names {
		t, ok := servers[n].(map[string]any)
		if !ok {
			continue
		}
		s := ServerSpec{Name: n, Source: SourceCodex, Enabled: true, Transport: TransportStdio}
		s.Command, _ = t["command"].(string)
		s.Args = stringList(t["args"])
		s.Env = stringMap(t["env"])
		s.Cwd, _ = t["cwd"].(string)
		if en, ok := t["enabled"].(bool); ok {
			s.Enabled = en
		}
		if u, ok := t["url"].(string); ok && u != "" {
			s.URL = u
			s.Transport = TransportHTTP
			s.Headers = stringMap(t["http_headers"])
			if envHeaders := stringMap(t["env_http_headers"]); len(envHeaders) > 0 {
				if s.Headers == nil {
					s.Headers = map[string]string{}
				}
				for h, envName := range envHeaders {
					s.Headers[h] = os.Getenv(envName)
				}
			}
			if tokVar, ok := t["bearer_token_env_var"].(string); ok && tokVar != "" {
				if s.Headers == nil {
					s.Headers = map[string]string{}
				}
				s.Headers["Authorization"] = "Bearer " + os.Getenv(tokVar)
			}
		}
		out = append(out, s)
	}
	return out, nil
}

// ImportOpencode reads the "mcp" object of opencode.json / opencode.jsonc
// in dir (both files are merged, .jsonc last like OpenCode does).
func ImportOpencode(dir string) ([]ServerSpec, error) {
	merged := map[string]map[string]any{}
	found := false
	var firstErr error
	for _, f := range []string{"config.json", "opencode.json", "opencode.jsonc"} {
		data, err := os.ReadFile(filepath.Join(dir, f))
		if err != nil {
			continue
		}
		found = true
		var doc struct {
			MCP map[string]map[string]any `json:"mcp"`
		}
		if err := json.Unmarshal([]byte(StripJSONC(string(data))), &doc); err != nil {
			if firstErr == nil {
				firstErr = fmt.Errorf("%s: %w", filepath.Join(dir, f), err)
			}
			continue
		}
		for n, v := range doc.MCP {
			if merged[n] == nil {
				merged[n] = map[string]any{}
			}
			for k, val := range v {
				merged[n][k] = val
			}
		}
	}
	if !found {
		return nil, os.ErrNotExist
	}
	names := make([]string, 0, len(merged))
	for n := range merged {
		names = append(names, n)
	}
	sort.Strings(names)
	var out []ServerSpec
	for _, n := range names {
		t := merged[n]
		s := ServerSpec{Name: n, Source: SourceOpencode, Enabled: true}
		if en, ok := t["enabled"].(bool); ok {
			s.Enabled = en
		}
		typ, _ := t["type"].(string)
		if typ == "remote" || (typ == "" && t["url"] != nil) {
			s.Transport = TransportHTTP
			s.URL, _ = t["url"].(string)
			s.Headers = stringMap(t["headers"])
		} else {
			s.Transport = TransportStdio
			cmd := stringList(t["command"])
			if len(cmd) == 0 {
				if c, ok := t["command"].(string); ok {
					cmd = []string{c}
				}
			}
			if len(cmd) > 0 {
				s.Command, s.Args = cmd[0], cmd[1:]
			}
			s.Env = stringMap(t["environment"])
		}
		out = append(out, s)
	}
	return out, firstErr
}

func stringList(v any) []string {
	arr, ok := v.([]any)
	if !ok {
		return nil
	}
	out := make([]string, 0, len(arr))
	for _, x := range arr {
		switch y := x.(type) {
		case string:
			out = append(out, y)
		default:
			out = append(out, fmt.Sprint(y))
		}
	}
	return out
}

func stringMap(v any) map[string]string {
	m, ok := v.(map[string]any)
	if !ok || len(m) == 0 {
		return nil
	}
	out := make(map[string]string, len(m))
	for k, x := range m {
		if s, ok := x.(string); ok {
			out[k] = s
		} else {
			out[k] = fmt.Sprint(x)
		}
	}
	return out
}
