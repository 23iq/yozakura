package server

import (
	"errors"
	"testing"

	"yozakura/backend/pkg/yozd/ipc"
	"yozakura/backend/pkg/yozd/ipc/mock"
)

type errComp struct {
	*mock.Compositor
	errs []string
}

func (e errComp) ConfigErrors() ([]string, error) { return e.errs, nil }

func TestConfigErrorsRPC(t *testing.T) {
	if _, err := configErrors(mock.NewCompositor()); !errors.Is(err, ipc.ErrNotSupported) {
		t.Fatalf("want ErrNotSupported, got %v", err)
	}
	s := &Server{compositor: errComp{Compositor: mock.NewCompositor()}}
	res, err := s.dispatchExtra(Request{Method: "Config.Errors"})
	if l, ok := res.([]string); err != nil || !ok || l == nil || len(l) != 0 {
		t.Fatalf("clean: %#v %v", res, err)
	}
	s = &Server{compositor: errComp{Compositor: mock.NewCompositor(), errs: []string{"x"}}}
	if res, _ = s.dispatchExtra(Request{Method: "Config.Errors"}); len(res.([]string)) != 1 {
		t.Fatalf("%v", res)
	}
}
