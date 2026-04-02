"""
    Shortfall

The `Shortfall` result specification reports expectation-based resource
adequacy risk metrics such as EUE and LOLE, producing a `ShortfallResult`.

A `ShortfallResult` can be directly indexed by a region name and a timestamp to retrieve a tuple of sample mean and standard deviation, estimating
 the average unserved energy in that region and timestep. However, in most
cases it's simpler to use [`EUE`](@ref) and [`LOLE`](@ref) constructors to
directly retrieve standard risk metrics.

Example:

```julia
shortfall, =
    assess(sys, SequentialMonteCarlo(samples=1000), Shortfall())

period = ZonedDateTime(2020, 1, 1, 0, tz"UTC")

# Unserved energy mean and standard deviation
sf_mean, sf_std = shortfall["Region A", period]

# System-wide risk metrics
eue = EUE(shortfall)
lole = LOLE(shortfall)
neue = NEUE(shorfall)

# Regional risk metrics
regional_eue = EUE(shortfall, "Region A")
regional_lole = LOLE(shortfall, "Region A")
regional_neue = NEUE(shortfall, "Region A")

# Period-specific risk metrics
period_eue = EUE(shortfall, period)
period_lolp = LOLE(shortfall, period)

# Region- and period-specific risk metrics
period_eue = EUE(shortfall, "Region A", period)
period_lolp = LOLE(shortfall, "Region A", period)
```

See [`ShortfallSamples`](@ref) for recording sample-level shortfall results.
"""
struct Shortfall <: ResultSpec end

struct DemandResponseShortfall <: ResultSpec end

mutable struct ShortfallAccumulator{S} <: ResultAccumulator{Shortfall}

    # Cross-simulation LOL period count mean/variances
    periodsdropped_total::MeanVariance
    periodsdropped_region::Vector{MeanVariance}
    periodsdropped_period::Vector{MeanVariance}
    periodsdropped_regionperiod::Matrix{MeanVariance}

    # Running LOL period counts for current simulation
    periodsdropped_total_currentsim::Int
    periodsdropped_region_currentsim::Vector{Int}

    # Cross-simulation UE mean/variances
    unservedload_total::MeanVariance
    unservedload_region::Vector{MeanVariance}
    unservedload_period::Vector{MeanVariance}
    unservedload_regionperiod::Matrix{MeanVariance}

    # Running UE totals for current simulation
    unservedload_total_currentsim::Int
    unservedload_region_currentsim::Vector{Int}

    # Sample-level UE for current simulation
    unservedload_sample::Vector{Int}
    unservedload_region_sample::Matrix{Int}

end

function accumulator(
    sys::SystemModel{N}, nsamples::Int, ::S
) where {N,S<:Union{Shortfall,DemandResponseShortfall}}

    nregions = length(sys.regions)

    periodsdropped_total = meanvariance()
    periodsdropped_region = [meanvariance() for _ in 1:nregions]
    periodsdropped_period = [meanvariance() for _ in 1:N]
    periodsdropped_regionperiod = [meanvariance() for _ in 1:nregions, _ in 1:N]

    periodsdropped_total_currentsim = 0
    periodsdropped_region_currentsim = zeros(Int, nregions)

    unservedload_total = meanvariance()
    unservedload_region = [meanvariance() for _ in 1:nregions]
    unservedload_period = [meanvariance() for _ in 1:N]
    unservedload_regionperiod = [meanvariance() for _ in 1:nregions, _ in 1:N]

    unservedload_total_currentsim = 0
    unservedload_region_currentsim = zeros(Int, nregions)
    unservedload_sample = zeros(Int, nsamples)
    unservedload_region_sample = zeros(Int, nregions, nsamples)

    return ShortfallAccumulator{S}(
        periodsdropped_total, periodsdropped_region,
        periodsdropped_period, periodsdropped_regionperiod,
        periodsdropped_total_currentsim, periodsdropped_region_currentsim,
        unservedload_total, unservedload_region,
        unservedload_period, unservedload_regionperiod,
        unservedload_total_currentsim, unservedload_region_currentsim,
        unservedload_sample, unservedload_region_sample)

