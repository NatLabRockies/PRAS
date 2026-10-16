"""
    ShortfallEvents

The `ShortfallEvents` result specification reports sample-level shortfall
events, producing a `ShortfallEventsResult`.

A shortfall event is a contiguous run of one or more simulation timesteps
with positive shortfall. A `ShortfallEventsResult` can be indexed by sample
number to retrieve system-wide events or by region name and sample number to
retrieve regional events. Each event records its starting timestep, ending
timestep and unserved energy.

Example:

```julia
events, =
    assess(sys, SequentialMonteCarlo(samples=1000), ShortfallEvents())

# Events for the first sample
system_events = events[1]
regional_events = events["Region A", 1]

# Each event has start_idx, end_idx and energy fields
first_system_event = first(system_events)
start_idx = first_system_event.start_idx
end_idx = first_system_event.end_idx
energy = first_system_event.energy

# System-wide event metrics
lolev = LOLEv(events)
mean_duration = MeanEventDuration(events)
max_duration = MaxEventDuration(events)
mean_energy = MeanEventEnergy(events)
max_energy = MaxEventEnergy(events)

# Regional event metrics
regional_lolev = LOLEv(events, "Region A")
```

This result stores every shortfall event for every sample and can require
significant memory for simulations with many samples or events.
"""
struct ShortfallEvents <: ResultSpec end

usesamplepartitions(::ShortfallEvents) = true

struct ShortfallEvent
    start_idx::Int
    end_idx::Int
    energy::Int

    function ShortfallEvent(start_idx::Int, end_idx::Int, energy::Int)
        start_idx > 0 || throw(DomainError(start_idx, "start_idx must be positive"))
        end_idx >= start_idx || throw(DomainError(end_idx, "end_idx must be >= start_idx"))
        energy >= 0 || throw(DomainError(energy, "energy must be non-negative"))
        new(start_idx, end_idx, energy)
    end
end

duration_periods(ev::ShortfallEvent) = ev.end_idx - ev.start_idx + 1
event_energy(ev::ShortfallEvent) = ev.energy
_event_meanestimate(xs::AbstractVector{<:Real}) =
    isempty(xs) ? MeanEstimate(0.0) : MeanEstimate(xs)

mutable struct ShortfallEventsAccumulator <: ResultAccumulator{ShortfallEvents}

    system_events::Vector{Vector{ShortfallEvent}}
    region_events::Matrix{Vector{ShortfallEvent}}

    in_system_event::Bool
    system_event_start::Int
    system_event_energy::Int

    in_region_event::Vector{Bool}
    region_event_start::Vector{Int}
    region_event_energy::Vector{Int}

    nperiods::Int
end

function accumulator(
    sys::SystemModel{N}, nsamples::Int, ::ShortfallEvents
) where {N}

    nregions = length(sys.regions)

    system_events = [ShortfallEvent[] for _ in 1:nsamples]
    region_events = [ShortfallEvent[] for _ in 1:nregions, _ in 1:nsamples]

    in_system_event = false
    system_event_start = 0
    system_event_energy = 0

    in_region_event = falses(nregions)
    region_event_start = zeros(Int, nregions)
    region_event_energy = zeros(Int, nregions)

    return ShortfallEventsAccumulator(
        system_events, region_events,
        in_system_event, system_event_start, system_event_energy,
        in_region_event, region_event_start, region_event_energy,
        N)
end

function merge!(
    x::ShortfallEventsAccumulator, y::ShortfallEventsAccumulator
)
    foreach(append!, x.system_events, y.system_events)
    foreach(append!, x.region_events, y.region_events)
    return
end

function copy_sample_partition!(
    x::ShortfallEventsAccumulator,
    y::ShortfallEventsAccumulator,
    sampleids::UnitRange{Int},
)
    @views x.system_events[sampleids] .= y.system_events
    @views x.region_events[:, sampleids] .= y.region_events
    return
end

accumulatortype(::ShortfallEvents) = ShortfallEventsAccumulator

