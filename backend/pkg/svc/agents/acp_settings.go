package agents

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
)

type acpOptionValue struct {
	Value   string           `json:"value"`
	Name    string           `json:"name"`
	Options []acpOptionValue `json:"options"`
}
type acpConfigOption struct {
	ID           string           `json:"id"`
	Category     string           `json:"category"`
	Type         string           `json:"type"`
	CurrentValue string           `json:"currentValue"`
	Options      []acpOptionValue `json:"options"`
}

func optionValues(list []acpOptionValue) []acpOptionValue {
	var out []acpOptionValue
	for _, v := range list {
		if v.Value != "" {
			out = append(out, v)
		}
		out = append(out, optionValues(v.Options)...)
	}
	return out
}
func findOption(options []acpConfigOption, category string) *acpConfigOption {
	for i := range options {
		if options[i].Category == category && options[i].Type == "select" {
			return &options[i]
		}
	}
	return nil
}
func acpCatalog(options []acpConfigOption) ModelCatalog {
	result := ModelCatalog{Models: []ModelInfo{}}
	model := findOption(options, "model")
	if model == nil {
		result.Error = "ACP agent did not advertise model configuration"
		return result
	}
	effort := findOption(options, "thought_level")
	values := optionValues(model.Options)
	if len(values) == 0 && model.CurrentValue != "" {
		values = append(values, acpOptionValue{Value: model.CurrentValue, Name: model.CurrentValue})
	}
	for _, value := range values {
		entry := ModelInfo{ID: value.Value, Name: value.Name, Efforts: []string{}, IsDefault: value.Value == model.CurrentValue}
		if effort != nil {
			entry.DefaultEffort = effort.CurrentValue
			for _, v := range optionValues(effort.Options) {
				entry.Efforts = append(entry.Efforts, v.Value)
			}
		}
		result.Models = append(result.Models, entry)
	}
	return result
}
func (a acpAdapter) Models(ctx context.Context, o StartOptions) (ModelCatalog, error) {
	raw, err := discoveryPeer(ctx, o, a.spec.args(o), map[string]any{"protocolVersion": 1, "clientCapabilities": map[string]any{}}, false, func(rpc *rpcPeer, finish func(json.RawMessage, error)) {
		err := rpc.Call("session/new", map[string]any{"cwd": o.Cwd, "mcpServers": []any{}}, func(raw json.RawMessage, e *rpcError) {
			if e != nil {
				finish(nil, e)
				return
			}
			finish(raw, nil)
		})
		if err != nil {
			finish(nil, err)
		}
	})
	if err != nil {
		return ModelCatalog{}, err
	}
	var result struct {
		ConfigOptions []acpConfigOption `json:"configOptions"`
	}
	if err := json.Unmarshal(raw, &result); err != nil {
		return ModelCatalog{}, err
	}
	return acpCatalog(result.ConfigOptions), nil
}
func (c *acpConn) applySettings(sid string, options []acpConfigOption) {
	type change struct{ id, value string }
	var changes []change
	for _, setting := range []struct{ category, value string }{{"model", c.opts.Model}, {"thought_level", c.opts.Effort}} {
		if setting.value == "" {
			continue
		}
		option := findOption(options, setting.category)
		if option == nil {
			c.settingsFailed(errors.New("ACP agent did not advertise " + setting.category))
			return
		}
		found := setting.value == option.CurrentValue
		for _, value := range optionValues(option.Options) {
			if value.Value == setting.value {
				found = true
			}
		}
		if !found {
			c.settingsFailed(fmt.Errorf("unsupported ACP %s: %s", setting.category, setting.value))
			return
		}
		changes = append(changes, change{option.ID, setting.value})
	}
	var next func(int)
	next = func(i int) {
		if i == len(changes) {
			c.markReady()
			return
		}
		change := changes[i]
		err := c.rpc.Call("session/set_config_option", map[string]any{"sessionId": sid, "configId": change.id, "value": change.value}, func(_ json.RawMessage, e *rpcError) {
			if e != nil {
				c.settingsFailed(e)
				return
			}
			next(i + 1)
		})
		if err != nil {
			c.settingsFailed(err)
		}
	}
	next(0)
}
func (c *acpConn) settingsFailed(err error) {
	c.sink.Emit(Event{Kind: KindError, Message: err.Error()})
	c.failStart()
}