end

function merge!(
    x::ShortfallAccumulator, y::ShortfallAccumulator
)

    merge!(x.periodsdropped_total, y.periodsdropped_total)
    foreach(merge!, x.periodsdropped_region, y.periodsdropped_region)
    foreach(merge!, x.periodsdropped_period, y.periodsdropped_period)
    foreach(merge!, x.periodsdropped_regionperiod, y.periodsdropped_regionperiod)

    merge!(x.unservedload_total, y.unservedload_total)
    foreach(merge!, x.unservedload_region, y.unservedload_region)
    foreach(merge!, x.unservedload_period, y.unservedload_period)
    foreach(merge!, x.unservedload_regionperiod, y.unservedload_regionperiod)

    x.unservedload_sample .+= y.unservedload_sample
    x.unservedload_region_sample .+= y.unservedload_region_sample

    return

end

accumulatortype(::S) where {
        S<:Union{Shortfall,DemandResponseShortfall}
    } = ShortfallAccumulator{S}

struct ShortfallResult{N, L, T <: Period, E <: EnergyUnit, S} <:
       AbstractShortfallResult{N, L, T}
    nsamples::Union{Int, Nothing}
    regions::Regions
    timestamps::StepRange{ZonedDateTime,T}

    eventperiod_mean::Float64
    eventperiod_std::Float64

    eventperiod_region_mean::Vector{Float64}
    eventperiod_region_std::Vector{Float64}

    eventperiod_period_mean::Vector{Float64}
    eventperiod_period_std::Vector{Float64}

    eventperiod_regionperiod_mean::Matrix{Float64}
    eventperiod_regionperiod_std::Matrix{Float64}

    shortfall_mean::Matrix{Float64} # r x t

    shortfall_std::Float64
    shortfall_region_std::Vector{Float64}
    shortfall_period_std::Vector{Float64}
    shortfall_regionperiod_std::Matrix{Float64}

    shortfall_samples::Vector{Float64}
    shortfall_region_samples::Matrix{Float64}

    function ShortfallResult{N,L,T,E,S}(
        nsamples::Union{Int,Nothing},
        regions::Regions,
        timestamps::StepRange{ZonedDateTime,T},
        eventperiod_mean::Float64,
        eventperiod_std::Float64,
        eventperiod_region_mean::Vector{Float64},
        eventperiod_region_std::Vector{Float64},
        eventperiod_period_mean::Vector{Float64},
        eventperiod_period_std::Vector{Float64},
        eventperiod_regionperiod_mean::Matrix{Float64},
        eventperiod_regionperiod_std::Matrix{Float64},
        shortfall_mean::Matrix{Float64},
        shortfall_std::Float64,
        shortfall_region_std::Vector{Float64},
        shortfall_period_std::Vector{Float64},
        shortfall_regionperiod_std::Matrix{Float64},
        shortfall_samples::Vector{Float64},
        shortfall_region_samples::Matrix{Float64},
    ) where {N,L,T<:Period,E<:EnergyUnit,S <: Union{Shortfall,DemandResponseShortfall}}

        isnothing(nsamples) || nsamples > 0 ||
            throw(DomainError("Sample count must be positive or `nothing`."))


        length(timestamps) == N ||
            error("The provided timestamp range does not match the simulation length")

        nregions = length(regions.names)

        length(eventperiod_region_mean) == nregions &&
        length(eventperiod_region_std) == nregions &&
        length(eventperiod_period_mean) == N &&
        length(eventperiod_period_std) == N &&
        size(eventperiod_regionperiod_mean) == (nregions, N) &&
        size(eventperiod_regionperiod_std) == (nregions, N) &&
        length(shortfall_region_std) == nregions &&
        length(shortfall_period_std) == N &&
        size(shortfall_regionperiod_std) == (nregions, N) &&
        size(shortfall_samples) == (nsamples,) &&
        size(shortfall_region_samples) == (nregions, nsamples) ||
            error("Inconsistent input data sizes")

        new{N,L,T,E,S}(nsamples, regions, timestamps,
            eventperiod_mean, eventperiod_std,
            eventperiod_region_mean, eventperiod_region_std,
            eventperiod_period_mean, eventperiod_period_std,
            eventperiod_regionperiod_mean, eventperiod_regionperiod_std,
            shortfall_mean, shortfall_std,
            shortfall_region_std, shortfall_period_std,
            shortfall_regionperiod_std, shortfall_samples,
            shortfall_region_samples)

    end

