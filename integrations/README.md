# Runtime integrations

Optional, **default-off** plumbing that lets an external agent runtime show which advisor is
currently working, which is blocked on the owner, and which is done — without the owner scrolling
back through a single Claude Code transcript.

Nothing here changes how the council works. If you never set `MAJLIS_BACKEND`, the hooks fire, the
entry point sees `noop`, and exits immediately.

## Enabling

```bash
export MAJLIS_BACKEND=herdr    # or: log
```

| Backend | What it does |
|---|---|
| `noop` *(default)* | Nothing. |
| `herdr` | Reports member state to the current [Herdr](https://herdr.dev) pane. |
| `log` | Appends JSONL to `Team's brain/jarvis/agent-events.jsonl`. Works with no runtime at all. |

Optional: `MAJLIS_ORCHESTRATOR` (default `jarvis`) names who holds the floor between dispatches.

## How it fits together

```
Claude Code hook  ──►  bin/majlis-report.sh  ──►  integrations/$MAJLIS_BACKEND.sh
  (settings.json)        maps event → verb            speaks to the runtime
```

`bin/majlis-report.sh` reads the hook JSON on stdin and maps Claude Code events onto a small
neutral vocabulary. Adapters are **invoked, never sourced**, so an adapter may be written in any
language and can never corrupt the entry point.

## The contract — four verbs

An adapter is an executable taking `<verb> <handle> [extra]`:

| Verb | Fired on | `handle` is |
|---|---|---|
| `member_start <handle> <agent_id>` | `SubagentStart` | the advisor taking the floor |
| `member_stop <handle> <agent_id>` | `SubagentStop` | whoever holds the floor *after* the return |
| `member_blocked <handle> <message>` | `Notification` | the current floor-holder |
| `member_release <handle>` | `Stop` | the orchestrator |

`handle` is the member's `subagent_type` — the same identifier `team/roster.md` already lists and
Jarvis already dispatches with. No second registry.

To add a runtime, drop in `integrations/<name>.sh`, handle the four verbs, and guard for "this
runtime isn't present" inside that file. Adapter-specific knowledge stays in the adapter.

## Three rules that are load-bearing

1. **Always exit 0.** A reporting failure must never break a dispatch.
2. **Default to `noop`.** Someone who has never heard of Herdr must be unaffected.
3. **No network, never block.** Hooks run on every dispatch.

## Known behaviours worth understanding

- **One pane, one state.** Majlis members are Claude Code subagents dispatched with the `Agent`
  tool: they run *in-process* and never occupy their own pane. Herdr detects agents per pane, so it
  sees one Claude Code process, not seven advisors. This layer annotates that one pane rather than
  fighting it. Herdr's `report-agent` is built for exactly this — state "not visible in the native
  terminal UI".
- **Parallel dispatch resolves to the most recent advisor.** Jarvis can run several members at once,
  but the runtime shows one state. The entry point keeps a marker file per live subagent under
  `$TMPDIR/majlis-report/<session>/` and reports the newest still-running one, falling back to the
  orchestrator when the floor is free. Markers are cleared on `Stop`.
- **Blocked fires immediately.** This is the main advantage over screen-scraping: Herdr's own
  Claude Code detection classifies `blocked` strictly and lags a few seconds, while the
  `Notification` hook fires at once.
- **What you do not get:** one pane per advisor, several advisors visibly running side by side, or
  killing an individual advisor from the runtime. Those need a pane per member, which is
  deliberately out of scope — it would abandon the `Agent` tool, lose in-process return values and
  `SendMessage` continuity, and break the charter's requirement that Jarvis synthesizes member
  output.

## Testing

```bash
tests/majlis-report.test.sh
```

Drives the entry point with recorded hook payloads against the `log` adapter and asserts the
emitted verbs. No dependencies beyond bash.
