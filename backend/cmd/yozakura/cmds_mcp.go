package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"
	"yozakura/backend/pkg/brand"

	"yozakura/backend/pkg/mcp/yozakura"
)

// runMCP serves the Yozakura MCP tools on stdin/stdout. stdout carries
// only protocol frames; diagnostics go to stderr.
//
//	yozakura mcp               serve (spawned by Claude Code, Codex, OpenCode, ...)
//	yozakura mcp --list-tools  print tool names and exit
func runMCP(args []string) int {
	srv := yozakura.NewServer(yozakura.DefaultDeps(), readVersion())
	if len(args) > 0 && (args[0] == "--list-tools" || args[0] == "-l") {
		for _, t := range srv.Tools() {
			ro := ""
			if t.ReadOnly() {
				ro = " (read-only)"
			}
			fmt.Fprintf(os.Stderr, "%s%s\n", t.Name, ro)
		}
		return 0
	}
	srv.Logger = log.New(os.Stderr, "["+brand.AppID+" mcp] ", log.LstdFlags)
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	if err := srv.Serve(ctx, os.Stdin, os.Stdout); err != nil {
		fmt.Fprintf(os.Stderr, "%s mcp: %v\n", brand.AppID, err)
		return 1
	}
	return 0
}
