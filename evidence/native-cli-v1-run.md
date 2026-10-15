# Standalone CLI V1 spawn and wait event trace (2026-10-16)

## Setup

- Binary: `/Users/joey/.local/bin/codex`, version `0.162.1`.
- Feature inventory from `codex features list`: `multi_agent` is stable and enabled; `multi_agent_v2` is stable and disabled.
- Invocation mode: `codex exec --ephemeral --json --sandbox read-only --cd /Users/joey/codex-subagent-lab --enable multi_agent`.
- Task: ask the root agent to spawn exactly one child, inspect only `README.md`, wait for that child, then report a unique marker and its observation. No file writes were allowed.
- Captured stdout JSONL: `/tmp/codex-v1-subagent-probe-2026-10-16.jsonl`.
- SHA-256: `648970fdb713270a42dc6cd6e9c1040f4a3a7d6218e20c5a5704bbed60914a33`.

## Observed event order

The JSONL contains the following relevant records in order; thread IDs are replaced here with stable placeholders.

1. `thread.started` and `turn.started` for the root.
2. Root `agent_message`: it will identify the capability, spawn exactly one child, and wait.
3. `item.started`: `collab_tool_call`, tool `spawn_agent`, status `in_progress`.
4. `item.completed`: same tool, status `completed`, one receiver (`child-A`); `agents_states.child-A = { status: "pending_init", message: null }`.
5. `item.started`: `collab_tool_call`, tool `wait`, targeting `child-A`, status `in_progress`.
6. `item.completed`: tool `wait`, status `completed`; `agents_states.child-A = { status: "completed", message: "CHILD_MARKER=violet-cedar-104 README.md says the prototype uses Node built-ins and needs no package installation." }`.
7. Root `agent_message` reports the same marker and observation, then `turn.completed`.

## Interpretation and limits

**Observation:** in this run, the completed `spawn_agent` call returned while the child state was still `pending_init`; the later `wait` completion carried `completed` and the child message; the root's final message followed. This is direct evidence about the serialized event sequence and state fields emitted by standalone CLI 0.162.1 under the recorded feature settings.

**Inference:** `spawn_agent` completion is an acceptance/creation receipt in this trace, not a join on child completion; `wait` is a later coordination step that returns the child result.

**Unknown:** this does not expose the child's internal transcript, establish internal scheduling details, or show that ChatGPT Desktop uses the same runtime path. It is not a V2 run. The CLI emitted environment warnings about an unrelated unavailable MCP server and a WebSocket-to-HTTP fallback; the task still completed and emitted the records above. No files in the lab workspace were changed by the run.

## Reproduction shape

Run the pinned standalone CLI with `--ephemeral --json --sandbox read-only`, enable only `multi_agent`, constrain the child to read `README.md`, and capture stdout JSONL. Feature defaults are version-sensitive; verify `codex features list` for the same binary before classifying another run as V1.
