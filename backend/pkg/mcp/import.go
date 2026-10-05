package mcp

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// Transports.
const (
	TransportStdio = "stdio"
	TransportHTTP  = "http"
	TransportSSE   = "sse"
)

// Sources, in de-duplication priority order.
const (
	SourceYozakura      = "yozakura"
	SourceClaude        = "claude"
	SourceClaudeProject = "claude-project"
	SourceCodex         = "codex"
	SourceOpencode      = "opencode"
)

var sourcePriority = map[string]int{
	SourceYozakura: 0, SourceClaude: 1, SourceClaudeProject: 2, SourceCodex: 3, SourceOpencode: 4,
}

// ServerSpec is a normalized MCP server definition.
type ServerSpec struct {
	Name      string            `json:"name"`
	Source    string            `json:"source"`
	Project   string            `json:"project,omitempty"`
	Transport string            `json:"transport"`
	Command   string            `json:"command,omitempty"`
	Args      []string          `json:"args,omitempty"`
	Env       map[string]string `json:"env,omitempty"`
	Cwd       string            `json:"cwd,omitempty"`
	URL       string            `json:"url,omitempty"`
	Headers   map[string]string `json:"headers,omitempty"`
	Enabled   bool              `json:"enabled"`
}

// Public is the IPC-safe view: env and header values are never exposed.
type Public struct {
	Name       string   `json:"name"`
	Source     string   `json:"source"`
	Project    string   `json:"project,omitempty"`
	Transport  string   `json:"transport"`
	Command    string   `json:"command,omitempty"`
	Args       []string `json:"args"`
	URL        string   `json:"url,omitempty"`
	EnvKeys    []string `json:"envKeys"`
	HeaderKeys []string `json:"headerKeys"`
	Enabled    bool     `json:"enabled"`
}

// Public returns the redacted view of s.
func (s ServerSpec) Public() Public {
	args := s.Args
	if args == nil {
		args = []string{}
	}
	return Public{
		Name: s.Name, Source: s.Source, Project: s.Project, Transport: s.Transport,
		Command: s.Command, Args: args, URL: redactURL(s.URL),
		EnvKeys: sortedKeys(s.Env), HeaderKeys: sortedKeys(s.Headers), Enabled: s.Enabled,
	}
}

// redactURL drops query strings, which often carry API keys.
func redactURL(u string) string {
	if i := strings.IndexByte(u, '?'); i >= 0 {
		return u[:i] + "?…"
	}
	return u
}

func sortedKeys(m map[string]string) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}

// ImportOptions selects which configs to read. Empty paths use defaults.
type ImportOptions struct {
	Claude, Codex, Opencode bool
	Home                    string // defaults to os.UserHomeDir
	ClaudeJSON              string // ~/.claude.json
	ClaudeSettings          string // ~/.claude/settings.json
	CodexTOML               string // $CODEX_HOME/config.toml
	OpencodeDir             string // $XDG_CONFIG_HOME/opencode
	ProjectMCPJSON          bool   // also read <project>/.mcp.json for Claude projects
}

// Duplicate records a server dropped because a higher-priority source
// already defined the same name.
type Duplicate struct {
	Name   string `json:"name"`
	Source string `json:"source"`
	KeptBy string `json:"keptBy"`
}

// ImportResult is the merged server list plus diagnostics.
type ImportResult struct {
	Servers    []ServerSpec `json:"servers"`
	Duplicates []Duplicate  `json:"duplicates"`
	Errors     []string     `json:"errors"`
}

func (o *ImportOptions) defaults() {
	if o.Home == "" {
		o.Home, _ = os.UserHomeDir()
	}
	if o.ClaudeJSON == "" {
		o.ClaudeJSON = filepath.Join(o.Home, ".claude.json")
	}
	if o.ClaudeSettings == "" {
		o.ClaudeSettings = filepath.Join(o.Home, ".claude", "settings.json")
	}
	if o.CodexTOML == "" {
		dir := os.Getenv("CODEX_HOME")
		if dir == "" {
			dir = filepath.Join(o.Home, ".codex")
		}
		o.CodexTOML = filepath.Join(dir, "config.toml")
	}
	if o.OpencodeDir == "" {
		base := os.Getenv("XDG_CONFIG_HOME")
		if base == "" {
			base = filepath.Join(o.Home, ".config")
		}
		o.OpencodeDir = filepath.Join(base, "opencode")
	}
}

