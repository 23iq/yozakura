package agents

import "errors"

// Session modes. ModeAssistant is the AI bar's Assistant space: $HOME as
// working directory, the yozakura MCP server always attached and the agent's
// built-in tools kept (commands and file writes ask through the policy).
// "shell" was its former name; stored sessions and old clients still send it.
const (
	ModeAgent     = "agent"
	ModeAssistant = "assistant"
	ModeOneshot   = "oneshot"
	legacyShell   = "shell"
)

// normalizeMode maps the legacy "shell" mode to ModeAssistant.
func normalizeMode(mode string) string {
	if mode == legacyShell {
		return ModeAssistant
	}
	return mode
}

// Optional adapter validation keeps provider-specific launch rules out of the manager.
type launchValidator interface {
	ValidateLaunch(mode, prompt string) error
}

func validateLaunch(a Adapter, mode, prompt string) error {
	switch normalizeMode(mode) {
	case "", ModeAgent, ModeAssistant, ModeOneshot:
	default:
		return errors.New("unknown agent session mode")
	}
	if validator, ok := a.(launchValidator); ok {
		return validator.ValidateLaunch(mode, prompt)
	}
	if mode == ModeOneshot {
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
