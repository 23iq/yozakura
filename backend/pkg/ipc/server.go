package ipc

import (
	"bufio"
	"encoding/json"
	"fmt"
	"net"
	"os"
	"sync"

	"yozakura/backend/pkg/instancelock"
)

// Request is a JSON-RPC like request: {"id":..., "method":"...", "params":{...}}
type Request struct {
	ID     json.RawMessage `json:"id"`
	Method string          `json:"method"`
	Params json.RawMessage `json:"params"`
}

// Response is a JSON-RPC like response: {"id":..., "result":{...}} or {"id":..., "error":"..."}
type Response struct {
	ID     json.RawMessage `json:"id"`
	Result json.RawMessage `json:"result,omitempty"`
	Error  string          `json:"error,omitempty"`
}

// ServiceEvent is a subscription push: {"service":"...", "data":{...}}
type ServiceEvent struct {
	Service string `json:"service"`
	Data    any    `json:"data"`
}

// HandlerFunc processes a method request and returns the result payload.
type HandlerFunc func(params json.RawMessage) (any, error)

// Service is a set of methods plus an optional subscription stream.
type Service struct {
	Name      string
	Methods   map[string]HandlerFunc
	Subscribe func(sub *Subscriber)
	// Async lists slow methods (network, child processes) that run in their
	// own goroutine so they do not block later requests on the same
	// connection. Responses are matched by id, so order does not matter.
	Async map[string]bool
}

// Subscriber is a per-client subscription context.
type Subscriber struct {
	Events chan ServiceEvent
	stop   chan struct{}
	once   sync.Once
}

func (s *Subscriber) Push(event ServiceEvent) {
	select {
	case s.Events <- event:
	default:
	}
}

func (s *Subscriber) Stop() {
	s.once.Do(func() { close(s.stop) })
}

// StopCh exposes the subscriber stop channel for select.
func (s *Subscriber) StopCh() <-chan struct{} { return s.stop }

func (s *Subscriber) Send(service string, data any) {
	s.Push(ServiceEvent{Service: service, Data: data})
}

// Server is a line-delimited JSON server over a Unix socket.
// A connection serves request/response while possible. A "subscribe"
// request on a connection transitions it into a streaming event channel.
type Server struct {
	path      string
	services  map[string]*Service
	mu        sync.RWMutex
	listener  net.Listener
	closeOnce sync.Once
	sockID    instancelock.SocketID
}

func NewServer(path string) *Server {
	return &Server{
		path:     path,
		services: make(map[string]*Service),
	}
}

func (s *Server) Register(svc *Service) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.services[svc.Name] = svc
}

func (s *Server) SocketPath() string { return s.path }

// Listen binds the Unix socket.
func (s *Server) Listen() error {
	if err := os.Remove(s.path); err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("remove stale socket: %w", err)
	}
	ln, err := net.Listen("unix", s.path)
	if err != nil {
		return err
	}
	// Go would unlink the path by name on Close, even when a successor has
	// since bound a new socket there; Close removes it only if still ours.
	if ul, ok := ln.(*net.UnixListener); ok {
		ul.SetUnlinkOnClose(false)
	}
	s.sockID = instancelock.StatSocket(s.path)
	if err := os.Chmod(s.path, 0o600); err != nil {
		return err
	}
	s.listener = ln
	return nil
}

// Close shuts down the server and removes the socket if it is still the
// one this server bound. Only the first call
// acts, so a later Close cannot remove a socket a new daemon has created.
func (s *Server) Close() {
	s.closeOnce.Do(func() {
		if s.listener != nil {
			s.listener.Close()
		}
		instancelock.RemoveIfOwned(s.path, s.sockID)
	})
}

// Serve accepts connections until the listener is closed.
func (s *Server) Serve() error {
	for {
		conn, err := s.listener.Accept()
		if err != nil {
			return err
		}
		go s.handleConn(conn)
	}
}

func (s *Server) handleConn(conn net.Conn) {
	defer conn.Close()
	scanner := bufio.NewScanner(conn)
	scanner.Buffer(make([]byte, 0, 64*1024), 64*1024*1024)
	writer := bufio.NewWriter(conn)
	var wmu sync.Mutex
	var pending sync.WaitGroup
	defer pending.Wait()

	for scanner.Scan() {
		line := scanner.Bytes()
		if len(line) == 0 {
			continue
		}
		var req Request
		if err := json.Unmarshal(line, &req); err != nil {
			wmu.Lock()
			writeMessage(writer, Response{ID: nil, Error: "invalid request JSON"})
			wmu.Unlock()
			continue
		}
		if req.Method == "subscribe" {
			pending.Wait()
			s.streamSubscribe(conn, writer, &req)
			return
		}
		if s.isAsync(req.Method) {
			pending.Add(1)
			go func(req Request) {
				defer pending.Done()
				s.handleOne(writer, &wmu, &req)
			}(req)
			continue
		}
		s.handleOne(writer, &wmu, &req)
	}
}

type lockedWriter struct {
	w  *bufio.Writer
	mu *sync.Mutex
}

func (l *lockedWriter) write(resp Response) {
	l.mu.Lock()
	defer l.mu.Unlock()
	writeMessage(l.w, resp)
}

func writeMessage(w *bufio.Writer, resp Response) {
	data, err := json.Marshal(resp)
	if err != nil {
		return
	}
	w.Write(append(data, '\n'))
	w.Flush()
}

func (s *Server) isAsync(method string) bool {
	svcName, m := splitMethod(method)
	s.mu.RLock()
	defer s.mu.RUnlock()
	svc := s.services[svcName]
	return svc != nil && svc.Async[m]
}

// handleOne processes a single request and writes its response; wmu
// serializes writes with concurrently running async handlers.
func (s *Server) handleOne(bw *bufio.Writer, wmu *sync.Mutex, req *Request) {
	if len(req.ID) == 0 {
		return
	}
	w := &lockedWriter{w: bw, mu: wmu}
	svcName, method := splitMethod(req.Method)
	if svcName == "" {
		w.write(Response{ID: req.ID, Error: fmt.Sprintf("unknown method: %s", req.Method)})
		return
	}
	s.mu.RLock()
	svc := s.services[svcName]
	s.mu.RUnlock()
	if svc == nil {
		w.write(Response{ID: req.ID, Error: fmt.Sprintf("unknown service: %s", svcName)})
		return
	}
	hdl, ok := svc.Methods[method]
	if !ok {
		w.write(Response{ID: req.ID, Error: fmt.Sprintf("unknown method: %s", req.Method)})
		return
	}

	result, err := hdl(req.Params)
	if err != nil {
		w.write(Response{ID: req.ID, Error: err.Error()})
		return
	}
	var raw json.RawMessage
	if result != nil {
		data, merr := json.Marshal(result)
		if merr != nil {
			w.write(Response{ID: req.ID, Error: "result marshal failed"})
			return
		}
		raw = data
	}
	w.write(Response{ID: req.ID, Result: raw})
}

// marshalEvent serializes a ServiceEvent for the result field.
func marshalEvent(event ServiceEvent) json.RawMessage {
	data, err := json.Marshal(event)
	if err != nil {
		return json.RawMessage(`{"error":"marshal failed"}`)
	}
	return data
}

func splitMethod(method string) (string, string) {
	for i := 0; i < len(method); i++ {
		if method[i] == '.' {
			return method[:i], method[i+1:]
		}
	}
	return "", method
}

func contains(list []string, item string) bool {
	for _, v := range list {
		if v == item {
			return true
		}
	}
	return false
}
