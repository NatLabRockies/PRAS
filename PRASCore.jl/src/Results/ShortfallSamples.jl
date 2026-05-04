"""
    ShortfallSamples

The `ShortfallSamples` result specification reports sample-level unserved energy outcomes, producing a `ShortfallSamplesResult`.

A `ShortfallSamplesResult` can be directly indexed by a region name and a
timestamp to retrieve a vector of sample-level unserved energy results in that
region and timestep. [`EUE`](@ref) and [`LOLE`](@ref) constructors can also
be used to retrieve standard risk metrics.

Example:

```julia
shortfall, =
    assess(sys, SequentialMonteCarlo(samples=10), ShortfallSamples())

period = ZonedDateTime(2020, 1, 1, 0, tz"UTC")
day = Date(2020, 1, 1)

samples = shortfall["Region A", period]

@assert samples isa Vector{Float64}
@assert length(samples) == 10

# System-wide risk metrics
eue = EUE(shortfall)
lole = LOLE(shortfall)
neue = NEUE(shortfall)
lold = LOLD(shortfall)

# Regional risk metrics
regional_eue = EUE(shortfall, "Region A")
regional_lole = LOLE(shortfall, "Region A")
regional_neue = NEUE(shortfall, "Region A")
regional_lold = LOLD(shortfall, "Region A")

# Period-specific risk metrics
period_eue = EUE(shortfall, period)
period_lolp = LOLE(shortfall, period)
day_lold = LOLD(shortfall, day)

# Region- and period-specific risk metrics
period_eue = EUE(shortfall, "Region A", period)
period_lolp = LOLE(shortfall, "Region A", period)
regional_day_lold = LOLD(shortfall, "Region A", day)
```

Note that this result specification requires large amounts of memory for
larger sample sizes. See [`Shortfall`](@ref) for average shortfall outcomes when sample-level granularity isn't required.
"""
struct ShortfallSamples <: ResultSpec end
struct DemandResponseShortfallSamples <: ResultSpec end

struct ShortfallSamplesAccumulator{S} <: ResultAccumulator{ShortfallSamples}

    shortfall::Array{Int,3}

end

function accumulator(
    sys::SystemModel{N}, nsamples::Int, ::S
) where {N,S<:Union{ShortfallSamples,DemandResponseShortfallSamples}}

    nregions = length(sys.regions)
    shortfall = zeros(Int, nregions, N, nsamples)

    return ShortfallSamplesAccumulator{S}(shortfall)

end

function merge!(
    x::ShortfallSamplesAccumulator, y::ShortfallSamplesAccumulator
)

    x.shortfall .+= y.shortfall
    return

end

accumulatortype(::S) where {
        S<:Union{ShortfallSamples,DemandResponseShortfallSamples}
    } = ShortfallSamplesAccumulator{S}

struct ShortfallSamplesResult{N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit, S} <: AbstractShortfallResult{N,L,T}

    regions::Regions{N,P}
    timestamps::StepRange{ZonedDateTime,T}

    shortfall::Array{Int,3} # r x t x s

end

function getindex(
    x::ShortfallSamplesResult{N,L,T,P,E}
) where {N,L,T,P,E}
    p2e = conversionfactor(L, T, P, E)
    return vec(p2e * sum(x.shortfall, dims=1:2))
end

function getindex(
    x::ShortfallSamplesResult{N,L,T,P,E}, r::AbstractString
) where {N,L,T,P,E}
    i_r = findfirstunique(x.regions.names, r)
    p2e = conversionfactor(L, T, P, E)
    return vec(p2e * sum(view(x.shortfall, i_r, :, :), dims=1))
end

function getindex(
    x::ShortfallSamplesResult{N,L,T,P,E}, t::ZonedDateTime
) where {N,L,T,P,E}
    i_t = findfirstunique(x.timestamps, t)
    p2e = conversionfactor(L, T, P, E)
    return vec(p2e * sum(view(x.shortfall, :, i_t, :), dims=1))
end

function getindex(
    x::ShortfallSamplesResult{N,L,T,P,E}, r::AbstractString, t::ZonedDateTime
) where {N,L,T,P,E}
    i_r = findfirstunique(x.regions.names, r)
    i_t = findfirstunique(x.timestamps, t)
    p2e = conversionfactor(L, T, P, E)
    return vec(p2e * x.shortfall[i_r, i_t, :])
end


function LOLE(x::ShortfallSamplesResult{N,L,T}) where {N,L,T}
    eventperiods = sum(sum(x.shortfall, dims=1) .> 0, dims=2)
    return LOLE{N,L,T}(MeanEstimate(eventperiods))
end

function LOLE(x::ShortfallSamplesResult{N,L,T}, r::AbstractString) where {N,L,T}
    i_r = findfirstunique(x.regions.names, r)
    eventperiods = sum(view(x.shortfall, i_r, :, :) .> 0, dims=1)
    return LOLE{N,L,T}(MeanEstimate(eventperiods))
