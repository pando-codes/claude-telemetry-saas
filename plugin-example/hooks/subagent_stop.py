#!/usr/bin/env python3
"""SubagentStop hook — log agent completion with tool attribution from transcript."""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent / "lib"))

from telemetry import read_hook_input, is_enabled, write_event, parse_agent_transcript


def main():
    hook_input = read_hook_input()
    if not is_enabled():
        return

    session_id = hook_input.get("session_id", "unknown")
    agent_type = hook_input.get("agent_type", "unknown")
    stop_reason = hook_input.get("stop_hook_reason", "unknown")
    transcript_path = hook_input.get("agent_transcript_path")

    # Parse the agent's transcript to extract tool usage breakdown
    tool_summary = {}
    if transcript_path:
        tool_summary = parse_agent_transcript(transcript_path)

    write_event("subagent_stop", session_id, {
        "agent_type": agent_type,
        "reason": stop_reason,
        "tool_counts": tool_summary.get("tool_counts", {}),
        "tool_count_total": tool_summary.get("total_tools", 0),
        "turns": tool_summary.get("turns", 0),
    })


if __name__ == "__main__":
    main()
