"""
    ShortfallEvents

The `ShortfallEvents` result specification reports sample-level shortfall
events, producing a `ShortfallEventsResult`.

A shortfall event is a contiguous run of one or more simulation timesteps
with positive shortfall.

This result can be used to inspect event start/end times and to compute
event-based reliability metrics such as [`LOLEv`](@ref).
"""
struct ShortfallEvents <: ResultSpec end

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

mutable struct ShortfallEventsAccumulator{S} <: ResultAccumulator{ShortfallEvents}

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
    sys::SystemModel{N}, nsamples::Int, ::S
) where {N,S<:ShortfallEvents}

    nregions = length(sys.regions)

    system_events = [ShortfallEvent[] for _ in 1:nsamples]
    region_events = [ShortfallEvent[] for _ in 1:nregions, _ in 1:nsamples]

    in_system_event = false
    system_event_start = 0
    system_event_energy = 0

    in_region_event = falses(nregions)
    region_event_start = zeros(Int, nregions)
    region_event_energy = zeros(Int, nregions)

    return ShortfallEventsAccumulator{S}(
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

accumulatortype(::S) where {
        S<:ShortfallEvents
    } = ShortfallEventsAccumulator{S}

struct ShortfallEventsResult{N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit,S} <: AbstractShortfallEventResult{N,L,T}
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

LOLEv(x::ShortfallEventsResult{N,L,T}) where {N,L,T} =
    LOLEv{N,L,T}(MeanEstimate(length.(x.system_events)))

function LOLEv(x::ShortfallEventsResult{N,L,T}, r::AbstractString) where {N,L,T}
    i_r = findfirstunique(x.regions.names, r)
    counts = [length(x.region_events[i_r, s]) for s in axes(x.region_events, 2)]
    return LOLEv{N,L,T}(MeanEstimate(counts))
end

function finalize(
    acc::ShortfallEventsAccumulator{S},
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E,S<:ShortfallEvents}


    return ShortfallEventsResult{N,L,T,P,E,S}(
        system.regions, system.timestamps,
        acc.system_events, acc.region_events)
end

function MeanEventDuration(x::ShortfallEventsResult{N,L,T}) where {N,L,T}
    durations = Float64[
        isempty(events) ? 0.0 : mean(duration_periods.(events))
        for events in x.system_events
    ]
    return MeanEventDuration{N,L,T}(MeanEstimate(durations))
end

function MeanEventDuration(x::ShortfallEventsResult{N,L,T}, r::AbstractString) where {N,L,T}
    i_r = findfirstunique(x.regions.names, r)
    durations = Float64[
        isempty(x.region_events[i_r, s]) ? 0.0 :
            mean(duration_periods.(x.region_events[i_r, s]))
        for s in axes(x.region_events, 2)
    ]
    return MeanEventDuration{N,L,T}(MeanEstimate(durations))
end

function MaxEventDuration(x::ShortfallEventsResult{N,L,T}) where {N,L,T}
    durations = Float64[
        isempty(events) ? 0.0 : maximum(duration_periods.(events))
        for events in x.system_events
    ]
    return MaxEventDuration{N,L,T}(MeanEstimate(durations))
end

function MaxEventDuration(x::ShortfallEventsResult{N,L,T}, r::AbstractString) where {N,L,T}
    i_r = findfirstunique(x.regions.names, r)
    durations = Float64[
        isempty(x.region_events[i_r, s]) ? 0.0 :
            maximum(duration_periods.(x.region_events[i_r, s]))
        for s in axes(x.region_events, 2)
    ]
    return MaxEventDuration{N,L,T}(MeanEstimate(durations))
end

function MeanEventEnergy(x::ShortfallEventsResult{N,L,T,P,E}) where {N,L,T,P,E}
    p2e = conversionfactor(L, T, P, E)
    energies = Float64[
        isempty(events) ? 0.0 : mean(p2e .* event_energy.(events))
        for events in x.system_events
    ]
    return MeanEventEnergy{N,L,T,E}(MeanEstimate(energies))
end

function MeanEventEnergy(x::ShortfallEventsResult{N,L,T,P,E}, r::AbstractString) where {N,L,T,P,E}
    i_r = findfirstunique(x.regions.names, r)
    p2e = conversionfactor(L, T, P, E)
    energies = Float64[
        isempty(x.region_events[i_r, s]) ? 0.0 :
            mean(p2e .* event_energy.(x.region_events[i_r, s]))
        for s in axes(x.region_events, 2)
    ]
    return MeanEventEnergy{N,L,T,E}(MeanEstimate(energies))
end

function MaxEventEnergy(x::ShortfallEventsResult{N,L,T,P,E}) where {N,L,T,P,E}
    p2e = conversionfactor(L, T, P, E)
    energies = Float64[
        isempty(events) ? 0.0 : maximum(p2e .* event_energy.(events))
        for events in x.system_events
    ]
    return MaxEventEnergy{N,L,T,E}(MeanEstimate(energies))
end

function MaxEventEnergy(x::ShortfallEventsResult{N,L,T,P,E}, r::AbstractString) where {N,L,T,P,E}
    i_r = findfirstunique(x.regions.names, r)
    p2e = conversionfactor(L, T, P, E)
    energies = Float64[
        isempty(x.region_events[i_r, s]) ? 0.0 :
            maximum(p2e .* event_energy.(x.region_events[i_r, s]))
        for s in axes(x.region_events, 2)
    ]
    return MaxEventEnergy{N,L,T,E}(MeanEstimate(energies))
end


function totalevents(x::ShortfallEventsResult)
    return sum(length, x.system_events)
end

function totalevents(x::ShortfallEventsResult, r::AbstractString)
    i_r = findfirstunique(x.regions.names, r)
    return sum(length, view(x.region_events, i_r, :))
end

