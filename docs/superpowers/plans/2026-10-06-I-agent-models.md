# I. Agent models in the picker, "set once, stays"

User bug: in the Assistant only the CLI agent (Claude Code, Codex, OpenCode)
could be chosen, not its model (Haiku, gpt-5.5, ...); the model choice lived
in the gear (hidden in Assistant) and in memory only, and every new chat
went back to `ai.defaultModel`.

## Design

- **Picker** (`modules/aicenter/header/`): `AgentPickerRows.js` (pure) adds
  child rows under each installed agent: its `agents.models` catalog for
  `Ai.agentCwd` ($HOME in Assistant, the project in Code), the default marked
  ("Agent default · Opus 5.5"), effort levels per model, a loading / error
  (Retry) / empty row and a manual id field when `manualModel`.
  `PickerModel.build` takes `agentCatalogs`, `expanded`, `currentId`,
  `currentAgentModel`; search matches agent models too ("haiku" lists
  Claude > Haiku). Rows: `AgentModelRow.qml`, `AgentModelNote.qml`; the agent
  row (`ModelPickerRow`) shows a caret. Click / Enter on an agent toggles it
  (Right/Left too); the current agent opens expanded and selected on its
  model. Opening the picker loads every installed agent's catalog once.
  Picking a child calls `Ai.pickAgentModel(agent, model)` (engine + model +
  remembered effort in one step). Claude's `default` alias is stored as ""
  (the CLI resolves it); any other id is stored as is.
- **Persistence** (`modules/services/ai/EngineMemory.qml`, StateService,
  the project's convention for UI state):
  `aiEngines = {assistant: {id, base}, code: {id, base}}` (legacy
  `lastAiModel` / `lastAiCodeModel` read once and still written),
  `aiAgentModels = {"assistant:claude": "haiku", ...}`; effort stays per model
  in `aiModelEfforts` (EffortState). `EngineSelection.start(default, pick)`:
  the last pick wins; the configured default applies when nothing was picked
  or when it changed after the pick (`base` = the default at pick time), so
  editing/pinning the setting is the newer explicit choice.
- **Users**: startup and space entry (`Ai._ensureInit`, `SpaceState.enter`),
  `Ai.newConversation` (the space's pick, not a resumed session's engine),
  `Ai.agentSettings.model` (pick, else `ai.agents.<id>.model`),
  `configureAgent({model})` records the pick (gear, picker), Quick ask
  (`quickModel` and its agent model when `ai.quickAsk.model` is empty),
  Code tasks (`TaskOptions`: agent + model of the Code pick unless
  `ai.tasks.defaultAgents` is set). Resumed sessions keep their own model.
- Backend unchanged: `agents.create {model}` -> `SessionMeta.Model` ->
  `claude --model`, Codex turn `model`, OpenCode ACP setting.

## Tests

- `tests/ai-picker-model.test.cjs`: expanded/collapsed agents, current mark,
  status/manual rows, keyboard skipping, search, native id.
- `tests/ai-engine-selection.test.cjs`: `start` / `startCode` rules.
- `tests/ai-agent-model-picker.test.py`: real panel + picker: expand, pick a
  child, reopen marked, default alias, search, manual id.
- `tests/ai-engine-memory.test.py`: real `Ai.qml`: pick -> agents.create
  model/effort, new chat keeps it, resumed session shows its own, Quick ask
  follows, Code keeps its own, restart (second instance), changed default.
- Go `TestManagerCreateModelReachesTheCLI`: `--model haiku` in the launch
  args. Live (build tag `live`, one session): `Model:haiku` session answered by
  `claude-haiku-4-5-20251001` (Claude's session log).

## Notes for later sub-projects

- `Ai.engineMemory.engine(space)` / `.agentModel(space, agent)` /
  `.remember*` are the API; do not read `lastAiModel` directly.
- `Ai.agentCwd` is the folder agents list models for in the visible space.
- The gear (`AgentSettings.qml`) still works and also records the pick.
- Picker pin action is not added; pinning stays in the gear ("Use as default
  engine"), and `EngineSelection.start` honours it as the newer choice.

## Manual test

1. Ctrl+K in the Assistant: Claude Code / Codex / OpenCode show a caret;
   click Claude: Default (Opus …), Haiku, Sonnet, … with effort levels.
2. Click Haiku: the strip says `Claude Code · Haiku · …`; send a message.
3. New chat (Ctrl+N): still Haiku. Restart the shell: still Haiku.
4. Type `gpt` in the picker: Codex > gpt-5.x rows; pick one.
5. Open an old session with another model: it shows its model; New chat
   goes back to the last pick.
6. Quick ask (notch) with `ai.quickAsk.model` empty uses the same model.
