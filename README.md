# Codex Subagent Reverse Engineering

Evidence-led notes on how Codex creates, coordinates, and reports subagents.

This repository contains a static-analysis report for the macOS Codex CLI embedded in ChatGPT and a source comparison against the matching public Codex version tag. It does not include the Codex application or redistribute upstream source files.

## Current finding

The installed CLI reports `0.162.0-alpha.17.2`. The public `openai/codex` tag with that version resolves to commit [`740e5af33c71225640e0c1c1555c514c2c93ab74`](https://github.com/openai/codex/tree/740e5af33c71225640e0c1c1555c514c2c93ab74). The matching version and local symbols provide a strong comparison point, but do not prove that this exact app binary was built from that commit.

In that source snapshot, V2 spawn creates a child thread through shared `AgentControl`, persists the parent-child edge before submitting the initial input, and delivers terminal outcomes through the V2 session event path. The detached completion watcher is the legacy route. See [the evidence report](evidence/subagent-flow.md).

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
- No live multi-agent run, network capture, or server-side implementation analysis is included.

## References

- [OpenAI Codex repository](https://github.com/openai/codex)
- [Version tag `rust-v0.162.0-alpha.17.2`](https://github.com/openai/codex/tree/740e5af33c71225640e0c1c1555c514c2c93ab74)
- [Codex multi-agent guide](https://developers.openai.com/api/docs/guides/agents-api/multi-agent)

