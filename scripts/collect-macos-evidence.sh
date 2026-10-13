#!/bin/sh
set -eu

target=${1:-/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex}
if [ ! -x "$target" ]; then
  printf 'Executable not found or not executable: %s\n' "$target" >&2
  exit 1
fi

printf '%s\n' '## Version'
"$target" --version
printf '\n%s\n' '## SHA-256'
shasum -a 256 "$target"
printf '\n%s\n' '## Mach-O UUID'
dwarfdump --uuid "$target"
printf '\n%s\n' '## Selected symbols'
nm -an "$target" | rg 'LocalAgentControl.*(prepare_thread_spawn|maybe_start_completion_watcher|turn_finished)|multi_agents_v2.*(spawn|wait|list_agents|send_message|followup_task|interrupt_agent)|notify_parent_of_terminal_turn' | head -80 || true
printf '\n%s\n' '## Selected embedded strings'
strings -a "$target" | rg -o 'features\.multi_agent_v2\.(max_concurrent_threads_per_session|min_wait_timeout_ms|max_wait_timeout_ms|default_wait_timeout_ms)|codex\.multi_agent\.result_delivery|core/src/tools/handlers/multi_agents_v2/(spawn|wait|list_agents)\.rs' | sort -u | head -80 || true