end

function LOLE(x::ShortfallSamplesResult{N,L,T}, t::ZonedDateTime) where {N,L,T}
    i_t = findfirstunique(x.timestamps, t)
    eventperiods = sum(view(x.shortfall, :, i_t, :), dims=1) .> 0
    return LOLE{1,L,T}(MeanEstimate(eventperiods))
end

function LOLE(x::ShortfallSamplesResult{N,L,T}, r::AbstractString, t::ZonedDateTime) where {N,L,T}
    i_r = findfirstunique(x.regions.names, r)
    i_t = findfirstunique(x.timestamps, t)
    eventperiods = view(x.shortfall, i_r, i_t, :) .> 0
    return LOLE{1,L,T}(MeanEstimate(eventperiods))
end


EUE(x::ShortfallSamplesResult{N,L,T,P,E}) where {N,L,T,P,E} =
    EUE{N,L,T,E}(MeanEstimate(x[]))

EUE(x::ShortfallSamplesResult{N,L,T,P,E}, r::AbstractString) where {N,L,T,P,E} =
    EUE{N,L,T,E}(MeanEstimate(x[r]))

EUE(x::ShortfallSamplesResult{N,L,T,P,E}, t::ZonedDateTime) where {N,L,T,P,E} =
    EUE{1,L,T,E}(MeanEstimate(x[t]))

EUE(x::ShortfallSamplesResult{N,L,T,P,E}, r::AbstractString, t::ZonedDateTime) where {N,L,T,P,E} =
    EUE{1,L,T,E}(MeanEstimate(x[r, t]))

function NEUE(x::ShortfallSamplesResult)

    demand = sum(x.regions.load)

    estimate = if demand > 0
        div(MeanEstimate(x[]), demand/1e6)
    else
        MeanEstimate(0.)
    end

    return NEUE(estimate)

end

function NEUE(x::ShortfallSamplesResult, r::AbstractString)

    i_r = findfirstunique(x.regions.names, r)

    demand = sum(x.regions.load[i_r, :])

    estimate = if demand > 0
        div(MeanEstimate(x[r]), demand/1e6)
    else
        MeanEstimate(0.)
    end

    return NEUE(estimate)

end

function finalize(
    acc::ShortfallSamplesAccumulator{S},
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E,S<:Union{ShortfallSamples,DemandResponseShortfallSamples}}

    return ShortfallSamplesResult{N,L,T,P,E,S}(
        system.regions, system.timestamps, acc.shortfall)

end

function _count_dropped_days_by_sample(flags_by_period_sample, day_ids)
    nperiods, nsamples = size(flags_by_period_sample)
    counts = zeros(Int, nsamples)

    isempty(day_ids) && return counts

    for s in 1:nsamples
        current_day = day_ids[1]
        day_has_shortfall = false
        dropped_days = 0

        for t in 1:nperiods
            if day_ids[t] != current_day
                dropped_days += day_has_shortfall
                current_day = day_ids[t]
                day_has_shortfall = false
            end

            day_has_shortfall |= flags_by_period_sample[t, s]
        end

        dropped_days += day_has_shortfall
        counts[s] = dropped_days
    end

    return counts
end

function LOLD(x::ShortfallSamplesResult)
    flags = dropdims(sum(x.shortfall, dims=1) .> 0, dims=1)
    daycounts = _count_dropped_days_by_sample(flags, _day_ids(x.timestamps))
    return LOLD{_ndays(x.timestamps)}(MeanEstimate(daycounts))
end

function LOLD(x::ShortfallSamplesResult, r::AbstractString)
    i_r = findfirstunique(x.regions.names, r)
    flags = Matrix(view(x.shortfall, i_r, :, :) .> 0)
    daycounts = _count_dropped_days_by_sample(flags, _day_ids(x.timestamps))
    return LOLD{_ndays(x.timestamps)}(MeanEstimate(daycounts))
end

function LOLD(x::ShortfallSamplesResult, d::Date)
    dayrange = _day_range(x.timestamps, d)

    # day_slice has shape: region × day_timestamps × sample
    day_slice = view(x.shortfall, :, dayrange, :)

    # For each sample, event occurs if any region has any shortfall in any timestep of the day
    eventdays = vec(dropdims(any(day_slice .> 0, dims=(1, 2)), dims=(1, 2)))

    return LOLD{1}(MeanEstimate(eventdays))
end

function LOLD(x::ShortfallSamplesResult, r::AbstractString, d::Date)
    i_r = findfirstunique(x.regions.names, r)
    dayrange = _day_range(x.timestamps, d)

    region_day_slice = view(x.shortfall, i_r, dayrange, :)

    # For each sample, did this region have any shortfall during the day?
    eventdays = vec(dropdims(any(region_day_slice .> 0, dims=1), dims=1))

    return LOLD{1}(MeanEstimate(eventdays))
end
