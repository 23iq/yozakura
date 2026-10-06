# C. Providers: plan

Spec: `docs/superpowers/specs/2026-10-06-ai-bar-redesign-design.md` (section C).
Builds on C1 (backend `providers.test`, `providers.ollama.probe`,
`ProviderPresets.js`, `assets/ai/models.json`) and B (picker Connect rows,
`Ai.connectProviderRequested(provider)`).

## Data flow

- **Connection state** (pure `services/ai/ProviderConnect.js`): keyed
  providers are connected when the KeyStore has their key; Custom when it has
  an endpoint; Ollama and LM Studio when their last probe was reachable (no
  fake key). Hidden providers (`ai.providers.hidden`) are neither listed nor
  probed and never shown as "not connected".
- **`services/ai/ProviderSetup.qml`** (`Ai.providers`, owned by the facade):
  `status(id)`, `test(id, key, url, cb)` (`providers.test`; Ollama uses
  `providers.ollama.probe` to show capabilities), `save(...)` (KeyStore for
  keys/custom endpoint + curl template, `ai.ollama.endpoint` /
  `ai.lmstudio.endpoint` for local providers), `disconnect(id)` (delete the
  key; local providers are hidden instead), and the quiet migration of the
  old `ollama: enabled` KeyStore entry (endpoint -> `ai.ollama.endpoint`,
  entry deleted).
- **Catalog**: LM Studio is listed from `<endpoint>/models` (no key; its
  reachability = the listing succeeded). Local providers are re-probed when
  the picker opens (throttle) and every `ai.providers.probeInterval` s while
  the AI bar is visible (0 = only on demand).
- **Requests**: `ChatRequest` applies `ai.providers.timeout` (curl
  `--max-time`), `ai.providers.retries` (only when nothing was streamed and
  the failure is a connection error / 429 / 5xx; pure `RequestPolicy.js`),
  custom headers for Custom (`ai.providers.customHeaders`), OpenRouter
  attribution headers (`ai.providers.openrouterAttribution`) and Ollama
  `keep_alive` (`ai.ollama.keepAlive`).

## UI (`modules/aicenter/providers/`)

- `ConnectSheet.qml`: two steps (provider grid -> form), inline in the AI
  bar (overlay) or embedded (settings page, onboarding).
- `ProviderGrid.qml` + `ProviderTile.qml`: icons, labels, Local badge,
  connected/running state.
- `ProviderForm.qml`: key (`SecretField.qml`: paste, show/hide), Get a key
  link, base URL, curl template (Custom), Test (`TestStatus.qml`: spinner,
  model count, error), local models with capability badges
  (`ProbeModels.qml`), Save, Disconnect.
- Opened from: picker footer / not-connected rows, `Ai.connectProviderRequested`,
  the Assistant "Connect a model" CTA, onboarding.

## Settings

New category `ai-providers` (`schema/aiproviders.js`, group Extend):
connections (editor `AiProvidersEditor` = the same `ConnectSheet`),
default model (`AiDefaultModel` editor), picker visibility per provider
(`AiProviderVisibility`), requests (timeout, retries), Custom headers,
OpenRouter attribution, Ollama (endpoint, keep-alive, num_ctx moved here),
LM Studio endpoint, auto-probe interval. `widgets/config/AiPanel.qml` and its
legacy registration are deleted.

## Tests

- node: `ai-provider-connect.test.cjs` (status, migration plan, validation,
  test params, summaries, headers, request policy, Providers.js LM Studio /
  DeepSeek / OpenRouter URLs, listings, keep_alive), `onboarding.test.cjs`
  (`ollamaState`).
- qmlharness: `ai-connect-sheet.test.py` (grid -> form -> Test -> Save,
  errors, Ollama probe models, Disconnect, Custom endpoint + curl, hidden
  providers, picker/CTA open the sheet, legacy Ollama entry migration)
  replacing `ai-panel.test.py`; `ai-providers-settings.test.py` (settings
  page); updated `ai-model-catalog`, `ai-spaces`, `onboarding-ui`.
- Go: `providers.test` extra headers.

## Notes for later sub-projects

What exists now:

- **`Ai.providers`** (`services/ai/ProviderSetup.qml`, created with the
  facade): `status(id)` -> `{state: connected|offline|none|hidden,
  connected, local}`, `unconnected` (picker rows), `anyConnected`,
  `current(id)` -> `{key, url, curl}`, `test(id, key, url, cb)`,
  `save(id, key, url, curl)`, `disconnect(id)`, `setHidden(id, hide)`,
  `migrate()`. Pure rules: `ProviderConnect.js` (`status`, `unconnected`,
  `validate`, `testCall`, `summarize`, `savePlan`, `legacyOllama`,
  `extraHeaders(id, cfg, {url, name})`, `headerMap`).
