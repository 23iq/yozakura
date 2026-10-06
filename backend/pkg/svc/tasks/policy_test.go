package tasks

import (
	"testing"

	"yozakura/backend/pkg/svc/agents"
)

func TestDeniedCommand(t *testing.T) {
	wt := "/data/wt/k1"
	allowed := []string{
		"make check", "go test ./...", "npm install && npm test", "rm -rf build", "rm -rf ./node_modules dist/*",
		"git status", "git commit -m wip", "curl -s https://example.com", "mkdir -p src/new", "cp ../x.txt notes.txt",
		"echo hi > out.txt", "ls 2>/dev/null", "bash -lc 'go vet ./...'", "/usr/bin/bash -lc \"cargo build\"",
		"CGO_ENABLED=0 go build", "wget https://example.com/file", "rsync -a src/ dst/", "chmod 755 run.sh",
	}
	for _, c := range allowed {
		if why := DeniedCommand(c, wt); why != "" {
			t.Errorf("%q denied: %s", c, why)
		}
	}
	denied := []string{
		"git push", "git push origin main", "git -C . push", "make && git push --force", "git remote add x y",
		"git config --global user.name x", "sudo make install", "doas rm x", "curl -X POST https://x", "curl -d a=1 https://x",
		"curl --data-binary @f https://x", "curl -F f=@x https://x", "wget --post-data=a https://x", "scp a host:b",
		"rsync -a dist/ host:/srv", "ssh host ls", "rm -rf /", "rm -rf ~/x", "rm -rf ../other", "rm -rf $HOME/x",
		"rm /etc/passwd", "echo x > /etc/hosts", "cat a >> ~/.bashrc", "echo $(whoami)", "ls `pwd`", "npm publish",
		"cargo publish", "docker push img", "gh pr create", "mv src /tmp/src", "cp a.txt /usr/local/bin/a",
		"systemctl --user stop x", "dd if=/dev/zero of=x", "bash -lc 'git push'", "tee /etc/x",
	}
	for _, c := range denied {
		if why := DeniedCommand(c, wt); why == "" {
			t.Errorf("%q allowed", c)
		}
	}
}

func TestScopeDecide(t *testing.T) {
	var s scopes
	s.set("wt", sessionScope{worktree: "/w/k1"})
	s.set("plan", sessionScope{worktree: "/w/k1", planning: true})
	s.set("here", sessionScope{worktree: "/p", inPlace: true})
	meta := func(id string) agents.SessionMeta { return agents.SessionMeta{ID: id} }
	req := func(cat, path string, in map[string]any) agents.PermissionRequest {
		return agents.PermissionRequest{Category: cat, Path: path, Input: in}
	}
	cases := []struct {
		id   string
		req  agents.PermissionRequest
		want string
	}{
		{"other", req(agents.CatWrite, "/w/k1/a", nil), ""},
		{"wt", req(agents.CatWrite, "/w/k1/a.go", nil), agents.DecisionAllow},
		{"wt", req(agents.CatWrite, "", map[string]any{"file_path": "/w/k1/sub/b.go"}), agents.DecisionAllow},
		{"wt", req(agents.CatWrite, "/w/k1/../k2/a", nil), ""},
		{"wt", req(agents.CatWrite, "/home/u/.bashrc", nil), ""},
		{"wt", req(agents.CatWrite, "", nil), ""},
		{"wt", req(agents.CatExec, "", map[string]any{"command": "make check"}), agents.DecisionAllow},
		{"wt", req(agents.CatExec, "", map[string]any{"command": []any{"git", "push"}}), ""},
		{"wt", req(agents.CatExec, "", map[string]any{"command": "git push"}), ""},
		{"wt", req(agents.CatNetwork, "", nil), agents.DecisionAllow},
		{"wt", req(agents.CatRead, "", nil), agents.DecisionAllow},
		{"wt", req(agents.CatMCP, "", nil), ""},
		{"plan", req(agents.CatWrite, "/w/k1/a", nil), agents.DecisionDeny},
		{"plan", req(agents.CatExec, "", map[string]any{"command": "make"}), ""},
		{"here", req(agents.CatWrite, "/p/a", nil), ""},
	}
	for i, c := range cases {
		if got := s.decide(meta(c.id), c.req); got != c.want {
			t.Errorf("case %d (%s %s): got %q want %q", i, c.id, c.req.Category, got, c.want)
		}
	}
}
