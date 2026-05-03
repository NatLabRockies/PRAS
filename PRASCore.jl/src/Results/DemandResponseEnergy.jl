"""
    DemandResponseEnergy

The `DemandResponseEnergy` result specification reports the average energy borrowed
of `DemandResponses`, producing a `DemandResponseEnergyResult`.

A `DemandResponseEnergyResult` can be indexed by demand response device name and a timestamp to
retrieve a tuple of sample mean and standard deviation, estimating the average
energy borrowed level for the given demand response device in that timestep.

Example:

```julia
drenergy, =
    assess(sys, SequentialMonteCarlo(samples=1000), DemandResponseEnergy())

soc_mean, soc_std =
    drenergy["MyDemandResponse123", ZonedDateTime(2020, 1, 1, 0, tz"UTC")]
```

See [`DemandResponseEnergySamples`](@ref) for sample-level demand response states of borrowed energy.
"""
struct DemandResponseEnergy <: ResultSpec end

mutable struct DemandResponseEnergyAccumulator <: ResultAccumulator{DemandResponseEnergy}

    # Cross-simulation energy mean/variances
    energy_period::Vector{MeanVariance}
    energy_demandresponseperiod::Matrix{MeanVariance}

end

function accumulator(
    sys::SystemModel{N}, nsamples::Int, ::DemandResponseEnergy
) where {N}

    ndemandresponses = length(sys.demandresponses)

    energy_period = [meanvariance() for _ in 1:N]
    energy_demandresponseperiod = [meanvariance() for _ in 1:ndemandresponses, _ in 1:N]

    return DemandResponseEnergyAccumulator(
        energy_period, energy_demandresponseperiod)

end

function merge!(
    x::DemandResponseEnergyAccumulator, y::DemandResponseEnergyAccumulator
)

    foreach(merge!, x.energy_period, y.energy_period)
    foreach(merge!, x.energy_demandresponseperiod, y.energy_demandresponseperiod)

    return

end

accumulatortype(::DemandResponseEnergy) = DemandResponseEnergyAccumulator

struct DemandResponseEnergyResult{N,L,T<:Period,E<:EnergyUnit} <: AbstractEnergyResult{N,L,T}

    nsamples::Union{Int,Nothing}
    demandresponses::Vector{String}
    timestamps::StepRange{ZonedDateTime,T}

    energy_mean::Matrix{Float64}

    energy_period_std::Vector{Float64}
    energy_regionperiod_std::Matrix{Float64}

end

names(x::DemandResponseEnergyResult) = x.demandresponses

function getindex(x::DemandResponseEnergyResult, t::ZonedDateTime)
    i_t = findfirstunique(x.timestamps, t)
    return sum(view(x.energy_mean, :, i_t)), x.energy_period_std[i_t]
end

function getindex(x::DemandResponseEnergyResult, s::AbstractString, t::ZonedDateTime)
    i_dr = findfirstunique(x.demandresponses, s)
    i_t = findfirstunique(x.timestamps, t)
    return x.energy_mean[i_dr, i_t], x.energy_regionperiod_std[i_dr, i_t]
end

function finalize(
    acc::DemandResponseEnergyAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    _, period_std = mean_std(acc.energy_period)
    demandresponseperiod_mean, demandresponseperiod_std = mean_std(acc.energy_demandresponseperiod)

    nsamples = first(first(acc.energy_period).stats).n

    return DemandResponseEnergyResult{N,L,T,E}(
        nsamples, system.demandresponses.names, system.timestamps,
        demandresponseperiod_mean, period_std, demandresponseperiod_std)

end
