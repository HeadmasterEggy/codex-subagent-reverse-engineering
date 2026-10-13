# Subagent flow: local binary and matching public source

Checked on 2026-10-13. This report distinguishes direct local observations from source-derived behavior and inference.

## Target identity

| Field | Observation |
| --- | --- |
| Product | ChatGPT macOS app, embedded Codex CLI |
| CLI version output | `codex-cli 0.162.0-alpha.17.2` |
| Mach-O architecture | arm64 |
| Mach-O UUID | `2CE1483B-FF35-344F-9958-9D48FFE5D5ED` |
| SHA-256 | `0d5ac7aae20c4eda6242428d5e218c55ba96d8763fda2a271088ff37104b9d28` |
| Matching source tag | `rust-v0.162.0-alpha.17.2` |
| Peeled source commit | `740e5af33c71225640e0c1c1555c514c2c93ab74` |

The version match is direct evidence. It is not proof that the installed executable was built from the peeled commit: no signed build manifest or embedded source revision was established in this investigation.

## Finding ledger

| Question | Result | Evidence and boundary |
| --- | --- | --- |
| Is spawn a separate CLI process? | The inspected source path uses shared `AgentControl` to create a child thread. | The V2 handler calls `agent_control.spawn(SpawnRequest { ... })`; the controller calls `spawn_new_thread_with_source` or the forked-thread path. This source call path does not establish every platform/runtime mode. |
| What gives a child its identity? | A child thread ID plus `ThreadSpawn` source metadata and agent path. | Source: [`spawn.rs` handler](https://github.com/openai/codex/blob/740e5af33c71225640e0c1c1555c514c2c93ab74/codex-rs/core/src/tools/handlers/multi_agents_v2/spawn.rs), [`control/spawn.rs`](https://github.com/openai/codex/blob/740e5af33c71225640e0c1c1555c514c2c93ab74/codex-rs/core/src/agent/control/spawn.rs). |
| When does the child receive its first input? | After the parent-child spawn edge has been persisted and awaited. | In `spawn_agent_internal`, edge persistence is scheduled and `pending_spawn.wait_for_edge()` precedes `send_input` / inter-agent communication. Source: [`control/spawn.rs`](https://github.com/openai/codex/blob/740e5af33c71225640e0c1c1555c514c2c93ab74/codex-rs/core/src/agent/control/spawn.rs). |
| How does V2 completion reach the parent? | Session terminal events are converted to an `AgentTurnOutcome`; `turn_finished` routes completion activity and a result message. | Source: [`session/mod.rs`](https://github.com/openai/codex/blob/740e5af33c71225640e0c1c1555c514c2c93ab74/codex-rs/core/src/session/mod.rs), [`completion.rs`](https://github.com/openai/codex/blob/740e5af33c71225640e0c1c1555c514c2c93ab74/codex-rs/core/src/agent/control/completion.rs). Queue acceptance is not proof the parent model consumed the result. |
| What does the completion watcher do? | It is the legacy notification route in this source snapshot. | Spawn starts `maybe_start_completion_watcher` only when the effective version is not V2. The watcher subscribes to child status, checks terminal status, then injects a legacy notification or sends a completion message for a V2 child encountered during legacy recovery. Source: [`control.rs`](https://github.com/openai/codex/blob/740e5af33c71225640e0c1c1555c514c2c93ab74/codex-rs/core/src/agent/control.rs), [`control/spawn.rs`](https://github.com/openai/codex/blob/740e5af33c71225640e0c1c1555c514c2c93ab74/codex-rs/core/src/agent/control/spawn.rs). |
| What can the local binary confirm? | It contains matching named spawn/wait handlers, controller methods, terminal-routing callsite metadata, V2 settings strings, and a disassemblable watcher entry point. | These are static observations. Names and strings alone do not prove runtime execution or exact source correspondence. |
| Which runtime settings were active? | Unknown. | Static strings contain settings names but do not establish resolved config, feature flags, or policy for this app session. |
| Was an actual child run observed? | No. | No agent was spawned, and no traffic/session trace was captured for this report. |

## Versioned source path

The public source tag exactly matches the CLI's reported version. In that snapshot:

1. The V2 tool handler builds a `ThreadSpawn` source and sends a `SpawnRequest` to `AgentControl`.
2. `spawn_agent_internal` selects the effective multi-agent version, admits the start, checks capacity, reserves registry/residency slots, and prepares inherited environment/execution policy and metadata.
3. The controller creates the child thread (or forked thread), records the spawn edge, waits for persistence, then submits the first input.
4. On `TurnComplete` or `TurnAborted`, a V2 session constructs an `AgentTurnOutcome` and calls `turn_finished`.
5. Completion routing may emit a `Completed` activity to the initiating thread and queues an inter-agent result communication with `trigger_turn = false`.
6. The parent queue receiving a message and the parent model processing it are separate events.

The older watcher subscribes to child status until a terminal state and performs a final status lookup if the subscription ends without one. In the normal new-spawn path its caller is guarded by `multi_agent_version != V2`.

## Local static evidence

Curated symbol names found in the executable include:

- `LocalAgentControl::prepare_thread_spawn`
- `LocalAgentControl::maybe_start_completion_watcher`
- `AgentControl for LocalAgentControl::turn_finished`
- V2 `spawn` and `wait` handler `spec` / `handle` methods
- V2 `list_agents`, `send_message`, `followup_task`, and `interrupt_agent` handler paths
- legacy `spawn`, `wait`, `send_input`, and `close_agent` handler paths
- callsite metadata associated with `notify_parent_of_terminal_turn`

The arm64 disassembly of `maybe_start_completion_watcher` includes a call to `LocalAgentRuntime::admit_start` and closure/future construction. This confirms local implementation structure around the watcher entry point. Optimized Rust async code is not a direct source-level reconstruction; the exact branch conditions and end-to-end runtime path are interpreted from the matching versioned source, not asserted from this disassembly alone.

The executable's embedded strings include `features.multi_agent_v2.max_concurrent_threads_per_session`, wait timeout keys and validation text, and `codex.multi_agent.result_delivery`. Their presence does not disclose which values were active.

## Reproduction and limits

Run `scripts/collect-macos-evidence.sh` to re-check the installed artifact identity and selected static symbol/string names. The report intentionally omits full disassembly and the app bundle. It makes no claim about server-side routing, remote executors, UI service internals, token cost, or actual completion timing.

