package ipc

import (
	"encoding/json"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestDescribeListsServicesAndBuiltin(t *testing.T) {
	srv := NewServer("unused")
	srv.Register(&Service{
		Name:      "zeta",
		Methods:   map[string]HandlerFunc{"b": nil, "a": nil},
		Subscribe: func(*Subscriber) {},
	})
	reg := srv.Describe()
	assert.Equal(t, ProtocolVersion, reg.Protocol)
	assert.Equal(t, "ipc", reg.Services[0].Name)
	assert.Equal(t, []string{"hello", "methods"}, reg.Services[0].Methods)
	last := reg.Services[len(reg.Services)-1]
	assert.Equal(t, ServiceInfo{Name: "zeta", Methods: []string{"a", "b"}, Subscribe: true}, last)
}

func TestHelloReportsProtocol(t *testing.T) {
	srv := NewServer("unused")
	out, err := srv.services["ipc"].Methods["hello"](nil)
	assert.NoError(t, err)
	data, _ := json.Marshal(out)
	assert.JSONEq(t, `{"protocol":1}`, string(data))
}
