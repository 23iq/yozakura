package yozakura

import (
	"encoding/json"
	"testing"

	"github.com/stretchr/testify/assert"

	"yozakura/backend/pkg/brand"
)

func TestSpecialTools(t *testing.T) {
	d, r, ipc := newDeps(t)
	d.AppDirs = []string{"../../specials/testdata/apps"}
	d.BindsFile = "../../specials/testdata/binds.json"

	empty := callTool(t, d, "specials_list", `{}`)
	assert.False(t, empty.IsError, empty.Text())
	assert.Contains(t, empty.Text(), `"specials": []`)

	add := callTool(t, d, "special_add", `{"name":"Discord","toggle":"SUPER+D","send":"SUPER+ALT+D","accent":"tertiary"}`)
	assert.False(t, add.IsError, add.Text())
	assert.Contains(t, add.Text(), `"workspace": "special:Discord"`)
	assert.Contains(t, add.Text(), `"match": "discord"`, "known name: installed app suggested")

	bad := callTool(t, d, "special_add", `{"name":"discord"}`)
	assert.True(t, bad.IsError, "same Hyprland name")
	clash := callTool(t, d, "special_add", `{"name":"Telegram","toggle":"SUPER+S","apps":[]}`)
	assert.False(t, clash.IsError, clash.Text())
	assert.Contains(t, clash.Text(), "core bind system.tools")

	up := callTool(t, d, "special_update", `{"name":"discord","newName":"Chat","preload":true}`)
	assert.False(t, up.IsError, up.Text())
	app := callTool(t, d, "special_app_add", `{"name":"Chat","match":"vesktop","command":"vesktop","ifRunning":"move","rule":true}`)
	assert.False(t, app.IsError, app.Text())
	hex := callTool(t, d, "special_update", `{"name":"Chat","accent":"#ff0000"}`)
	assert.True(t, hex.IsError, "palette roles only")

	r.bins[brand.Daemon] = true
	r.out[brand.Daemon+" workspace list"] = `[{"id":"-98","name":"special:Chat"},{"id":"1","name":"1"}]`
	r.out[brand.Daemon+" window list"] = `[{"id":"0x1","app_id":"vesktop","workspace_id":"-98"},{"id":"0x2","app_id":"foot","workspace_id":"1"}]`
	list := callTool(t, d, "specials_list", `{}`)
	var got struct {
		Specials []struct {
			Name, Workspace string
			Windows         int
			Preload         bool
			Apps            []map[string]any
		}
	}
	assert.NoError(t, json.Unmarshal([]byte(list.Text()), &got), list.Text())
	if assert.Len(t, got.Specials, 2) {
		assert.Equal(t, "Chat", got.Specials[0].Name)
		assert.Equal(t, "special:Chat", got.Specials[0].Workspace)
		assert.Equal(t, 1, got.Specials[0].Windows)
		assert.True(t, got.Specials[0].Preload)
		assert.Len(t, got.Specials[0].Apps, 2)
	}

	open := callTool(t, d, "special_open", `{"name":"chat"}`)
	assert.False(t, open.IsError, open.Text())
	last := ipc.calls[len(ipc.calls)-1]
	assert.Equal(t, "ui.toggle", last.Method)
	ipc.down = true
	open = callTool(t, d, "special_open", `{"name":"Telegram"}`)
	assert.False(t, open.IsError, open.Text())
	assert.Equal(t, []string{"workspace", "toggle-special", "Telegram"}, r.last().Args)

	rm := callTool(t, d, "special_remove", `{"name":"Telegram"}`)
	assert.False(t, rm.IsError, rm.Text())
	missing := callTool(t, d, "special_open", `{"name":"Telegram"}`)
	assert.True(t, missing.IsError)
}
