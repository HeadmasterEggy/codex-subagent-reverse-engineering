# Codex Subagent Reverse Engineering

Evidence-led notes on how Codex creates, coordinates, and reports subagents.

This repository contains a static-analysis report for the macOS Codex CLI embedded in ChatGPT and version-scoped comparisons with public Codex source tags. It does not include the Codex application or redistribute upstream source files.

## Current finding

The ChatGPT app embeds CLI `0.162.0-alpha.17.2`; its version-matched public source tag resolves to [`740e5af33c71225640e0c1c1555c514c2c93ab74`](https://github.com/openai/codex/tree/740e5af33c71225640e0c1c1555c514c2c93ab74). The separately installed standalone CLI reports `0.162.1` and is a different binary. The public `rust-v0.162.1` tag peels to [`092d3acd6bec3e3a14bdc7e7a2810ab628ab759d`](https://github.com/openai/codex/tree/092d3acd6bec3e3a14bdc7e7a2810ab628ab759d). Neither version match proves exact binary build provenance.

In that source snapshot, V2 spawn creates a child thread through shared `AgentControl`, persists the parent-child edge before submitting the initial input, and delivers terminal outcomes through the V2 session event path. The detached completion watcher is the legacy route. See [the evidence report](evidence/subagent-flow.md).

A separate current-`main` source follow-up traces inherited environment selections into child startup and conditionally gated V2 capability discovery into MCP and world-state contribution contexts. Its integration test checks inventory projection without placing the sentinel skill string in model requests, but does not spawn a child; this is not evidence that V2-discovered skills become direct model-callable tools or that the installed Desktop uses current `main`. See the [version-scoped V2 discovery evidence](evidence/subagent-flow.md#current-main-v2-capability-discovery-metadata-and-child-step-projection).

A static inspection of the installed ChatGPT Desktop 26.1007.30912 bundle also confirms that its selected-subagent details header renders model and reasoning effort from the child thread's model-settings selector. The bundle maps that selector to `latestModel`/`latestReasoningEffort`, initialized from thread metadata. The inspection does not establish that V2 activity-item fields feed this selector, and it does not prove a live render; see [the scoped Desktop panel evidence](evidence/subagent-flow.md#installed-desktop-panel-renders-selected-child-model-settings).

The same installed bundle shows that conversation WebSocket events notify the desktop `localThreadCatalog` using `{hostId, conversationId}` and can trigger catalog refresh after reconnect. The main-process implementation maps those notifications to archive/unarchive catalog operations; this confirms a catalog synchronization bridge, not message-body ingestion into the app-server item store or the Work activity projection. See [the conversation socket/catalog trace](evidence/subagent-flow.md#installed-desktop-conversation-socket-notifies-the-local-thread-catalog).

Follow-up tracing shows that app-server catalog reads use `listThreads`/`readThread(includeTurns:false)`, while the ChatGPT catalog source maps `/conversations` metadata. Renderer catalog refresh updates thread metadata and recent summaries; its `mode:"catalog"` branch does not hydrate transcript turns. Separately, Work activity rows consume `vin`'s projection of the renderer conversation mapping, populated through history hydration and conversation WebSocket updates/refetches. The causal connection from that mapping to the app-server `item/started`/`item/completed` reducer remains unproven. See the [catalog trace](evidence/subagent-flow.md#installed-desktop-conversation-socket-notifies-the-local-thread-catalog) and [Work projection data path](evidence/subagent-flow.md#installed-desktop-work-projection-is-fed-by-the-renderer-conversation-mapping) for scoped evidence.

A read-only correlation of the local Codex Desktop session store found three V2 parent-child rollout pairs for embedded CLI `0.162.0-alpha.17.2`. In each recorded sequence, the child's `task_started` precedes the parent's `SubAgentActivity(Started)`; at completion, `task_complete` precedes `Completed`, followed by the matching parent `agent_message`. This is a scoped observation of locally retained rollout records, not evidence of a global desktop default or exact UI render timing. No identifiers or message contents are published; see [the desktop runtime evidence](evidence/subagent-flow.md#desktop-research-session-runtime-metadata).

Matching each parent's `wait_agent` call to its recorded output adds an important boundary: two outputs mapped to `MailboxActivity`, one timed out; the matching parent `agent_message` followed the wait output in all three. In the two `MailboxActivity` pairs, the linked child's completion activity was recorded between the wait call and its output. The rollout does not identify which mailbox notification woke either handler. The timeout pair's child rollout contains multiple turns, so these records do not establish whether that wait output preceded completion of the specific child turn. This local sample does not make V2 `wait_agent` a child-join operation; see the detailed [wait timing evidence](evidence/subagent-flow.md#desktop-research-session-runtime-metadata).

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

