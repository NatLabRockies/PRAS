struct TypeParams
    N::Int64
    L::Int64
    T::String
    P::String
    E::String
end

function TypeParams(pras_sys::SystemModel{N,L,T,P,E}) where {N,L,T,P,E}
    return TypeParams(
        N,
        L,
        unitsymbol(T),
        unitsymbol(P),
        unitsymbol(E),
    )
end

struct EUEResult
    mean::Float64
    stderror::Float64
end

function EUEResult(shortfall::AbstractShortfallResult; region::Union{Nothing, String} = nothing)

    eue = (region === nothing) ? EUE(shortfall) :  EUE(shortfall, region)
    return EUEResult(
        eue.eue.estimate,
        eue.eue.standarderror,
    )
end

struct LOLEResult
    mean::Float64
    stderror::Float64
end

function LOLEResult(shortfall::AbstractShortfallResult; region::Union{Nothing, String} = nothing) 

    lole = (region === nothing) ?  LOLE(shortfall) : LOLE(shortfall, region)
    return LOLEResult(
        lole.lole.estimate,
        lole.lole.standarderror,
    )
end

struct NEUEResult
    mean::Float64
    stderror::Float64
end

function NEUEResult(shortfall::AbstractShortfallResult; region::Union{Nothing, String} = nothing)

    neue = (region === nothing) ? NEUE(shortfall) :  NEUE(shortfall, region)
    return NEUEResult(
        neue.neue.estimate,
        neue.neue.standarderror,
    )
end

struct LOLDResult
    mean::Float64
    stderror::Float64
end

function LOLDResult(shortfall::ShortfallSamplesResult; region::Union{Nothing, String} = nothing)

    lold = (region === nothing) ? LOLD(shortfall) : LOLD(shortfall, region)
    return LOLDResult(
        lold.lold.estimate,
        lold.lold.standarderror,
    )
end

struct LOLEvResult
    mean::Float64
    stderror::Float64
end

function LOLEvResult(events::ShortfallEventsResult; region::Union{Nothing, String} = nothing)
    lolev = (region === nothing) ? LOLEv(events) : LOLEv(events, region)
    return LOLEvResult(
        lolev.lolev.estimate,
        lolev.lolev.standarderror,
    )
end

struct MeanEventDurationResult
    mean::Float64
    stderror::Float64
end

function MeanEventDurationResult(events::ShortfallEventsResult; region::Union{Nothing, String} = nothing)
    duration = (region === nothing) ? MeanEventDuration(events) : MeanEventDuration(events, region)
    return MeanEventDurationResult(
        duration.duration.estimate,
        duration.duration.standarderror,
    )
end

struct MaxEventDurationResult
    mean::Float64
    stderror::Float64
end

function MaxEventDurationResult(events::ShortfallEventsResult; region::Union{Nothing, String} = nothing)
    duration = (region === nothing) ? MaxEventDuration(events) : MaxEventDuration(events, region)
    return MaxEventDurationResult(
        duration.duration.estimate,
        duration.duration.standarderror,
    )
end

struct MeanEventEnergyResult
    mean::Float64
    stderror::Float64
end

function MeanEventEnergyResult(events::ShortfallEventsResult; region::Union{Nothing, String} = nothing)
    energy = (region === nothing) ? MeanEventEnergy(events) : MeanEventEnergy(events, region)
    return MeanEventEnergyResult(
        energy.energy.estimate,
        energy.energy.standarderror,
    )
end

struct MaxEventEnergyResult
    mean::Float64
    stderror::Float64
end

function MaxEventEnergyResult(events::ShortfallEventsResult; region::Union{Nothing, String} = nothing)
    energy = (region === nothing) ? MaxEventEnergy(events) : MaxEventEnergy(events, region)
    return MaxEventEnergyResult(
        energy.energy.estimate,
        energy.energy.standarderror,
    )
end

struct EventRecord
    sample_id::Int64
    start_timestamp::ZonedDateTime
    end_timestamp::ZonedDateTime
    duration_periods::Int64
    energy::Float64
end

struct RegionResult
    name::String
    eue::EUEResult
    lole::LOLEResult
    neue::NEUEResult
    lold::Union{Nothing, LOLDResult}
    load::Vector{Int64}
    peak_load::Float64
    capacity::Dict{String,Vector{Int64}}
    shortfall_mean::Vector{Float64}
    shortfall_timestamps::Vector{ZonedDateTime}
end