struct ShortfallEventsResult{N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit} <: Result{N,L,T}
    regions::Regions
    timestamps::StepRange{ZonedDateTime,T}

    system_events::Vector{Vector{ShortfallEvent}}
    region_events::Matrix{Vector{ShortfallEvent}}
end

"""
    getindex(x::ShortfallEventsResult, s::Int)

Return the vector of system-wide shortfall events for sample `s`.
"""
function getindex(x::ShortfallEventsResult, s::Int)
    return x.system_events[s]
end

"""
    getindex(x::ShortfallEventsResult, r::AbstractString)

Return a vector whose `s`th entry is the vector of shortfall events
for region `r` in sample `s`.
"""
function getindex(x::ShortfallEventsResult, r::AbstractString)
    i_r = findfirstunique(x.regions.names, r)
    return [x.region_events[i_r, s] for s in axes(x.region_events, 2)]
end

"""
    getindex(x::ShortfallEventsResult, r::AbstractString, s::Int)

Return the vector of shortfall events for region `r` in sample `s`.
"""
function getindex(x::ShortfallEventsResult, r::AbstractString, s::Int)
    i_r = findfirstunique(x.regions.names, r)
    return x.region_events[i_r, s]
end

start_event_timestamp(x::ShortfallEventsResult, ev::ShortfallEvent) = x.timestamps[ev.start_idx]
end_event_timestamp(x::ShortfallEventsResult, ev::ShortfallEvent) = x.timestamps[ev.end_idx]

"""
    eventsinterval(x::ShortfallEventsResult, t::StepRange{ZonedDateTime})
    eventsinterval(x::ShortfallEventsResult, r::AbstractString, t::StepRange{ZonedDateTime})

Return system-wide events, or events in region `r`, fully contained between the first and last timestamps of `t`, inclusive.
The interval must be nonempty and forward in time with endpoints present in `x.timestamps`.
All simulation timesteps between the endpoints are considered, regardless of the step of `t`.

The returned vector contains a new event list for each original sample, including empty lists.
Event boundaries and stored energy are unchanged.
An `@info` message reports the number of overlapping events excluded because they start before or end after the interval, including events spanning the entire interval.
An empty list therefore means no fully contained events, not necessarily no shortfall.

For example, `eventsinterval(x, x.timestamps[2:7])` excludes events at timesteps 1–3 and 6–8 but includes an event at timesteps 3–6.
"""
function eventsinterval(x::ShortfallEventsResult, t::StepRange{ZonedDateTime})
    return _eventsinterval(x, t, x.system_events)
end

function eventsinterval(
    x::ShortfallEventsResult, r::AbstractString, t::StepRange{ZonedDateTime}
)
    i_r = findfirstunique(x.regions.names, r)
    return _eventsinterval(x, t, view(x.region_events, i_r, :))
end

function _eventsinterval(
    x::ShortfallEventsResult, t::StepRange{ZonedDateTime},
    sample_events::AbstractVector{Vector{ShortfallEvent}}
)
    (isempty(t) || first(t) > last(t)) &&
        throw(ArgumentError("The event interval must be nonempty and forward in time"))
    i_t0 = findfirstunique(x.timestamps, first(t))
    i_tf = findlastunique(x.timestamps, last(t))

    selected = [ShortfallEvent[] for _ in eachindex(sample_events)]
    nexcluded = 0
    for (included, events) in zip(selected, sample_events)
        for ev in events
            if i_t0 <= ev.start_idx && ev.end_idx <= i_tf
                push!(included, ev)
            elseif ev.start_idx <= i_tf && i_t0 <= ev.end_idx
                nexcluded += 1
            end
        end
    end

    if nexcluded > 0
        @info "Excluded $nexcluded overlapping events that extend beyond the requested interval. Only fully contained events are returned."
    end
    return selected
end

LOLEv(x::ShortfallEventsResult{N,L,T}) where {N,L,T} =
    LOLEv{N,L,T}(MeanEstimate(length.(x.system_events)))

