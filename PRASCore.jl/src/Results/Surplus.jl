"""
    Surplus

The `Surplus` result specification reports unused generation and storage
discharge capability of `Regions`, producing a `SurplusResult`.

A `SurplusResult` can be indexed by region name and timestamp to retrieve
a tuple of sample mean and standard deviation, estimating the average
unused capacity in that region and timestep.

Example:

```julia
surplus, =
    assess(sys, SequentialMonteCarlo(samples=1000), Surplus())

surplus_mean, surplus_std =
    surplus["Region A", ZonedDateTime(2020, 1, 1, 0, tz"UTC")]
```

See [`SurplusSamples`](@ref) for sample-level surplus results.
"""
struct Surplus <: ResultSpec end

mutable struct SurplusAccumulator <: ResultAccumulator{Surplus}

    # Cross-simulation surplus mean/variances
    surplus_period::Vector{MeanVariance}
    surplus_regionperiod::Matrix{MeanVariance}

end

function accumulator(
    sys::SystemModel{N}, nsamples::Int, ::Surplus
) where {N}

    nregions = length(sys.regions)

    surplus_period = [meanvariance() for _ in 1:N]
    surplus_regionperiod = [meanvariance() for _ in 1:nregions, _ in 1:N]

    return SurplusAccumulator(
        surplus_period, surplus_regionperiod)

end

function merge!(
    x::SurplusAccumulator, y::SurplusAccumulator
)

    foreach(merge!, x.surplus_period, y.surplus_period)
    foreach(merge!, x.surplus_regionperiod, y.surplus_regionperiod)

    return

end

accumulatortype(::Surplus) = SurplusAccumulator

struct SurplusResult{N,L,T<:Period,P<:PowerUnit} <: AbstractSurplusResult{N,L,T}

    nsamples::Union{Int,Nothing}
    regions::Vector{String}
    timestamps::AbstractVector{ZonedDateTime}

    surplus_mean::Matrix{Float64}

    surplus_period_std::Vector{Float64}
    surplus_regionperiod_std::Matrix{Float64}

end

function getindex(x::SurplusResult, t::ZonedDateTime)
    i_t = findfirstunique(x.timestamps, t)
    return sum(view(x.surplus_mean, :, i_t)), x.surplus_period_std[i_t]
end

function getindex(x::SurplusResult, r::AbstractString, t::ZonedDateTime)
    i_r = findfirstunique(x.regions, r)
    i_t = findfirstunique(x.timestamps, t)
    return x.surplus_mean[i_r, i_t], x.surplus_regionperiod_std[i_r, i_t]
end

function finalize(
    acc::SurplusAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    _, period_std = mean_std(acc.surplus_period)
    regionperiod_mean, regionperiod_std = mean_std(acc.surplus_regionperiod)

    nsamples = first(first(acc.surplus_period).stats).n

    return SurplusResult{N,L,T,P}(
        nsamples, system.regions.names, system.timestamps,
        regionperiod_mean, period_std, regionperiod_std)

end
