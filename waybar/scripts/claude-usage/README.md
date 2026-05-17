# claude-usage/

Real-time Claude Code quota pill — waybar always-on monitor + on-demand TUI, with persistence sinks for forecasting (Batch D) and token optimization metrics (Batch E).

## Layout

```
claude-usage/
├── pill.sh           # waybar pill entrypoint + --tui mode (was waybar/scripts/claude-usage.sh)
├── lib/              # reusable shell fragments (forecast helpers, etc. — empty in D0)
├── forecast.py       # historical calibration + per-model forecast (D3/D4) — pending
├── scan-sessions.py  # daily JSONL scan → sessions.jsonl sink (D2)
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

## scan-sessions.py (D2)

Daily systemd timer (03:00) walks every `~/.claude/projects/**/*.jsonl` (CC CLI + Claudian + autonomous Docker runs all land here — Claudian uses Agent SDK with the host `~/.claude`), dedups `message.id` cross-file, and writes one aggregate per `(session_id, model, day)` to `~/.local/share/claude-usage/sessions-YYYY-MM.jsonl`.

### Output line schema

```json
{
  "day": "2026-05-14",
  "session_id": "1d0287c5-...",
  "project": "life/notes",
  "model": "claude-opus-4-7",
  "turns": 47,
  "input_tokens": 521000,
  "output_tokens": 38000,
  "cache_creation_tokens": 89000,
  "cache_read_tokens": 1240000,
  "peak_ctx_turn": 192000,
  "first_ts": "2026-05-14T08:12:33Z",
  "last_ts":  "2026-05-14T14:55:01Z"
}
```

`peak_ctx_turn` = max of `(input + cache_creation + cache_read)` over assistant turns — the metric that triggers tier-1M pricing at ~200K and motivates Batch F (runaway detection).

### Manual invocation

```bash
# Preview last 7 days without writing
~/life/2-areas/dev-tools/hyprdots/waybar/scripts/claude-usage/scan-sessions.py --dry-run --verbose

# Force a backfill from a specific date
~/life/2-areas/dev-tools/hyprdots/waybar/scripts/claude-usage/scan-sessions.py --since 2026-05-10 --verbose

# Trigger via systemd (matches what the timer does at 03:00)
systemctl --user start claude-usage-scan-sessions.service
```

Idempotent: second run is a no-op (existing `(session_id, model, day)` keys are skipped). Append-only — historical lines are never rewritten; a session that spans midnight UTC produces two lines.

### Rotation

At the top of every run: closed-month files (`sessions-YYYY-MM.jsonl` whose month ≠ today) are gzipped in-place; `sessions-YYYY-MM.jsonl.gz` older than **90 days** are deleted. Simulate with `--simulate-date YYYY-MM-DD`.

### Systemd units

- `~/.config/systemd/user/claude-usage-scan-sessions.service` (oneshot)
- `~/.config/systemd/user/claude-usage-scan-sessions.timer` (`OnCalendar=*-*-* 03:00:00`, `Persistent=true`)

Both are symlinks to `hyprdots/.config/systemd/user/`. Check next firing with `systemctl --user list-timers | grep scan-sessions`.

### Troubleshooting

- **Service exits but no new lines** — backfill window may be empty. Run with `--since 2026-05-01 --verbose` and check stderr for "scanned N JSONLs".
- **`peak_ctx_turn` looks wrong** — check the raw JSONL: peak is per-turn, not session total. Verify with `grep '"type":"assistant"' <session.jsonl> | jq '.message.usage | (.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens)' | sort -rn | head -1`.
- **Missing Claudian session** — they land in `~/.claude/projects/-home-warley-life-notes/<sessionId>.jsonl` (same dir as VSCode CC sessions with `cwd=~/life/notes`). The vault `.claudian/sessions/*.meta.json` is only a thumbnail; the JSONL is the source of truth.

## Batch history

- **Batch A–C** (2026-05-08 → 2026-05-10): engine discovery, API endpoint, T3-lite forecast, idle-fallback UX
- **Pós-C polish** (2026-05-10/11): tooltip simplification, REC sliding-window, idle tier
- **D0** (2026-05-14): folder refactor, this README — single mechanical commit before D1+
- **D1–D6**: API/session sinks, historical calibration, per-model forecast, UX surfaces, weekly validation
- **E1–E7**: token optimization (CLAUDE.md, MEMORY.md, MCP, hooks, cache hit-rate, recurring loop)
- **F**: runaway detection (post-D2)