end

function getindex(x::ShortfallResult)
    return sum(x.shortfall_mean), x.shortfall_std
end

function getindex(x::ShortfallResult, r::AbstractString)
    i_r = findfirstunique(x.regions.names, r)
    return sum(view(x.shortfall_mean, i_r, :)), x.shortfall_region_std[i_r]
end

function getindex(x::ShortfallResult, t::ZonedDateTime)  
    i_t = findfirstunique(x.timestamps, t)
    return sum(view(x.shortfall_mean, :, i_t)), x.shortfall_period_std[i_t]
end

function getindex(x::ShortfallResult, r::AbstractString, t::ZonedDateTime)  
    i_r = findfirstunique(x.regions.names, r)
    i_t = findfirstunique(x.timestamps, t)
    return x.shortfall_mean[i_r, i_t], x.shortfall_regionperiod_std[i_r, i_t]
end


LOLE(x::ShortfallResult{N,L,T}) where {N,L,T} =
    LOLE{N,L,T}(MeanEstimate(x.eventperiod_mean,
                             x.eventperiod_std,
                             x.nsamples))

function LOLE(x::ShortfallResult{N,L,T}, r::AbstractString) where {N,L,T}
    i_r = findfirstunique(x.regions.names, r)
    return LOLE{N,L,T}(MeanEstimate(x.eventperiod_region_mean[i_r],
                                    x.eventperiod_region_std[i_r],
                                    x.nsamples))
end

function LOLE(x::ShortfallResult{N,L,T}, t::ZonedDateTime) where {N,L,T}
    i_t = findfirstunique(x.timestamps, t)
    return LOLE{1,L,T}(MeanEstimate(x.eventperiod_period_mean[i_t],
                                    x.eventperiod_period_std[i_t],
                                    x.nsamples))
end

function LOLE(x::ShortfallResult{N,L,T}, r::AbstractString, t::ZonedDateTime) where {N,L,T}
    i_r = findfirstunique(x.regions.names, r)
    i_t = findfirstunique(x.timestamps, t)
    return LOLE{1,L,T}(MeanEstimate(x.eventperiod_regionperiod_mean[i_r, i_t],
                                    x.eventperiod_regionperiod_std[i_r, i_t],
                                    x.nsamples))
end


EUE(x::ShortfallResult{N,L,T,E}) where {N,L,T,E} =
    EUE{N,L,T,E}(MeanEstimate(x[]..., x.nsamples))

EUE(x::ShortfallResult{N,L,T,E}, r::AbstractString) where {N,L,T,E} =
    EUE{N,L,T,E}(MeanEstimate(x[r]..., x.nsamples))

EUE(x::ShortfallResult{N,L,T,E}, t::ZonedDateTime) where {N,L,T,E} =
    EUE{1,L,T,E}(MeanEstimate(x[t]..., x.nsamples))

EUE(x::ShortfallResult{N,L,T,E}, r::AbstractString, t::ZonedDateTime) where {N,L,T,E} =
    EUE{1,L,T,E}(MeanEstimate(x[r, t]..., x.nsamples))

function NEUE(x::ShortfallResult)  

    demand = sum(x.regions.load)

    estimate = if demand > 0
        div(MeanEstimate(x[]..., x.nsamples), demand/1e6)
    else
        MeanEstimate(0.)
    end

    return NEUE(estimate)

end

