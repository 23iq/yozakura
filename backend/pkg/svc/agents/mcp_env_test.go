package agents

import (
	"strings"
	"testing"
)

func TestWithShellEnvForwardsSessionVars(t *testing.T) {
	t.Setenv("XDG_RUNTIME_DIR", "/run/user/4242")
	t.Setenv("WAYLAND_DISPLAY", "wayland-1")
	t.Setenv("NIRI_SOCKET", "")
	srv := withShellEnv(MCPServer{Name: YozakuraMCPName, Env: map[string]string{"WAYLAND_DISPLAY": "keep"}})
	if srv.Env["XDG_RUNTIME_DIR"] != "/run/user/4242" {
		t.Fatalf("XDG_RUNTIME_DIR not forwarded: %v", srv.Env)
	}
	if srv.Env["WAYLAND_DISPLAY"] != "keep" {
		t.Fatalf("explicit value overwritten: %v", srv.Env)
	}
	if _, ok := srv.Env["NIRI_SOCKET"]; ok {
		t.Fatalf("empty variable forwarded: %v", srv.Env)
	}
}

func TestCodexArgsForwardShellEnvByName(t *testing.T) {
	t.Setenv("XDG_RUNTIME_DIR", "/run/user/4242")
	args, env, err := codexArgs(StartOptions{MCP: []MCPServer{withShellEnv(MCPServer{Name: YozakuraMCPName, Transport: "stdio", Command: "/bin/yozakura", Args: []string{"mcp"}})}})
	if err != nil {
		t.Fatal(err)
	}
	found := false
	for _, a := range args {
		if strings.Contains(a, "env_vars=") && strings.Contains(a, "XDG_RUNTIME_DIR") {
			found = true
		}
	}
	if !found {
		t.Fatalf("env_vars with XDG_RUNTIME_DIR missing from %v", args)
	}
	has := false
	for _, e := range env {
		if e == "XDG_RUNTIME_DIR=/run/user/4242" {
			has = true
		}
	}
	if !has {
		t.Fatalf("XDG_RUNTIME_DIR not in env %v", env)
	}
}