- **Connect sheet** (`modules/aicenter/providers/ConnectSheet.qml`):
  `open(provider)` ("" = grid), `embedded` (settings page, no close), signals
  `closeRequested`, `connected(provider)`. The AI bar opens it on
  `Ai.connectProviderRequested`; `Ai.openProviderSettings(provider)` emits
  that while the bar is visible and opens Settings → AI providers otherwise.
  Building blocks: `ProviderGrid`, `ProviderTile`, `ProviderForm`,
  `FormField` (paste, show/hide), `TestStatus`, `ProbeModels`,
  `ProviderIcon` (logos tinted with theme colours).
- **Catalog**: LM Studio is listed (`catalog.lmstudio = {reachable, endpoint,
  error}`); `probeLocal(force)` probes Ollama + LM Studio; hidden providers are
  skipped; keyed providers use a stored KeyStore endpoint when there is one;
  OpenRouter listings carry capability hints (`hint`: context, tools, vision)
  used when models.json does not know a model.
- **Requests** (`ChatRequest`): `ai.providers.timeout` (curl `--max-time`),
  `ai.providers.retries` (`RequestPolicy.js`: only before anything streamed,
  only transient errors), extra headers, Ollama `keep_alive`.
- **Backend**: `providers.test` accepts `headers` (custom endpoint auth;
  scrubbed from errors); `keystore.set` accepts a key-less entry with an
  endpoint (Custom without auth).
- **Settings**: category `ai-providers` (`schema/aiproviders.js`); editors
  `AiProvidersEditor`, `AiDefaultModel`, `AiProviderVisibility`.
  `ai.defaultModel` and `ai.ollama.numCtx` moved there; the AI page links to it.
- **Onboarding**: the AI step probes Ollama (`wizard.ollama` = running /
  installed / missing, `OnboardingModel.ollamaState`) and offers "Connect a
  provider" (the sheet, loaded by URL over the step). `ChoiceRow` has a
  `link` mode.
- **Tests**: `tests/lib/aiscene.py` now has a stateful KeyStore, a scriptable
  BackendService (`responses[method]`), a SettingsStore stub writing the scene
  Config, copies the provider icons and deletes its temp tree at exit
  (`AISCENE_KEEP=1` keeps it). The settings env mirrors the provider
  components and stubs `Ai.providers`.

Decisions:

- Ollama/LM Studio "connected" = reachable; "Disconnect" for a local server
  hides it from the picker (`ai.providers.hidden`), "Use this server" stores
  its endpoint and shows it again. The old `ollama: enabled` KeyStore entry is
  deleted on the first key load; its endpoint moves to `ai.ollama.endpoint`
  unless one is configured.
- Local endpoints are config keys (not secrets, editable in settings/CLI);
  keys and the Custom endpoint/curl template stay in the KeyStore.
- The sheet tests a form only when asked (Test), except local servers, which
  are probed once when their form opens (no generation, no model loaded).
- Retries never repeat a request that already streamed text, so no answer is
  duplicated or billed twice for the visible part.

Gaps: no `yozakura providers` CLI/MCP surface yet; per-provider custom
headers exist only for Custom; LM Studio capabilities come from models.json
only (its listing has none).

## Manual test

1. Open the AI bar, Ctrl+K: footer "Connect provider" opens the sheet inside
   the bar (grid: Cloud / On your machine; Ollama shows "Running" when it
   runs). Esc goes back, Esc again closes.
2. Pick OpenAI: "Get a key" opens the key page; paste a key with the paste
   button, toggle the eye; Test shows a spinner, then "It works · N models"
   (or "Could not connect: HTTP 401 …" with a wrong key). Save: the sheet
   closes and OpenAI models appear in the picker. Open OpenAI again:
   Disconnect removes them.
3. Pick Ollama: no key field; it probes at once and lists the local models
   with badges (tools, eye, brain, context; "chat only" without tools).
   `ollama ps` stays empty. Change the URL to a wrong port + Test ->
   "connection refused". "Hide from the picker" hides Ollama; "Use this
   server" shows it again.
4. Start LM Studio's server: within a minute (or on picker open) its models
   appear under LM Studio; stop it: the provider shows "not connected".
5. Custom: URL `http://host:port/v1`, optional key, Advanced → curl template;
   Save; Settings → AI providers → Custom endpoint headers adds e.g. a proxy
   token (Test sends it).
6. Remove every model: the Assistant's "Connect a model" opens the sheet.
7. Settings → AI providers: same sheet embedded, default model dropdown,
   per-provider picker switches, timeout/retries, OpenRouter attribution,
   Ollama address / keep-alive / context length, LM Studio address, probe
   interval. Settings → AI → "AI providers" links there.
8. Users with the old Ollama opt-in: after the update the KeyStore entry is
   gone (`yozakura ipc call keystore.list '{}'`) and Ollama still works.
9. Onboarding (`yozakura run onboarding`) → AI step: Ollama shows Running /
   Not running / Not found from the probe; "Connect a provider" opens the
   sheet over the step.