function LOLEv(x::ShortfallEventsResult{N,L,T}, r::AbstractString) where {N,L,T}
    i_r = findfirstunique(x.regions.names, r)
    counts = [length(x.region_events[i_r, s]) for s in axes(x.region_events, 2)]
    return LOLEv{N,L,T}(MeanEstimate(counts))
end

function finalize(
    acc::ShortfallEventsAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}


    return ShortfallEventsResult{N,L,T,P,E}(
        system.regions, system.timestamps,
        acc.system_events, acc.region_events)
end

function MeanEventDuration(x::ShortfallEventsResult{N,L,T}) where {N,L,T}
    durations = [
        duration_periods(ev)
        for events in x.system_events
        for ev in events
    ]
    return MeanEventDuration{N,L,T}(_event_meanestimate(durations))
end

function MeanEventDuration(x::ShortfallEventsResult{N,L,T}, r::AbstractString) where {N,L,T}
    i_r = findfirstunique(x.regions.names, r)
    durations = [
        duration_periods(ev)
        for s in axes(x.region_events, 2)
        for ev in x.region_events[i_r, s]
    ]
    return MeanEventDuration{N,L,T}(_event_meanestimate(durations))
end

function MaxEventDuration(x::ShortfallEventsResult{N,L,T}) where {N,L,T}
    duration = maximum((
        duration_periods(ev)
        for events in x.system_events
        for ev in events
    ); init=0)
    return MaxEventDuration{N,L,T}(MeanEstimate(duration))
end

function MaxEventDuration(x::ShortfallEventsResult{N,L,T}, r::AbstractString) where {N,L,T}
    i_r = findfirstunique(x.regions.names, r)
    duration = maximum((
        duration_periods(ev)
        for s in axes(x.region_events, 2)
        for ev in x.region_events[i_r, s]
    ); init=0)
    return MaxEventDuration{N,L,T}(MeanEstimate(duration))
end

function MeanEventEnergy(x::ShortfallEventsResult{N,L,T,P,E}) where {N,L,T,P,E}
    p2e = conversionfactor(L, T, P, E)
    energies = [
        p2e * event_energy(ev)
        for events in x.system_events
        for ev in events
    ]
    return MeanEventEnergy{N,L,T,E}(_event_meanestimate(energies))
end

function MeanEventEnergy(x::ShortfallEventsResult{N,L,T,P,E}, r::AbstractString) where {N,L,T,P,E}
    i_r = findfirstunique(x.regions.names, r)
    p2e = conversionfactor(L, T, P, E)
    energies = [
        p2e * event_energy(ev)
        for s in axes(x.region_events, 2)
        for ev in x.region_events[i_r, s]
    ]
    return MeanEventEnergy{N,L,T,E}(_event_meanestimate(energies))
end

function MaxEventEnergy(x::ShortfallEventsResult{N,L,T,P,E}) where {N,L,T,P,E}
    p2e = conversionfactor(L, T, P, E)
    energy = maximum((
        p2e * event_energy(ev)
        for events in x.system_events
        for ev in events
    ); init=0.0)
    return MaxEventEnergy{N,L,T,E}(MeanEstimate(energy))
end

function MaxEventEnergy(x::ShortfallEventsResult{N,L,T,P,E}, r::AbstractString) where {N,L,T,P,E}
    i_r = findfirstunique(x.regions.names, r)
    p2e = conversionfactor(L, T, P, E)
    energy = maximum((
        p2e * event_energy(ev)
        for s in axes(x.region_events, 2)
        for ev in x.region_events[i_r, s]
    ); init=0.0)
    return MaxEventEnergy{N,L,T,E}(MeanEstimate(energy))
end


function totalevents(x::ShortfallEventsResult)
    return sum(length, x.system_events)
end

function totalevents(x::ShortfallEventsResult, r::AbstractString)
    i_r = findfirstunique(x.regions.names, r)
    return sum(length, view(x.region_events, i_r, :))
end
