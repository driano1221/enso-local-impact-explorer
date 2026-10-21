# AI evidence interpreter

DeepSeek `deepseek-flash` classifies a question about the selected place, measure and season. It returns a validated intent and evidence ID. R renders reviewed explanations and the same real values used by the dashboard. It cannot run tools, browse, change climate files or generate forecasts. Intent selection can still be wrong.

Flow: selection + question → source-checked facts → JSON intent → validation → R-rendered explanation and source links. For Belo Horizonte, SON 2025, POWER is 22.28 °C against its 21.36 °C baseline; ERA5 is 21.21 °C against 21.29 °C. Neither difference proves an El Niño effect.

Thirty bounded real cases (15 PT/15 EN, including 18 held out) passed on 20 October 2026. They cover one climate context and do not establish general reliability. Fake-transport tests verify software, not model accuracy.

## Operation and privacy

The question and public climate context are sent to DeepSeek only after pressing Consult evidence. Never enter personal information. No browser API key, conversation history or automatic calls on page opening. Five-second session cooldown, three concurrent jobs per R process, 30 new jobs/minute/process, 500-character input, 400 output tokens, 35-second provider timeout. R children keep Shiny responsive; changing selection cancels/discards stale replies. Failures preserve the ordinary dashboard.

An in-memory cache (200 entries/process) separates question, facts, language and prompt version. It resets on restart and is not an accounting ledger. Operational logs contain only timestamp, model and token counts; they omit questions, answers and credentials. Provider terms apply to sent data.

The owner authorized the available prepaid balance through **8 November 2026, Brasília**, without an application dollar cap. New calls stop at 9 November 03:00 UTC. Previously cached explanations may remain; depleted balance or provider limits show a fallback. Limits are per R process, not a global billing guarantee. No credit-card or automatic top-up configuration is changed.

## Configure another server

Without a key the climate dashboard runs normally and the interpreter reports unavailable. Set `ENSO_PRIVATE_CONFIG` to a server-only JSON path, or supply `.enso-runtime.json` at the app root (never under www):

```json
{"api_key":"YOUR_PRIVATE_KEY","expires":1794193200}
```

Exclude that file from Git, public archives, integrity manifests and browser resources. Use hosting secrets when available. The owner's private deployment uploads it separately from the public package. The public manifest attests listed code/data, not credentials, live answers or continued host operation.

Run `Rscript ia/testar_local.R` and `Rscript ia/testar_servidor.R` without a key or API charges. `worker.R` is production; `testes/worker_fake.R` is test-only and never selected by a browser parameter.
