package ipc

import (
	"encoding/json"
	"sort"
)

// ProtocolVersion is the wire protocol revision of the JSON-RPC API. Bump it
// on any breaking change to a method or event shape; the shell
// (modules/services/BackendService.qml, expectedProtocol) warns when it
// differs from what the daemon reports through ipc.hello.
const ProtocolVersion = 1

// ServiceInfo describes one registered service for the method registry.
type ServiceInfo struct {
	Name      string   `json:"name"`
	Methods   []string `json:"methods"`
	Subscribe bool     `json:"subscribe"`
}

// Registry is the machine-readable list of everything the server answers.
type Registry struct {
	Protocol int           `json:"protocol"`
	Services []ServiceInfo `json:"services"`
}

// Describe lists every registered service with its sorted method names.
func (s *Server) Describe() Registry {
	s.mu.RLock()
	defer s.mu.RUnlock()
	reg := Registry{Protocol: ProtocolVersion, Services: []ServiceInfo{}}
	for _, svc := range s.services {
		info := ServiceInfo{Name: svc.Name, Methods: []string{}, Subscribe: svc.Subscribe != nil}
		for m := range svc.Methods {
			info.Methods = append(info.Methods, m)
		}
		sort.Strings(info.Methods)
		reg.Services = append(reg.Services, info)
	}
	sort.Slice(reg.Services, func(i, j int) bool { return reg.Services[i].Name < reg.Services[j].Name })
	return reg
}

// registerBuiltin adds the "ipc" service: ipc.hello (protocol handshake) and
// ipc.methods (the registry of the running daemon).
func (s *Server) registerBuiltin() {
	s.Register(&Service{
		Name: "ipc",
		Methods: map[string]HandlerFunc{
			"hello": func(json.RawMessage) (any, error) {
				return map[string]any{"protocol": ProtocolVersion}, nil
			},
			"methods": func(json.RawMessage) (any, error) { return s.Describe(), nil },
		},
	})
}
