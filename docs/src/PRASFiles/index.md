# PRAS Files

PRASFiles.jl provides functionality for reading and writing PRAS-specific file formats, allowing you to save and load resource adequacy data structures.

This package enables:

- Loading and saving PRAS system models
- Importing data from various formats
- Exporting results and system information to standard formats

For detailed information on available methods and types, see the [API Reference](./api.md).

## [Exporting shortfall events](@id exporting_shortfall_events)

`saveevents` writes a `ShortfallEventsResult` to `pras_event_results.json` inside a timestamped output directory.
See [Shortfall Events](@ref shortfall_events) for event definitions and guidance on choosing a result specification.

```julia
using PRAS

sys = PRAS.rts_gmlc()
events, = assess(sys, SequentialMonteCarlo(samples=100, seed=1), ShortfallEvents())

summary_directory = saveevents(events, sys, "event_results_summary")
records_directory = saveevents(
    events, sys, "event_results_with_records";
    include_events=true,
)
```

Both calls export the sample count, system type parameters, system attributes and timestamps.
They also export `lolev`, `mean_event_duration`, `max_event_duration`, `mean_event_energy`, `max_event_energy` and `total_events` at system and regional levels.
Each metric contains `mean` and `stderror` fields; for the maximum metrics, `mean` holds the observed maximum and `stderror` is zero.
`total_events` counts all observed events rather than averaging their counts across samples.

With the default `include_events=false`, `system_events` and each region's `events` array are empty even when `total_events` is positive.
This omits records from the JSON file only; it does not change what `ShortfallEvents()` records during simulation.
With `include_events=true`, the same summary fields are accompanied by flattened event records.
The JSON uses `system_events` for system records and `region_results`, each containing a region `name` and an `events` array, for regional records.

For example, an individual record for 10 MW of shortfall over two 15-minute timesteps in a system with energy units of MWh would be:

```json
{
  "sample_id": 1,
  "start_timestamp": "2020-01-01T00:00:00.000+00:00",
  "end_timestamp": "2020-01-01T00:15:00.000+00:00",
  "duration_periods": 2,
  "energy": 5.0
}
```

`sample_id` is one-based and identifies the Monte Carlo sample containing the event.
The timestamps label the first and last included timesteps, so `end_timestamp` is not an exclusive end boundary.
`duration_periods` is a timestep count; its physical duration follows from the timestep length `L` and time unit `T` in `type_params`.
`energy` is total unserved energy converted to the energy unit `E` in `type_params`, not the raw sum stored in the internal event object.

Event exports are separate from the aggregate `pras_results.json` files written by `saveshortfall` and do not include EUE, LOLE or NEUE fields.
