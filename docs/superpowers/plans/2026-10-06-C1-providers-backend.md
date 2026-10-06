# C1: providers backend, capability table, effort mapping, presets

Part of the AI bar redesign (spec sections B and C). Backend + pure JS only;
nothing is wired into QML yet (that is for the B/C QML workers).

## Files

| File | What |
|------|------|
| `backend/pkg/svc/providers/service.go` | IPC service `providers` (registered in `pkg/daemon/daemon.go`) |
| `backend/pkg/svc/providers/ollama.go` | Ollama probe (`/api/version`, `/api/tags`, `/api/show`) |
| `backend/pkg/svc/providers/cache.go` | on-disk capability cache |
| `backend/pkg/svc/providers/listing.go` | connection test (model listings) |
| `backend/pkg/svc/providers/models.go` | `assets/ai/models.json` lookup |
| `assets/ai/models.json` | bundled model capability table |
| `modules/services/ai/Effort.js` | unified effort level -> request params |
| `modules/services/ai/ProviderPresets.js` | provider presets for the Connect sheet |
| `tests/ai-effort.test.cjs`, `tests/ai-provider-presets.test.cjs`, `backend/pkg/svc/providers/*_test.go` | tests (httptest, no live calls) |

`Effort.js` / `ProviderPresets.js` are allowlisted as "dead" in
`tools/audit/config.json` (`deadCode.ignore`) until they are imported;
**remove those two entries when wiring them**.

## IPC API (service `providers`)

All methods return a result object (never an IPC error for provider
failures). `ollama.probe` and `test` are async (do not block the socket).

### `providers.ollama.probe {endpoint?}`

`endpoint` defaults to `http://127.0.0.1:11434`; a trailing `/`, `/v1` or
`/api` is stripped, a missing scheme becomes `http://`. Calls `/api/tags`
(5 s timeout), `/api/version`, and `POST /api/show` **only for models whose
digest is not cached**. Never calls `/api/generate` or `/api/chat`, so no
model is loaded (GPU-safe; cheap enough to re-probe every time the picker
opens).

```json
{ "endpoint": "http://127.0.0.1:11434", "reachable": true, "version": "0.35.0",
  "error": "",            // only when unreachable / bad endpoint, e.g. "connection refused"
  "models": [ {
    "id": "qwen3.5:9b", "name": "qwen3.5:9b",
    "sizeLabel": "9.7B",              // parameter size from details
    "diskSize": 6594474711,           // bytes
    "family": "qwen35",
    "contextLength": 262144,          // model_info["<arch>.context_length"]; 0 = unknown
    "capabilities": ["completion","tools","vision","thinking"],  // subset of completion|tools|vision|thinking|insert|embedding, canonical order
    "quantization": "Q4_K_M",
    "digest": "6488…",
    "detailed": true                  // false: /api/show failed, caps/context unknown (retried next probe)
  } ] }
```

