package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"yozakura/backend/pkg/brand"
)

// chatInfo is one saved AI chat as listed for the AI center session list.
type chatInfo struct {
	ID      string `json:"id"`
	Title   string `json:"title"`
	Pinned  bool   `json:"pinned"`
	Mode    string `json:"mode"`
	Model   string `json:"model"`
	Updated int64  `json:"updated"`
	Preview string `json:"preview"`
	Count   int    `json:"count"`
	// Search is a lowercased excerpt of the whole conversation for filtering.
	Search string `json:"search"`
}

type chatMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type chatFileV2 struct {
	Version  int           `json:"version"`
	Title    string        `json:"title"`
	Pinned   bool          `json:"pinned"`
	Mode     string        `json:"mode"`
	Model    string        `json:"model"`
	Updated  int64         `json:"updated"`
	Messages []chatMessage `json:"messages"`
}

const searchLimit = 4000

func truncateRunes(s string, n int) string {
	r := []rune(s)
	if len(r) <= n {
		return s
	}
	return string(r[:n]) + "…"
}

func oneLine(s string) string {
	return strings.TrimSpace(strings.Join(strings.Fields(s), " "))
}

// readChat parses both chat formats: v1 (a bare message array) and v2
// ({version, title, pinned, messages, ...}).
func readChat(path string, mtime int64) (chatInfo, bool) {
	id := strings.TrimSuffix(filepath.Base(path), ".json")
	info := chatInfo{ID: id, Title: "New Chat", Mode: "chat", Updated: mtime}
	data, err := os.ReadFile(path)
	if err != nil {
		return info, false
	}
	var msgs []chatMessage
	var v2 chatFileV2
	if json.Unmarshal(data, &msgs) != nil {
		if json.Unmarshal(data, &v2) != nil || v2.Version < 2 {
			return info, false
		}
		msgs = v2.Messages
		info.Pinned = v2.Pinned
		if v2.Mode != "" {
			info.Mode = v2.Mode
		}
		info.Model = v2.Model
		if v2.Updated > 0 {
			info.Updated = v2.Updated
		}
	}
	var search strings.Builder
	for _, m := range msgs {
		if m.Role != "user" && m.Role != "assistant" {
			continue
		}
		info.Count++
		if m.Role == "user" && info.Title == "New Chat" {
			info.Title = truncateRunes(oneLine(m.Content), 48)
		}
		if m.Role == "assistant" && m.Content != "" {
			info.Preview = truncateRunes(oneLine(m.Content), 90)
		}
		if search.Len() < searchLimit {
			search.WriteString(strings.ToLower(oneLine(m.Content)))
			search.WriteByte(' ')
		}
	}
	if v2.Title != "" {
		info.Title = v2.Title
	}
	info.Search = truncateRunes(search.String(), searchLimit)
	return info, true
}

// listChats returns the chats in dir, pinned first, then newest first.
func listChats(dir string) []chatInfo {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil
	}
	out := []chatInfo{}
	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".json") {
			continue
		}
		fi, err := e.Info()
		if err != nil {
			continue
		}
		if info, ok := readChat(filepath.Join(dir, e.Name()), fi.ModTime().UnixMilli()); ok {
			out = append(out, info)
		}
	}
	sort.SliceStable(out, func(i, j int) bool {
		if out[i].Pinned != out[j].Pinned {
			return out[i].Pinned
		}
		return out[i].Updated > out[j].Updated
	})
	return out
}

// runChatList lists AI chats: "id|title" lines, or JSON with --json.
//
//	yozakura chatlist [--json] <chat_dir>
func runChatList(args []string) int {
	asJSON := false
	rest := []string{}
	for _, a := range args {
		if a == "--json" {
			asJSON = true
		} else {
			rest = append(rest, a)
		}
	}
	if len(rest) < 1 {
		fmt.Fprintln(os.Stderr, "Usage: "+brand.AppID+" chatlist [--json] <chat_dir>")
		return 1
	}
	chatDir := rest[0]
	if err := os.MkdirAll(chatDir, 0o755); err != nil {
		return 1
	}
	chats := listChats(chatDir)
	if asJSON {
		data, err := json.Marshal(chats)
		if err != nil {
			return 1
		}
		fmt.Println(string(data))
		return 0
	}
	for _, c := range chats {
		fmt.Printf("%s|%s\n", c.ID, c.Title)
	}
	return 0
}
