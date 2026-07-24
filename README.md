# AI Meter

A local macOS menu-bar dashboard that totals token usage across concurrent Codex
and Claude Code sessions.

The app locally scans provider records stored at:

- `~/.codex/sessions/**/*.jsonl`
- `~/.claude/projects/**/*.jsonl`

It extracts usage metadata without retaining or transmitting prompt, response,
source-code, or tool-output content. See [PRIVACY.md](PRIVACY.md) for the exact
data boundary and update-check network behavior.

## Dashboard

- Clicking the menu-bar total opens a native dropdown dashboard.
- Periods: Today, This Week, Month, Year to Date, and Lifetime.
- Interactive hourly, daily, or monthly chart with Codex and Claude Code series.
- Provider filters and provider/model breakdowns from actual local metadata.
- Token, estimated electricity, and estimated water chart modes.
- SCI for AI-aligned methodology with adjustable environmental assumptions.
- Automatic update availability checks with an in-widget update link.
- Copy an exact PNG screenshot of the visible widget using the Screenshot button.

## Run during development

```sh
swift run AIUsageMonitor
```

## Test

```sh
swift test
```

## Build a local `.app`

```sh
chmod +x scripts/build-app.sh
scripts/build-app.sh
open "dist/AI Meter.app"
```

The script creates a universal application for Apple Silicon and Intel Macs.
The generated application is intended for local development and is not signed
or notarized. A distributable build should use a Developer ID certificate and
Apple notarization.

## Counting rules

- Codex emits cumulative session totals. AI Meter records only the positive
  delta from one `token_count` event to the next.
- Codex cached input is a subset of its reported input, so it is not added a
  second time.
- Claude Code reports ordinary input, cache creation, cache reads, and output
  separately; all four categories contribute to the total.
- Claude messages are deduplicated by provider message ID.
- Events are assigned to a day using the Mac's current calendar and time zone.

## Environmental estimates

Environmental values are scenarios, not provider measurements. AI Meter follows
the SCI for AI consumer boundary and uses provider-reported tokens as its
functional unit. The defaults are:

- `0.39 facility kWh / 1M tokens`, calibrated from a production-scale inference
  midpoint of `0.31 Wh` for a representative 800-token query.
- `1.20` PUE, within the `1.05–1.40` hyperscale range used by the inference study.
- `0.45 L / IT kWh` site WUE, based on the U.S. national-lab data-center
  scenario range.

The dashboard calculates direct site water as
`facility energy ÷ PUE × site WUE`. All assumptions are adjustable. See
[METHODOLOGY.md](METHODOLOGY.md) for the derivation, boundaries, uncertainty,
and primary sources.

## Updates

AI Meter checks an HTTPS JSON manifest every six hours and also provides a
manual check. The configured production URL is:

`https://github.com/yash1195/ai-meter/releases/latest/download/latest.json`

The manifest format is:

```json
{
  "version": "0.2.0",
  "build": 2,
  "releaseURL": "https://github.com/yash1195/ai-meter/releases/tag/v0.2.0"
}
```

The monotonic `build` value is compared with `CFBundleVersion`. When a newer
build exists, the widget presents an **Update to latest** button that opens the
signed, notarized release. AI Meter does not install updates automatically.

## License

Official, unmodified AI Meter releases are free for individuals and companies
to install and use, including for internal commercial business use. The public
source is available for evaluation and security review, but source copying,
modification, redistribution, deployment, and product replication are not
permitted without written permission. This is source-available software, not
open source. See [LICENSE](LICENSE).