Models are sorted by id. A model without `tools` should be "chat only" in
the Assistant. `contextLength` is the model maximum; the chat still has to
send `options.num_ctx` (Ollama's default context is much smaller).

### `providers.test {provider, baseUrl?, key?}`

Connection test for the Connect sheet. Only free GET listings, never a
prompt. The key is sent in headers only, never logged, and scrubbed from
error texts. `baseUrl` empty = preset base.

```json
{ "ok": true, "verified": true, "error": "", "models": [ {"id": "gpt-5", "name": "gpt-5"} ] }
```

| provider | request |
|----------|---------|
| openai, mistral, groq, deepseek, lmstudio, custom (and unknown ids) | `GET <base>/models`, `Authorization: Bearer` when a key is given |
| anthropic | `GET <base>/v1/models` (`/v1` added if missing), `x-api-key`, `anthropic-version` |
| gemini | `GET <base>/models?pageSize=1000`, `x-goog-api-key` (never `?key=`) |
| openrouter | `GET <base>/key` (checks the key; `/models` is public) then `GET <base>/models` |
| ollama | same as `ollama.probe` on `baseUrl` |
| minimax | no listing endpoint: `{ok: key != "", verified: false}`; the key is only checked by the first chat |

`error` examples: `"HTTP 401: Incorrect API key provided: ***"`,
`"connection refused"`, `"timed out"`, `"base URL required"`, `"invalid base URL"`.
Model lists are sorted by id and unfiltered (Providers.js `parseModelList`
filters embeddings etc. for the picker; do the same if needed).

### `providers.models.info {provider, model}`

No network. For `ollama`, the probe cache first (`source: "ollama"`), else
the table. Otherwise the table lookup below.

```json
{ "found": true, "provider": "openrouter", "model": "anthropic/claude-sonnet-4.5",
  "source": "table",                   // "table" | "ollama" | "" (not found)
  "prefix": "claude-sonnet-4", "contextWindow": 200000, "maxOutput": 64000,
  "vision": true, "tools": true, "reasoning": "anthropic_budget",
  "efforts": ["off","low","medium","high","max"], "budget": {"min": 1024},
  "effortMap": {...}, "note": "...",
  "capabilities": [...], "family": "..." }   // ollama source only
```

Ollama-sourced records use `reasoning: "ollama_think"` when the model has
the `thinking` capability (else `"none"`). Missing fields = unknown.

## File formats

### `assets/ai/models.json` (QML may read it directly as a plain JSON file)

```json
{ "updated": "2026-10-06",
  "efforts": ["off","low","medium","high","max"],
  "vendors": { "anthropic": "anthropic", "google": "gemini", "meta-llama": "open", ... },
  "providers": { "<provider id or 'open'>": [ {
      "prefix": "gpt-5", "contextWindow": 400000, "maxOutput": 128000,
      "vision": true, "tools": true,
      "reasoning": "openai_effort",     // openai_effort | anthropic_budget | gemini_budget | gemini_level | none
      "efforts": ["off","low","medium","high"],   // unified levels the model accepts
      "effortMap": { "off": "minimal" },          // provider value when != level name
      "budget": { "min": 128, "max": 32768 },     // budget styles only
      "note": "…" } ] } }
```

Lookup (Go `ModelTable.Lookup`; replicate in QML if you read the file
directly): id lower-cased, `:free` suffix dropped; tables tried in order
*provider*, *vendor of `vendor/model` ids* (via `vendors`), `open`; in each
table the full id first, then the id without `vendor/`; longest matching
`prefix` wins. Example: `openrouter` + `openai/gpt-oss-120b:free` -> `open`
table `gpt-oss`.

Coverage: OpenAI (gpt-4o, 4.1, 5, 5.x, codex, o-series), Anthropic (Claude
3.5 to 4.5 + a `claude-` fallback), Gemini 2.0/2.5/3, Mistral, Groq, DeepSeek,
MiniMax M2, open-weight models (gpt-oss, Llama 3/4, Kimi K2). Uncertain
values were omitted. Gemini 3 uses `gemini_level`
(`thinkingConfig.thinkingLevel` low/high), a fifth style beyond the spec's four,
because it replaces the budget there.

### `~/.cache/<app>/ollama-models.json`

```json
{ "version": 1, "entries": { "<endpoint>|<model id>": { ...OllamaModel... } } }
```

An entry is reused while its `digest` matches `/api/tags`; models gone from
an endpoint are pruned at the next probe; failed `/api/show` results are
not cached. Written atomically. Safe to delete.

## Effort.js (`.pragma library`)

`info` = a models.json entry, a `providers.models.info` result, or an Ollama
probe model. Family = `ProviderPresets.effortFamily(providerId)`:
`openai` (any OpenAI-compatible host), `anthropic`, `gemini`, `ollama`,
`openrouter`.

- `LEVELS` = `off|low|medium|high|max`; `normalize(level)`.
- `style(info)`, `levelsFor(info)` (`[]` = hide the control),
  `defaultLevel(info)` (medium, else high, else first),
  `resolve(level, info)` (closest supported level; unsupported `off` -> `""`
  = send nothing). Use `resolve` when restoring a per-model remembered level.
- `params(family, level, info)` -> fields to merge into the body:
  - openai: `{reasoning_effort}`; `off` -> `effortMap.off` (`minimal` for
    gpt-5, `none` for 5.1+) or omitted; `max` -> `xhigh` where mapped.
  - anthropic: `{thinking: {type: "enabled", budget_tokens}}` low 2048 /
    medium 8192 / high 16384 / max 32768, clamped to `maxOutput - 4096`; off -> `{}`.
  - gemini: `generationConfig.thinkingConfig.thinkingBudget` low 1024 /
    medium 8192 / high 16384 / max = `budget.max`, clamped to the range;
    off -> `thinkingBudget: 0` only where `budget.min == 0`;
    `includeThoughts: true` when thinking. Gemini 3: `thinkingLevel`.
  - ollama: `{think: true|false}`; gpt-oss `{think: "low"|"medium"|"high"}`
    (cannot be turned off; max -> high).
  - openrouter: `{reasoning: {effort}}` or `{reasoning: {max_tokens}}` for
    budget-style models; off -> `{}`.
- `apply(body, family, level, info)` -> a copy of `body` with `params`
  deep-merged (keeps existing `generationConfig` fields). Anthropic: raises
  `max_tokens` above the budget (capped at `maxOutput`, drops thinking if it
  cannot fit) and removes `temperature`/`top_k` (not allowed with thinking).

## ProviderPresets.js (`.pragma library`)

`PRESETS[]` of `{id, label, icon, baseUrl, keyRequired, keyUrl, keyId,
family, effortFamily?, local?, editableUrl?}` for openai, anthropic, gemini,
mistral, groq, minimax, openrouter, deepseek, lmstudio
(`http://127.0.0.1:1234/v1`), ollama, custom. Icons are files in
`assets/aiproviders/` (`custom` has `icon: ""`: use a glyph such as
`Icons.plug`). `keyId`s match `Providers.js` (new: `OPENROUTER_API_KEY`,
`DEEPSEEK_API_KEY`, `CUSTOM_API_KEY`). Functions: `ids()`, `preset(id)`
(null if unknown), `family(id)`, `effortFamily(id)`, `needsKey(id)`,
`sorted()` (remote by label, then local, then custom),
`isConnected(id, key, baseUrl)` (local presets return true; use the Ollama
probe's `reachable` for real state).

## Notes for later sub-projects

- `Providers.js` `PROVIDERS` has no `openrouter`/`deepseek`/`lmstudio` entries
  yet; adding them (family openai, bases from ProviderPresets) is part of
  wiring. OpenRouter needs `effortFamily: "openrouter"` for effort params.
- Groq/OpenRouter ids contain `/`; the table handles them via `vendors`.
- MiniMax cannot be verified for free; show "key saved, checked on first
  message" when `verified` is false.
- No CLI/MCP surface yet for `providers` (spec's "three ways" rule); add
  `yozakura providers ...` if needed.

## Manual test

1. `make build`, restart yozakura when convenient (the running daemon does
   not have the service yet), then
   `yozakura ipc call providers.ollama.probe '{}'` lists the local models
   with capabilities and `~/.cache/yozakura/ollama-models.json` appears. A
   second call does no `/api/show` and loads no model (`ollama ps` stays empty).
2. `yozakura ipc call providers.test '{"provider":"lmstudio"}'` with LM
   Studio closed -> `ok:false, error:"connection refused"`.
3. `yozakura ipc call providers.models.info '{"provider":"openrouter","model":"google/gemini-2.5-pro"}'`
   -> `contextWindow 1048576`, `reasoning gemini_budget`.
