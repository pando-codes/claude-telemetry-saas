#!/usr/bin/env python3
"""Stop hook — log stop reason."""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent / "lib"))

from telemetry import read_hook_input, is_enabled, write_event


def main():
    hook_input = read_hook_input()
    if not is_enabled():
        return

    session_id = hook_input.get("session_id", "unknown")
    reason = hook_input.get("stop_hook_reason", "unknown")

    write_event("stop", session_id, {
        "reason": reason,
    })


if __name__ == "__main__":
    main()
