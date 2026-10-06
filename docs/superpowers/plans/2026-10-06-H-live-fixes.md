# H. AI bar live fixes: project picker, narrow layout, model in advance

Bugs from live testing on the real shell (Hyprland), after A–G.

## 1. Code project folder

Problems: "Open folder…" / Browse ran `zenity` (slow, can open under the
layer-shell panel) and the choice went through `Ai.configureAgent({cwd})`,
which returned false silently while busy, was keyed by agent (switching
agent lost the project) and was not persisted.

- **State**: `modules/services/ai/CodeProject.qml` (owned by `Ai.project`):
  `dir` = StateService `aiCodeProject` || `ai.agents.defaultCwd` ||
  `recentDirs[0]` || `$HOME`; `set(path)` normalises (`~`, trailing `/`),
  persists and calls `AgentSessions.rememberDir` (recentDirs).
- **Facade**: `Ai.projectDir`, `Ai.chooseProject(dir)`. In the Code space
  `agentSettings.cwd` is the project (no longer an override), so new
  sessions (`RequestRunner` -> `agents.create`), the project bar, the task
  board/composer and `TasksService` all read the same value.
  `configureAgent({cwd})` in Code forwards to `chooseProject`. Choosing a
  project while a session of another folder is open moves the view to a new
  session there (the old one keeps running in the history). Opening a Code
  session from the history adopts its folder; `TasksService.focusTask`
  adopts the task's project.
- **Picker**: `modules/aicenter/code/FolderPicker.qml` (sheet, overlay
  `folder` in `AiCenterPanel`, opened by ProjectBar `pickRequested` and
  AgentSettings `browseRequested`), `FolderRow.qml`, `FolderBrowser.qml`
  (IPC + per-folder cache) and pure `FolderPath.js` (field parsing, crumbs,
  rows, keyboard). Empty field: Recent + Repositories, typing filters;
  `~/…` or `/…` browses (breadcrumbs, hidden toggle, git repos marked).
  Up/Down select, Tab/Right browse in, Enter / double click choose,
  Esc closes; "System dialog…" keeps zenity as a fallback.
- **Backend**: new `backend/pkg/svc/fsbrowse` service `fs`:
  `fs.list {dir}` -> `{dir, parent, git, entries:[{name,path,git,hidden}]}`
  (folders only, ≤2000) and `fs.repos {refresh}` -> `{repos:[{path,name,
  modified}], scannedAt}` (BFS of ~ to depth 4, skips node_modules/.cache/
  .local/vendor/…, 1.5 s / 40k-folder budget, cached 10 min, concurrent
  callers share one scan). Without it (old daemon) the picker says so and a
  typed path still works.

## 2. Narrow / short layout

Root cause of the overflow: non-`fillWidth` items in Qt Quick Layouts are
fixed at their implicit width, so wide rows (task options, project bar,
task tabs) forced the whole column wider than the bar. Fixes:
`Chip` elides when given less than its implicit width; ProjectBar items
shrink (narrow: branch icon + changes, instructions icon only; popovers
clamped to the bar); TaskOptions chips wrap (`Flow`); TaskDetail runs/tabs
scroll sideways; TaskHeader agent label elides; header switch goes
icons-only below 400 px in Code; empty states (`CenteredScroll`) scroll
instead of spilling over the composer; the workspace area clips; model
picker clamped in width and height, hint hidden when narrow; Usage screen
drops its title when narrow; Agent settings and Usage are opaque; Agent
settings content width fixed (`availableWidth`).

## 3. Model in advance

Backend `agents.models` entries gain `resolved` (Claude's `default` alias ->
"Opus 5.5", from the SDK `description`/`resolvedModel`). `EffortPrefs.
agentModelLabel`; `Ai.effort.modelLabel/effortLabel/summary`. The strip
shows `Codex · GPT-5.5` + the concrete effort (auto shows the engine
default level), Welcome/CodeEmpty show "Using Codex · GPT-5.5 · low"
(`common/UsingModel.qml`, click = picker), task options show the resolved
model and default effort, Agent settings list "Engine default · Opus 5.5".

## 4. Busy refusals

`Ai.refuseBusy()` sets a visible notice (`ai.busy_notice`), cleared when
the turn ends; used by `configureAgent`, `effort.set` and the model picker.

## Tests

`tests/ai-folder-path.test.cjs`, `tests/ai-code-project.test.py` (real
facade), `tests/ai-folder-picker.test.py` (aiscene UI flow),
`ai-model-info.test.cjs` (model label), Go `fsbrowse` + catalog resolved.

## Notes for later sub-projects

- Read the Code project from `Ai.projectDir`; change it only with
  `Ai.chooseProject`. `Ai.agentSettings.cwd` is the active session's cwd or
  the project.
- `Ai.refuseBusy()` for any setting refused during a turn.
- `fs.list` / `fs.repos` are generic; reuse for other folder pickers.
- Overflow rule: in a RowLayout give shrinkable items `Layout.fillWidth:
  true; Layout.maximumWidth: implicitWidth`.

## Manual test

1. `make build`, restart Yozakura (the `fs` service is new).
2. AI bar, Code (Ctrl+2), project ▾ -> Open folder…: the sheet opens
   instantly with Recent and Repositories. Type `yoz` -> filtered; type
   `~/` -> browse, eye shows dot folders, Tab enters, Enter chooses.
3. Project bar shows the folder, the board refreshes; switch agent: the
   project stays. Restart the shell: still the same project.
4. Start a chat session, choose another folder while it runs: the view
   moves to a new session there; the running one is in the history.
5. While a reply runs, change the effort: a notice explains why.
6. New Assistant chat / Code: "Using … · model · effort" before the first
   message; the strip shows the concrete model.
7. Compact width (~340 px) and a short bar: nothing clipped or off-centre.
