# claude-usage/

Real-time Claude Code quota pill — waybar always-on monitor + on-demand TUI, with persistence sinks for forecasting (Batch D) and token optimization metrics (Batch E).

## Layout

```
claude-usage/
├── pill.sh           # waybar pill entrypoint + --tui mode (was waybar/scripts/claude-usage.sh)
├── lib/              # reusable shell fragments (forecast helpers, etc. — empty in D0)
├── forecast.py       # historical calibration + per-model forecast (D3/D4) — pending
├── scan-sessions.py  # daily JSONL scan → sessions.jsonl sink (D2) — pending
└── README.md         # this file
```

Runtime state (volatile, `/tmp/`):
- `claude-usage-api-cache.json` — OAuth `/api/oauth/usage` response cache (TTL 300s)
- `claude-usage-api-fail.lock` — fail-lock to avoid 429 storms
- `claude-usage-trail.tsv` — sliding-window utilization trail (REC forecast)
- `claude-usage-cache.json` — ccusage fallback cache

Longitudinal state (persistent, `~/.local/share/claude-usage/`, **Batch D**):
- `api-snapshots-YYYY-MM.jsonl` — per-poll API snapshots (D1)
- `sessions-YYYY-MM.jsonl` — per-session per-model aggregates (D2)

## Hub

[notes/areas/claude/realtime-usage/realtime-usage.md](../../../../notes/areas/claude/realtime-usage/realtime-usage.md) — decisions, status table, batch plan.

## Invocation

| Surface | Path |
|---|---|
| Waybar module | `waybar/modules/custom-claude.jsonc` → `exec: .../claude-usage/pill.sh` |
| Keybind `Super+Shift+U` | `hypr/keybindings.conf` → `kitty -e watch -n 5 .../claude-usage/pill.sh --tui` |
| Manual debug | `~/life/2-areas/dev-tools/hyprdots/waybar/scripts/claude-usage/pill.sh` |
| Manual TUI | `~/life/2-areas/dev-tools/hyprdots/waybar/scripts/claude-usage/pill.sh --tui` |

## Batch history

- **Batch A–C** (2026-05-08 → 2026-05-10): engine discovery, API endpoint, T3-lite forecast, idle-fallback UX
- **Pós-C polish** (2026-05-10/11): tooltip simplification, REC sliding-window, idle tier
- **D0** (2026-05-14): folder refactor, this README — single mechanical commit before D1+
- **D1–D6**: API/session sinks, historical calibration, per-model forecast, UX surfaces, weekly validation
- **E1–E7**: token optimization (CLAUDE.md, MEMORY.md, MCP, hooks, cache hit-rate, recurring loop)
- **F**: runaway detection (post-D2)
