---
description: Connect the telemetry plugin to a Claude Telemetry SaaS instance for team analytics
allowed-tools: AskUserQuestion, Bash, Read, Edit
---

# Connect to Claude Telemetry SaaS

Help the user connect their local telemetry plugin to a Claude Telemetry SaaS instance for team analytics.

## Steps

1. **Ask for the SaaS URL and API key:**

Use AskUserQuestion to collect:
- **API URL**: The SaaS instance URL (e.g., `https://telemetry.pando.codes`). Default: `https://telemetry.pando.codes`
- **API Key**: A `ct_live_...` API key generated from the SaaS dashboard (Settings → API Keys)

2. **Update the telemetry config:**

Read the current config at `~/.claude/telemetry/config.json`, then update it with the new `api_url` and `api_key` values. Preserve all existing settings.

3. **Test the connection:**

Run a curl command to verify the API key works:
```bash
curl -s -o /dev/null -w "%{http_code}" -X POST \
  "<api_url>/api/v1/events" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: <api_key>" \
  -d '{"events":[{"ts":"'"$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"'","event":"session_start","session_id":"test-connection","seq":0,"data":{"cwd":"test"}}]}'
```

If it returns 201, the connection works. If it returns 401 or 403, the API key is invalid.

4. **Confirm success:**

Tell the user:
- Events will now be queued locally during each session
- On session end, all queued events are batch-pushed to the SaaS
- Local JSONL files are still preserved (local-first is maintained)
- They can view their analytics at `<api_url>` after their next session

If the connection test failed, help them troubleshoot (wrong URL, expired key, etc.).
