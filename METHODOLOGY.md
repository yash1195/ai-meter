# AI Meter environmental methodology

## What the estimate represents

AI Meter reports a consumer-side operational scenario for the language-model
usage recorded in local Codex and Claude Code logs. It is an estimate, not a
measurement from OpenAI, Anthropic, or their infrastructure providers.

The boundary and functional unit follow the ratified Green Software Foundation
Software Carbon Intensity for AI specification:

- Boundary: consumer-side operation and monitoring.
- Functional unit: provider-reported language-model tokens.
- Included today: estimated inference facility electricity and direct
  data-center cooling water.

This is not a complete SCI score because model providers do not expose the
infrastructure, location, grid carbon intensity, or embodied-hardware data
required for one.

## Electricity

AI Meter uses:

```text
facility electricity =
    reported tokens / 1,000,000
    × facility kWh per million tokens
```

The default is **0.39 facility kWh per million tokens**.

The calibration comes from the production-scale bottom-up model published by
Oviedo et al. in *Joule* in 2026. Its frontier-model baseline reports a median
of 0.31 Wh for a traditional query with 500 input and 300 output tokens:

```text
0.31 Wh / 800 tokens × 1,000,000 tokens / 1,000 Wh per kWh
= 0.3875 kWh per million tokens
≈ 0.39 kWh per million tokens
```

Applying the same conversion to the paper's 0.16–0.60 Wh interquartile range
gives an approximate **0.20–0.75 kWh per million tokens** uncertainty band.
The paper models production batching, H100 nodes, node power, token throughput,
and PUE. It also finds that output decoding generally dominates energy use.

AI Meter scales total reported tokens because both local sources reliably
expose total usage. This is a practical calibration, not a claim that every
input, cached, reasoning, and output token has identical marginal energy.
Long-context coding workloads, cache reuse, model routing, hardware generation,
quantization, batching, and provider-specific serving can move the real value
outside the displayed range.

## Direct cooling water

AI Meter uses the ISO/IEC 30134-9 definition of site Water Usage Effectiveness:

```text
WUE = annual direct data-center water / annual IT-equipment energy
```

Because the electricity factor above represents facility energy and WUE uses
IT energy as its denominator, AI Meter first removes facility overhead:

```text
IT energy = facility energy / PUE
direct site water = IT energy × site WUE
```

Defaults:

- **PUE 1.20**, within the 1.05–1.40 hyperscale range modeled by Oviedo et al.
- **Site WUE 0.45 L/IT kWh**, the lower end of the 0.45–0.48 L/kWh post-2023
  scenario range in Lawrence Berkeley National Laboratory's 2024 U.S. Data
  Center Energy Usage Report.

WUE varies sharply by facility, season, cooling design, and local climate.
Closed-loop chilled-water systems recirculate water internally but may still
consume makeup water through evaporative heat rejection. Dry-cooled sites can
have direct WUE near zero. The dashboard therefore lets the user set WUE to
zero or explore a broader scenario.

## Human-scale equivalents

The summary cards translate the calculated electricity and water values into
familiar comparisons. These are display analogies only and do not add to or
change the environmental estimate:

- **Tesla Model 3:** 25.4 kWh per 100 miles, the comparison consumption rating
  published by Tesla. AI Meter converts this to 0.254 kWh per mile, or
  approximately 3.94 miles per kWh.
- **WaterSense shower:** 7.6 liters per minute, the maximum rated flow for an
  EPA WaterSense-labeled showerhead. Larger values are shown as the equivalent
  number of 15-minute showers.

Actual vehicle efficiency varies by trim, speed, weather, terrain, and driving
style; showerheads vary too. The comparisons describe quantity, not the source,
location, or environmental consequences of that energy or water.

## Exclusions

The current estimate excludes:

- model research, data preparation, and training;
- hardware manufacturing and other embodied impacts;
- water consumed to generate electricity off-site;
- grid carbon emissions;
- networking, storage, orchestration, and tool activity not represented in
  provider token logs;
- user-device electricity.

These exclusions are disclosed in the widget. Future provider telemetry can
replace assumptions without changing the boundary or formulas.

## Primary sources

- Green Software Foundation, [SCI for AI](https://greensoftware.foundation/standards/sci-ai/)
- Oviedo et al., [Energy Use of AI Inference, Efficiency Pathways, and Test-Time Scaling](https://arxiv.org/abs/2509.20241)
- ISO, [ISO/IEC 30134-9:2022 — Water Usage Effectiveness](https://www.iso.org/standard/77692.html)
- Lawrence Berkeley National Laboratory, [2024 United States Data Center Energy Usage Report](https://doi.org/10.71468/P1WC7Q)
- Tesla, [Model 3 design and consumption rating](https://www.tesla.com/model3/design)
- U.S. Environmental Protection Agency, [WaterSense showerhead technical sheet](https://www.epa.gov/system/files/documents/2023-08/ws-homes-TRM-4-ShowerheadsTechSheet.pdf)
