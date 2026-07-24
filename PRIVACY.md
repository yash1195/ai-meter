# AI Meter privacy

AI Meter is designed to calculate usage locally.

## Local files

AI Meter scans JSONL records stored by Codex and Claude Code:

- `~/.codex/sessions/**/*.jsonl`
- `~/.claude/projects/**/*.jsonl`

The records are processed on the Mac to extract timestamps, provider and model
names, session identifiers, and provider-reported token counts. AI Meter does
not extract or retain prompt text, response text, source code, or tool output.

Usage history is rebuilt from the local provider files. AI Meter stores only
interface preferences and environmental-estimation assumptions in
`UserDefaults`.

## Network access

AI Meter makes an HTTPS request to its public update manifest to check whether
a newer version is available. Local AI usage data and source records are not
included in that request and are not transmitted by AI Meter.

The update host keeps access logging disabled. AI Meter may use CloudFront's
aggregate request count to estimate update-check activity, but does not store
IP addresses, user agents, device identifiers, or per-user analytics.

## Screenshots

The Screenshot control renders the visible widget and places the PNG on the
Mac clipboard. Nothing is uploaded by AI Meter.

## Environmental estimates

Electricity and water values are calculations made locally from token counts
and adjustable methodology assumptions. They are not provider measurements.
