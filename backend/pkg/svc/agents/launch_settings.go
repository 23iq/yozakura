package agents

import "errors"

// Optional adapter validation keeps provider-specific launch rules out of the manager.
type launchValidator interface {
	ValidateLaunch(mode, prompt string) error
}

func validateLaunch(a Adapter, mode, prompt string) error {
	switch mode {
	case "", "agent", "shell", "oneshot":
	default:
		return errors.New("unknown agent session mode")
	}
	if validator, ok := a.(launchValidator); ok {
		return validator.ValidateLaunch(mode, prompt)
	}
	if mode == "oneshot" {
		return errors.New("this adapter cannot restrict quick-request tools")
	}
	return nil
}
func (codexAdapter) ValidateLaunch(string, string) error  { return nil }
func (claudeAdapter) ValidateLaunch(string, string) error { return nil }
func (acpAdapter) ValidateLaunch(mode, prompt string) error {
	if mode == "oneshot" {
		return errors.New("ACP does not advertise a restricted quick-request tool profile")
	}
	if prompt != "" {
		return errors.New("ACP does not support custom system instructions")
	}
	return nil
}
