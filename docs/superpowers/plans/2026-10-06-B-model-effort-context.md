# B. Model, effort, context: plan

Spec: `docs/superpowers/specs/2026-10-06-ai-bar-redesign-design.md` (section B).
Builds on A (ComposerStatus slots, Transcript.js) and C1 (`providers.*` IPC,
`assets/ai/models.json`, `Effort.js`, `ProviderPresets.js`).

## Data flow

- **Capabilities**: `ModelCatalog` reads `assets/ai/models.json`
  (`ModelTable.qml`, FileView) and attaches `info` (contextWindow,
  maxOutput, vision, tools, reasoning, efforts, effortMap, budget) to every
  HTTP entry through the pure `ModelInfo.js` (same lookup as Go
  `ModelTable.Lookup`). Ollama models come from the backend
  `providers.ollama.probe` (`OllamaProbe.qml`, throttled re-probe when the
  picker opens) with their real capabilities and `contextLength`; the old
  KeyStore "ollama" + `/api/tags` path stays as a fallback when the backend
  is unreachable. Ollama models without `tools` get `tools: false` ->
  "chat only" badge and no tools in the request.
- **Effort**: `EffortState.qml` (owned by `Ai`) keeps a per-model memory
  (`StateService` `aiModelEfforts`: `{"openai:gpt-5": "high",
  "agent:codex/gpt-5.5": "xhigh"}`), resolves the current level with
  `Effort.resolve` (HTTP) or the agent catalog's `efforts` (CLI agents,
  native values), and writes it back when the user changes it in a chat
  (that is the model's new default). `ai.effort.default` (`auto` = model
  default) applies to models never touched. HTTP: `ChatSession.effort` ->
  `ChatRequest` -> `Providers.body(..., {effort})` -> `Effort.apply` with
  `ProviderPresets.effortFamily(provider)`. Agents: `Ai.agentSettings.effort`
  falls back to the memory before `ai.agents.<id>.effort`.
- **Context**: backend agent `done` events gain `usage.contextTokens` and
  `usage.contextWindow` (Codex `thread/tokenUsage/updated` `last.totalTokens`
  + `modelContextWindow`; Claude last assistant message usage + result
  `modelUsage.*.contextWindow`). `ChatSession.contextTokens` = last turn's
  input + output tokens. `ContextState.qml` (owned by `Ai`) computes
  `used/window/fraction/level` for the visible session: agents from the
  timeline usage, HTTP from `ai.context.overrides` > Ollama
  `min(contextLength, ai.ollama.numCtx)` > models.json. Ollama requests send
  `options.num_ctx` (pure `ContextMath.numCtx`).
- **Compaction** (HTTP only): `Compaction.js` (pure) picks the rows to
  summarise (everything before the last `keepTurns` user turns, after the
  previous summary). `ChatCompactor.qml` runs one summarisation request
  (same model or `ai.context.compactModel`) and inserts a `summary` row;
  `ChatRows.toMessages` sends the last summary + the rows after it only.
  The transcript shows the summary row as a "history compacted" marker
  (expandable). Auto-compact before sending at `ai.context.autoCompactAt`.

## UI

- `composer/ComposerStatus.qml`: `◆ engine · model` chip (opens picker),
  `EffortChip.qml` (level + popover with a segmented selector),
  `ContextMeter.qml` (thin bar + `62k/200k`, amber/red, tooltip, Compact).
- `composer/ContextNotice.qml`: notice above the strip at >= warn with a
  Compact button (HTTP) or "the agent compacts itself" (agents).