function NEUE(x::ShortfallResult, r::AbstractString) 

    i_r = findfirstunique(x.regions.names, r)

    demand = sum(x.regions.load[i_r, :])

    estimate = if demand > 0
        div(MeanEstimate(x[r]..., x.nsamples), demand/1e6)
    else
        MeanEstimate(0.)
    end

    return NEUE(estimate)

end

function CVAR(unit::Type{U}, x::ShortfallResult{N,L,T,E}, alpha::Float64) where {N,L,T,E,U<:EnergyUnit}

    estimate = x.shortfall_samples
    var = quantile(estimate, alpha)
    tail_losses = estimate[estimate .>= var]

    cvar = if !isempty(tail_losses)
        MeanEstimate(tail_losses)
    else
        MeanEstimate(0.)
    end                                                           

    return CVAR{N,L,T,E}(unit, cvar, alpha, var)
  
end


function CVAR(unit::Type{U}, x::ShortfallResult{N,L,T,E}, alpha::Float64, r::AbstractString) where {N,L,T,E,U<:EnergyUnit}

    i_r = findfirstunique(x.regions.names, r)
    estimate = x.shortfall_region_samples[i_r, :]
    var = quantile(estimate, alpha)
    tail_losses = estimate[estimate .>= var]

    cvar = if !isempty(tail_losses)
        MeanEstimate(tail_losses)
    else
        MeanEstimate(0.)
    end

    return CVAR{N,L,T,E}(unit, cvar, alpha, var)
  
end

function NCVAR(x::ShortfallResult{N,L,T,E}, cvar::CVAR) where {N,L,T,E}
    demand = sum(x.regions.load)

    if demand > 0
        ncvar = div(cvar.cvar, demand/1e6)
        var = div(cvar.var, demand/1e6)
    else
        ncvar = MeanEstimate(0.)
        var = MeanEstimate(0.)
    end

    return NCVAR(ncvar, cvar.alpha, var)
  
end

function NCVAR(x::ShortfallResult{N,L,T,E}, cvar::CVAR, r::AbstractString) where {N,L,T,E}
    i_r = findfirstunique(x.regions.names, r)
    demand = sum(x.regions.load[i_r, :])

    if demand > 0
        ncvar = div(cvar.cvar, demand/1e6)
        var = div(cvar.var, demand/1e6)
    else
        ncvar = MeanEstimate(0.)
        var = MeanEstimate(0.)
    end

    return NCVAR(ncvar, cvar.alpha, var)
  
end

function finalize(
    acc::ShortfallAccumulator{S},
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E,S}

    ep_total_mean, ep_total_std = mean_std(acc.periodsdropped_total)
    ep_region_mean, ep_region_std = mean_std(acc.periodsdropped_region)
    ep_period_mean, ep_period_std = mean_std(acc.periodsdropped_period)
    ep_regionperiod_mean, ep_regionperiod_std =
        mean_std(acc.periodsdropped_regionperiod)

    _, ue_total_std = mean_std(acc.unservedload_total)
    _, ue_region_std = mean_std(acc.unservedload_region)
    _, ue_period_std = mean_std(acc.unservedload_period)
    ue_regionperiod_mean, ue_regionperiod_std =
        mean_std(acc.unservedload_regionperiod)

    nsamples = first(acc.unservedload_total.stats).n

    p2e = conversionfactor(L,T,P,E)
    ue_regionperiod_mean .*= p2e
    ue_total_std *= p2e
    ue_region_std .*= p2e
    ue_period_std .*= p2e
    ue_regionperiod_std .*= p2e
    ue_sample = float(acc.unservedload_sample .* p2e)
    ue_region_sample = float(acc.unservedload_region_sample .* p2e)

    return ShortfallResult{N,L,T,E,S}(
        nsamples, system.regions, system.timestamps,
        ep_total_mean, ep_total_std, ep_region_mean, ep_region_std,
        ep_period_mean, ep_period_std,
        ep_regionperiod_mean, ep_regionperiod_std,
        ue_regionperiod_mean, ue_total_std,
        ue_region_std, ue_period_std, ue_regionperiod_std,
        ue_sample, ue_region_sample, )

end
