package main

import (
	"bytes"
	"errors"
	"strings"
	"testing"

	"yozakura/backend/pkg/apphooks"
)

type goodbyeHook struct {
	id      string
	err     error
	reverts *[]string
}

func (h goodbyeHook) ID() string                          { return h.id }
func (h goodbyeHook) Status(apphooks.Env) apphooks.Status { return apphooks.Status{ID: h.id} }
func (h goodbyeHook) Apply(apphooks.Env) (apphooks.Status, error) {
	return apphooks.Status{ID: h.id}, nil
}
func (h goodbyeHook) Revert(apphooks.Env) (apphooks.Status, error) {
	*h.reverts = append(*h.reverts, h.id)
	return apphooks.Status{ID: h.id, State: apphooks.StateDisconnected}, h.err
}

func TestGoodbyeRevertsEveryHook(t *testing.T) {
	var got []string
	var out bytes.Buffer
	revertAppHooks(&out, apphooks.Env{}, []apphooks.Hook{
		goodbyeHook{"kitty", nil, &got},
		goodbyeHook{"discord", errors.New("read-only"), &got},
		goodbyeHook{"foot", nil, &got},
	})
	if strings.Join(got, ",") != "kitty,discord,foot" {
		t.Fatalf("reverted %v", got)
	}
	if !strings.Contains(out.String(), "discord") || strings.Contains(out.String(), "kitty") {
		t.Fatalf("report %q", out.String())
	}
}