// Import reads every selected config and merges the results.
func Import(o ImportOptions) ImportResult {
	o.defaults()
	var all []ServerSpec
	var errs []string
	add := func(list []ServerSpec, err error) {
		if err != nil && !os.IsNotExist(err) {
			errs = append(errs, err.Error())
		}
		all = append(all, list...)
	}
	if o.Claude {
		add(ImportClaude(o.ClaudeJSON, o.ProjectMCPJSON))
		add(importClaudeSettings(o.ClaudeSettings))
	}
	if o.Codex {
		add(ImportCodex(o.CodexTOML))
	}
	if o.Opencode {
		add(ImportOpencode(o.OpencodeDir))
	}
	res := Merge(all)
	res.Errors = errs
	if res.Errors == nil {
		res.Errors = []string{}
	}
	return res
}

// Merge de-duplicates by name; the highest-priority source wins, ties keep
// the first occurrence. Output is sorted by source priority, then name.
func Merge(specs []ServerSpec) ImportResult {
	sorted := append([]ServerSpec(nil), specs...)
	sort.SliceStable(sorted, func(i, j int) bool {
		return sourcePriority[sorted[i].Source] < sourcePriority[sorted[j].Source]
	})
	seen := map[string]string{}
	res := ImportResult{Servers: []ServerSpec{}, Duplicates: []Duplicate{}}
	for _, s := range sorted {
		if keptBy, dup := seen[s.Name]; dup {
			res.Duplicates = append(res.Duplicates, Duplicate{Name: s.Name, Source: s.Source, KeptBy: keptBy})
			continue
		}
		seen[s.Name] = s.Source
		res.Servers = append(res.Servers, s)
	}
	sort.SliceStable(res.Servers, func(i, j int) bool {
		a, b := res.Servers[i], res.Servers[j]
		if pa, pb := sourcePriority[a.Source], sourcePriority[b.Source]; pa != pb {
			return pa < pb
		}
		return a.Name < b.Name
	})
	return res
}

// claudeServer is the Claude Code / .mcp.json server shape.
type claudeServer struct {
	Type    string            `json:"type"`
	Command string            `json:"command"`
	Args    []string          `json:"args"`
	Env     map[string]string `json:"env"`
	URL     string            `json:"url"`
	Headers map[string]string `json:"headers"`
}

func (c claudeServer) spec(name, source, project string) ServerSpec {
	s := ServerSpec{Name: name, Source: source, Project: project, Command: c.Command, Args: c.Args,
		Env: c.Env, URL: c.URL, Headers: c.Headers, Enabled: true}
	switch strings.ToLower(c.Type) {
	case "http", "streamable-http", "streamable_http":
		s.Transport = TransportHTTP
	case "sse":
		s.Transport = TransportSSE
	default:
		s.Transport = TransportStdio
		if c.Command == "" && c.URL != "" {
			s.Transport = TransportHTTP
		}
	}
	return s
}

func claudeServers(m map[string]claudeServer, source, project string) []ServerSpec {
	names := make([]string, 0, len(m))
	for n := range m {
		names = append(names, n)
	}
	sort.Strings(names)
	out := make([]ServerSpec, 0, len(m))
	for _, n := range names {
		out = append(out, m[n].spec(n, source, project))
	}
	return out
}

// ImportClaude reads ~/.claude.json: top-level mcpServers and every
// projects[path].mcpServers (and optionally <path>/.mcp.json).
func ImportClaude(path string, projectFiles bool) ([]ServerSpec, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var doc struct {
		MCPServers map[string]claudeServer `json:"mcpServers"`
		Projects   map[string]struct {
			MCPServers         map[string]claudeServer `json:"mcpServers"`
			DisabledMcpServers []string                `json:"disabledMcpjsonServers"`
		} `json:"projects"`
	}
	if err := json.Unmarshal(data, &doc); err != nil {
		return nil, fmt.Errorf("%s: %w", path, err)
	}
	out := claudeServers(doc.MCPServers, SourceClaude, "")
	projects := make([]string, 0, len(doc.Projects))
	for p := range doc.Projects {
		projects = append(projects, p)
	}
	sort.Strings(projects)
	for _, p := range projects {
		out = append(out, claudeServers(doc.Projects[p].MCPServers, SourceClaudeProject, p)...)
		if projectFiles {
			if list, err := importMCPJSON(filepath.Join(p, ".mcp.json"), p); err == nil {
				out = append(out, list...)
			}
		}
	}
	return out, nil
}

func importMCPJSON(path, project string) ([]ServerSpec, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var doc struct {
		MCPServers map[string]claudeServer `json:"mcpServers"`
	}
	if err := json.Unmarshal(data, &doc); err != nil {
		return nil, err
	}
	return claudeServers(doc.MCPServers, SourceClaudeProject, project), nil
}

func importClaudeSettings(path string) ([]ServerSpec, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var doc struct {
		MCPServers map[string]claudeServer `json:"mcpServers"`
	}
	if err := json.Unmarshal([]byte(StripJSONC(string(data))), &doc); err != nil {
		return nil, fmt.Errorf("%s: %w", path, err)
	}
	return claudeServers(doc.MCPServers, SourceClaude, ""), nil
}
