package main

import (
	"fmt"
	"io"
	"sync"
)

// CleanupEnv is what a goodbye cleanup step gets. Confirm asks a y/N
// question (false in non-interactive runs); Purge is --purge (downloaded
// models and logs go too).
type CleanupEnv struct {
	Out     io.Writer
	Confirm func(question string) bool
	Purge   bool
	Home    string
}

// CleanupFunc undoes one thing the app added outside its own directories and
// returns what it removed (one line each). It must be idempotent: running it
// where the artifact never existed returns nothing and no error.
type CleanupFunc func(env CleanupEnv) (removed []string, err error)

type cleanupStep struct {
	name string
	fn   CleanupFunc
}

var (
	cleanupMu    sync.Mutex
	cleanupSteps []cleanupStep
)

// RegisterCleanup adds a step to `goodbye`; features register their own
// (apphooks, the fish prompt, moved monitor lines, ...). Steps run in
// registration order; registering a name again replaces that step.
func RegisterCleanup(name string, fn CleanupFunc) {
	cleanupMu.Lock()
	defer cleanupMu.Unlock()
	for i := range cleanupSteps {
		if cleanupSteps[i].name == name {
			cleanupSteps[i].fn = fn
			return
		}
	}
	cleanupSteps = append(cleanupSteps, cleanupStep{name, fn})
}

func registeredCleanups() []cleanupStep {
	cleanupMu.Lock()
	defer cleanupMu.Unlock()
	return append([]cleanupStep(nil), cleanupSteps...)
}

// cleanupResult is one step's outcome for the summary.
type cleanupResult struct {
	Name    string
	Removed []string
	Err     error
}

// runCleanups runs steps in order (a failing step never stops the others)
// and prints the summary of what was removed.
func runCleanups(env CleanupEnv, steps []cleanupStep) []cleanupResult {
	var results []cleanupResult
	for _, s := range steps {
		removed, err := s.fn(env)
		results = append(results, cleanupResult{s.name, removed, err})
	}
	printCleanupSummary(env.Out, results)
	return results
}

func printCleanupSummary(w io.Writer, results []cleanupResult) {
	total := 0
	for _, r := range results {
		total += len(r.Removed)
		for _, item := range r.Removed {
			fmt.Fprintf(w, "  removed [%s] %s\n", r.Name, item)
		}
		if r.Err != nil {
			fmt.Fprintf(w, "  could not finish [%s]: %v\n", r.Name, r.Err)
		}
	}
	if total == 0 {
		fmt.Fprintln(w, "  nothing extra to clean up")
	}
}
