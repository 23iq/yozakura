package ipc

// ConfigErrorLister is implemented by compositors that report the errors of
// their last config load (Hyprland: `hyprctl configerrors`). Others answer
// Config.Errors with ErrNotSupported.
type ConfigErrorLister interface {
	ConfigErrors() ([]string, error)
}