- `header/ModelPicker.qml` redesign: rows from pure `PickerModel.js`
  (recent, groups by provider, unconnected providers with Connect),
  `ModelPickerRow.qml`, `CapabilityBadges.qml`, refresh button,
  `connectRequested(provider)` signal (-> `Ai.openProviderSettings()` until
  C's sheet exists).
- Settings: "Model & effort" and "Context window" sections in
  `schema/ai.js`; agents editor effort becomes a selector of the catalog's
  levels.

## Config

`ai.effort.default`, `ai.strip.effort`, `ai.context.{warnAt, criticalAt,
autoCompact, autoCompactAt, keepTurns, compactModel, overrides}`,
`ai.ollama.numCtx`, `ai.picker.{showCapabilities, groupByProvider,
showUnconnected, showRecent}`.

## Tests

- node: `ai-providers-effort.test.cjs` (request bodies per family, num_ctx,
  no tools for chat-only), `ai-compaction.test.cjs`, `ai-context-math.test.cjs`,
  `ai-model-info.test.cjs`, `ai-picker-model.test.cjs`.
- qmlharness: `ai-effort-context-ui.test.py` (strip, effort selector,
  picker badges/connect), updated `ai-model-catalog.test.py`.
- Go: codex/claude context usage parsing.

## Notes for later sub-projects

What exists now:

- **Catalog entries** (`services/ai/ModelCatalog.qml`) carry `info` (capability
  record, `ModelInfo.js`) plus `tools`/`images` derived from it. The table
  is `assets/ai/models.json` read through a FileView
  (`Quickshell.shellDir`). Ollama is listed through the backend
  `providers.ollama.probe` (`probeOllama(force)`, 15 s throttle; the picker
  calls it on open) and `catalog.ollama = {reachable, endpoint, error}`;
  the old KeyStore "ollama" opt-in + `/api/tags` path only runs when the
  backend call fails (old daemon). `openrouter` and `deepseek` are now in
  `Providers.PROVIDERS` and fetched with their keys (`OPENROUTER_API_KEY`,
  `DEEPSEEK_API_KEY`); LM Studio is not listed yet (C).
- **Effort**: `Ai.effort` (`EffortState.qml`): `levels`, `level` (`""` =
  auto, provider default), `autoHint` (agent default), `set(level)`,
  `levelFor(entry)`, `rememberedFor(agent, model)` (null = never chosen).
  Pure rules in `EffortPrefs.js`. `ai.effort.defaultLevel` (`auto` by
  default: no thinking is switched on behind the user's back).
  `Ai.requestOptions(entry)` gives `{effort, numCtx}` for any HTTP request
  (chat, quick ask, prompts).
- **Requests**: `Providers.body(messages, model, tools, {system, effort,
  numCtx})` applies `Effort.apply` with `ProviderPresets.effortFamily`;
  tools are dropped when `model.tools === false` or `info.tools === false`.
  Anthropic thinking signatures are parsed (`acc.signature`), stored on the
  assistant row (`signature`) and sent back in tool loops (required with
  extended thinking). Anthropic usage `inputTokens` now includes cache
  reads/writes and has `cachedTokens` (D can report it as is).
- **Usage per turn**: `ChatSession.lastUsage` `{inputTokens, outputTokens,
  cachedTokens?}` and `contextTokens` (persisted in the chat file). D can
  hook `ChatSession` turn ends there. Agents: `done` events carry
  `usage.contextTokens` / `usage.contextWindow` (Go `Usage`), the
  timeline keeps the last one in `state.usage`; new
  `AgentSessions.peekTimeline(id)` reads it without opening a session.
- **Context**: `Ai.contextState` (`ContextState.qml`): `used`, `window`,
  `source` (`table|override|ollama|agent`), `fraction`, `level`
  (`ok|warn|critical`), `canCompact`, `compacting`, `compact(session, cb)`,
  `needsAutoCompact(session)`. Pure math in `ContextMath.js`
  (`short()`/`label()` for "62k/200k"). `Ai.busy` is true while compacting.
- **Compaction**: rows with `role: "summary"` stand in for every row before
  them in requests (`ChatRows.toMessages`); `Transcript.js` renders them as
  kind `compacted` (`transcript/CompactedMarker.qml`). `Compaction.js`
  holds the plan/prompt; `ChatCompactor.qml` runs it.
- **Picker**: `header/ModelPicker.qml` emits `connectRequested(providerId)`
  ("" = the generic "Connect provider" footer). `AiCenterPanel` forwards it
  to `Ai.openProviderSettings(provider)`, which now also emits
  `Ai.connectProviderRequested(provider)`: **C** should open its inline
  sheet from that signal instead of the settings window. Rows come from
  the pure `PickerModel.js` (groups `recent|agent|<provider>|unconnected`);
  "not connected" = a preset with no listed model and no key/endpoint.
- **Strip**: `ComposerStatus` gained `contextSource`, `canCompact`,
  `compacting`, `compactRequested`; the effort chip is `EffortChip.qml`
  (hidden by `ai.strip.effort`), the meter `ContextMeter.qml`, and
  `ContextNotice.qml` sits above the strip. D's cost/limit slots are
  unchanged.

Gotchas: `default` cannot be a config key (it becomes a QML property name);
Popup children are not in the visual item tree of the scene (tests use
`findChild` for the popup itself); provider icons are not copied into the
`aiscene` test tree (ignore their load errors).

Decisions:

- "auto" effort sends nothing instead of `Effort.defaultLevel()`, so
  Anthropic chats do not silently start paying for thinking tokens.
- Agents keep their native effort values (Codex `xhigh`, …) from their
  catalog instead of being squeezed into the five unified levels; their
  memory key is `agent:<id>/<native model or default>`.
- Context of a Claude turn = last main-thread assistant message's
  `input + cache_read + cache_creation + output`; window = the
  `modelUsage` entry that processed the most prompt tokens (helpers such
  as Haiku titling also appear there). Codex: `last.totalTokens` and
  `modelContextWindow` (verified against `codex app-server
  generate-json-schema`; Claude fields verified with one `claude -p` call).
- Ollama under-reports prompt tokens when its KV cache is reused, so its
  context is `max(reported, ~chars/4 estimate)`.

## Manual test

1. Open the AI bar with an Anthropic model: the strip shows
   `◆ Anthropic · Claude Sonnet 4.5 ▾  Auto ▾`. Click `Auto ▾`: a segmented
   selector (Auto, Off, Low, Medium, High, Max). Pick High and send a
   question: thinking appears. Switch to another model and back: High is
   still selected. Settings -> AI -> "models and effort" -> default level.
2. Pick a model without reasoning (e.g. gpt-4o): the effort chip disappears.
3. Codex/Claude Code: the chip lists the CLI's levels (e.g. xhigh); after a
   turn the strip shows the context bar `12k/258k`, its tooltip explains
   that the agent compacts itself.
4. Ctrl+K: recent models on top, groups per provider, badges (tools, eye,
   brain, `200k`, "chat only" for Ollama models without tools), refresh
   button, providers without a key as `OpenAI — not connected [Connect]`
   (opens Settings -> AI for now), search filters by name/provider.
   With Ollama running, models appear without any keystore entry
   (`ollama ps` stays empty after opening the picker).
5. Long HTTP chat (or set Settings -> AI -> context overrides
   `openai:gpt-4o` = 4096): the meter turns amber at 80 %, a notice with
   Compact appears; Compact inserts "History compacted" (click to read the
   summary); the meter drops. At 95 % sending compacts first (toggle in
   settings). Stop during compaction cancels the send.
6. Ollama chat: `num_ctx` defaults to 32768 (Settings -> AI -> Ollama
   context length; 0 = model maximum) and the window shows `32k`.