struct RegionEventResult
    name::String
    lolev::LOLEvResult
    mean_event_duration::MeanEventDurationResult
    max_event_duration::MaxEventDurationResult
    mean_event_energy::MeanEventEnergyResult
    max_event_energy::MaxEventEnergyResult
    total_events::Int64
    events::Vector{EventRecord}
end

struct SystemResult
    num_samples::Int64
    type_params::TypeParams
    sys_attributes::Dict{String, String}
    timestamps::Vector{ZonedDateTime}
    eue::EUEResult
    lole::LOLEResult
    neue::NEUEResult
    lold::Union{Nothing, LOLDResult}
    region_results::Vector{RegionResult}
end

struct SystemEventResult
    num_samples::Int64
    type_params::TypeParams
    sys_attributes::Dict{String, String}
    timestamps::Vector{ZonedDateTime}
    lolev::LOLEvResult
    mean_event_duration::MeanEventDurationResult
    max_event_duration::MaxEventDurationResult
    mean_event_energy::MeanEventEnergyResult
    max_event_energy::MaxEventEnergyResult
    total_events::Int64
    system_events::Vector{EventRecord}
    region_results::Vector{RegionEventResult}
end

function get_shortfall_mean(shortfall::ShortfallResult)
    return shortfall.shortfall_mean
end

function get_shortfall_mean(shortfall::ShortfallSamplesResult{N,L,T,P,E}) where {N,L,T,P,E}
    shortfall_mean = mean(shortfall.shortfall, dims = 3)
    shortfall_mean .*= conversionfactor(L, T, P, E)
    return shortfall_mean
end

function get_nsamples(shortfall::ShortfallResult)
    return shortfall.nsamples
end

function get_nsamples(shortfall::ShortfallSamplesResult)
    return size(shortfall.shortfall,3)
end

function get_nsamples(events::ShortfallEventsResult)
    return length(events.system_events)
end

function get_lold_result(
    shortfall::ShortfallResult,
    log_lold_info::Bool;
    region::Union{Nothing, String} = nothing,
)
    if log_lold_info
        @info "LOLD is not implemented for ShortfallResult and will not be " *
              "included in the JSON export. Use ShortfallSamplesResult to " *
              "compute LOLD."
    end
    return nothing
end

function get_lold_result(
    shortfall::ShortfallSamplesResult,
    ::Bool;
    region::Union{Nothing, String} = nothing,
)
    return LOLDResult(shortfall; region = region)
end

function _get_eventrecords(
    events::ShortfallEventsResult{N,L,T,P,E},
    events_by_sample::AbstractVector{<:AbstractVector{ShortfallEvent}},
) where {N,L,T,P,E}
    p2e = conversionfactor(L, T, P, E)
    nrecords = sum(length, events_by_sample)
    iszero(nrecords) && return EventRecord[]

    records = Vector{EventRecord}(undef, nrecords)
    record_idx = 1

    for (sample_id, evts) in enumerate(events_by_sample)
        for ev in evts
            records[record_idx] = EventRecord(
                sample_id,
                start_event_timestamp(events, ev),
                end_event_timestamp(events, ev),
                duration_periods(ev),
                p2e * event_energy(ev),
            )
            record_idx += 1
        end
    end

    return records
end

function get_eventrecords(events::ShortfallEventsResult)
    return _get_eventrecords(events, events.system_events)
end

function get_eventrecords(
    events::ShortfallEventsResult,
    region::String,
)
    i_r = findfirstunique(events.regions.names, region)
    return _get_eventrecords(events, view(events.region_events, i_r, :))
end

# Define structtypes for different structs defined above
StructType(::Type{TypeParams}) = Struct()
StructType(::Type{EUEResult}) = Struct()
StructType(::Type{NEUEResult}) = Struct()
StructType(::Type{LOLEResult}) = Struct()
StructType(::Type{LOLDResult}) = Struct()
StructType(::Type{RegionResult}) = OrderedStruct()
StructType(::Type{SystemResult}) = OrderedStruct()
StructType(::Type{LOLEvResult}) = Struct()
StructType(::Type{MeanEventDurationResult}) = Struct()
StructType(::Type{MaxEventDurationResult}) = Struct()
StructType(::Type{MeanEventEnergyResult}) = Struct()
StructType(::Type{MaxEventEnergyResult}) = Struct()
StructType(::Type{EventRecord}) = Struct()
StructType(::Type{RegionEventResult}) = OrderedStruct()
StructType(::Type{SystemEventResult}) = OrderedStruct()
