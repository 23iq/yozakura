package ipc

import (
	"bufio"
	"encoding/json"
	"fmt"
	"log"
	"net"
	"os"
	"runtime/debug"
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

// NewSubscriber returns a subscriber with an event buffer of size buf, as
// the server creates for a stream (services' tests use it to drive Stop).
func NewSubscriber(buf int) *Subscriber {
	return &Subscriber{Events: make(chan ServiceEvent, buf), stop: make(chan struct{})}
}

// Push queues event without blocking; it is dropped when the buffer is full.
func (s *Subscriber) Push(event ServiceEvent) {
	s.TryPush(event)
}

// TryPush is Push reporting whether event was queued, for streams that must
// recover from a drop (resend their state) instead of losing it silently.
func (s *Subscriber) TryPush(event ServiceEvent) bool {
	select {
	case s.Events <- event:
		return true
	default:
		return false
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

// TrySend is Send reporting whether the event was queued (see TryPush).
func (s *Subscriber) TrySend(service string, data any) bool {
	return s.TryPush(ServiceEvent{Service: service, Data: data})
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
	s := &Server{
		path:     path,
		services: make(map[string]*Service),
	}
	s.registerBuiltin()
	return s
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

	// Ordered (non-async) requests run one at a time, in order, on this
	// worker, so the reader keeps reading while one is slow: an async
	// request behind it (the shell's freeze-watchdog heartbeat shares its
	// socket with compositor calls that may take their whole timeout) runs
	// at once instead of waiting for it.
	serial := make(chan Request, serialQueue)
	defer close(serial)
	go func() {
		for req := range serial {
			s.handleOne(writer, &wmu, &req)
			pending.Done()
		}
	}()

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
		pending.Add(1)
		if s.isAsync(req.Method) {
			go func(req Request) {
				defer pending.Done()
				s.handleOne(writer, &wmu, &req)
			}(req)
			continue
		}
		serial <- req
	}
}

// serialQueue is how many ordered requests may wait behind a slow one
// before the reader stops reading the connection.
const serialQueue = 256

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

	raw, errMsg := invoke(req.Method, hdl, req.Params)
	if errMsg != "" {
		w.write(Response{ID: req.ID, Error: errMsg})
		return
	}
	w.write(Response{ID: req.ID, Result: raw})
}

// crashOnPanic, deferred around service code, logs a panic with the stack
// of the goroutine that raised it and then panics again, so the daemon
// still dies exactly as an unrecovered panic would. It must not swallow
// the panic: most services take their mutex without a deferred Unlock, so
// a handler that panics mid-section leaves the lock held and every later
// call to that service would block forever. A dead daemon is recoverable
// (the next CLI call or keybind starts it again through ensureDaemon, which
// sweeps the children of the old one); a half-deadlocked one is not.
func crashOnPanic(what string) {
	if r := recover(); r != nil {
		log.Printf("[ipc] panic in %s: %v\n%s", what, r, debug.Stack())
		panic(r)
	}
}

// invoke runs one handler and marshals its result.
func invoke(method string, hdl HandlerFunc, params json.RawMessage) (json.RawMessage, string) {
	defer crashOnPanic(method)
	result, err := hdl(params)
	if err != nil {
		return nil, err.Error()
	}
	if result == nil {
		return nil, ""
	}
	data, err := json.Marshal(result)
	if err != nil {
		return nil, "result marshal failed"
	}
	return data, ""
}

// runSubscribe registers a stream with one service.
func runSubscribe(svc *Service, sub *Subscriber) {
	defer crashOnPanic(svc.Name + " subscribe")
	svc.Subscribe(sub)
}

// marshalEvent serializes a ServiceEvent for the result field.
func marshalEvent(event ServiceEvent) json.RawMessage {
	defer crashOnPanic("marshalling a " + event.Service + " event")
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
