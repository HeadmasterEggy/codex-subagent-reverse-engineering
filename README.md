# Codex Subagent Reverse Engineering

Evidence-led notes on how Codex creates, coordinates, and reports subagents.

This repository contains a static-analysis report for the macOS Codex CLI embedded in ChatGPT and version-scoped comparisons with public Codex source tags. It does not include the Codex application or redistribute upstream source files.

## Current finding

The ChatGPT app embeds CLI `0.162.0-alpha.17.2`; its version-matched public source tag resolves to [`740e5af33c71225640e0c1c1555c514c2c93ab74`](https://github.com/openai/codex/tree/740e5af33c71225640e0c1c1555c514c2c93ab74). The separately installed standalone CLI reports `0.162.1` and is a different binary. The public `rust-v0.162.1` tag peels to [`092d3acd6bec3e3a14bdc7e7a2810ab628ab759d`](https://github.com/openai/codex/tree/092d3acd6bec3e3a14bdc7e7a2810ab628ab759d). Neither version match proves exact binary build provenance.

In that source snapshot, V2 spawn creates a child thread through shared `AgentControl`, persists the parent-child edge before submitting the initial input, and delivers terminal outcomes through the V2 session event path. The detached completion watcher is the legacy route. See [the evidence report](evidence/subagent-flow.md).

A read-only correlation of the local Codex Desktop session store found three V2 parent-child rollout pairs for embedded CLI `0.162.0-alpha.17.2`. In each recorded sequence, the child's `task_started` precedes the parent's `SubAgentActivity(Started)`; at completion, `task_complete` precedes `Completed`, followed by the matching parent `agent_message`. This is a scoped observation of locally retained rollout records, not evidence of a global desktop default or exact UI render timing. No identifiers or message contents are published; see [the desktop runtime evidence](evidence/subagent-flow.md#desktop-research-session-runtime-metadata).

Matching each parent's `wait_agent` call to its recorded output adds an important boundary: two outputs mapped to `MailboxActivity`, one timed out; the matching parent `agent_message` followed the wait output in all three, while child completion followed the timed-out output in that one pair. The rollout does not identify which mailbox notification woke either handler. This local sample does not make V2 `wait_agent` a child-join operation; see the detailed [wait timing evidence](evidence/subagent-flow.md#desktop-research-session-runtime-metadata).

The 0.162.1 source snapshot also exposes structured agent-tree shutdown reporting: teardown failures are classified by operation and phase, retained up to 64 per tree, and include abandoned cleanup guards. It also conditionally preserves forked `AdditionalTools` declarations together with their context-comparison baseline. These are contrasts between public source snapshots, not proof of a linear version transition or the introducing commit; this checkout was shallow when ancestry was checked. They are source evidence, not live observations from the ChatGPT desktop host.

## Reproduce local identity checks

On macOS with the same app installed:

```sh
./scripts/collect-macos-evidence.sh
```

The script reads the executable, prints its version, SHA-256, Mach-O UUID, and selected symbol/string matches. It does not start an agent session or modify the app. Pass an executable path as the first argument to inspect a different installation.

## Evidence boundaries

- Static symbols and strings establish that named code/data is present, not that a particular runtime path executed.
- Disassembly is interpreted narrowly and cross-checked against the versioned public source where possible.
- A matching version tag is not a signed build-provenance statement.
- One live CLI V2 probe successfully spawned a child and captured parent/child rollout evidence; a separate ephemeral probe failed because no parent rollout was found. Neither run used the desktop conversation host. No network capture or private server-side implementation analysis is included.

## References

- [OpenAI Codex repository](https://github.com/openai/codex)
- [Version tag `rust-v0.162.0-alpha.17.2`](https://github.com/openai/codex/tree/740e5af33c71225640e0c1c1555c514c2c93ab74)
- [Version tag `rust-v0.162.1`](https://github.com/openai/codex/tree/092d3acd6bec3e3a14bdc7e7a2810ab628ab759d)
- [Codex multi-agent guide](https://developers.openai.com/api/docs/guides/agents-api/multi-agent)

