"""
    DemandResponseEnergyUsage

The `DemandResponseEnergyUsage` result specification reports the average
cumulative activated energy of `DemandResponses`, producing a
`DemandResponseEnergyUsageResult`.

A `DemandResponseEnergyUsageResult` can be indexed by demand response device
name and a timestamp to retrieve a tuple of sample mean and standard deviation
for cumulative usage through that timestep.

Usage counts borrowing from the start of each sample in the system's energy
units, before efficiency adjustments.
Initial borrowed energy is excluded.
Repayment, debt decay and outages do not reduce usage.
Total horizon usage is the final value, not the sum over timestamps.

Example:

```julia
usage, =
    assess(sys, SequentialMonteCarlo(samples=1000), DemandResponseEnergyUsage())

usage_mean, usage_std =
    usage["MyDemandResponse123", ZonedDateTime(2020, 1, 1, 0, tz"UTC")]
```

See [`DemandResponseEnergyUsageSamples`](@ref) for sample-level cumulative
usage.

See [`DemandResponseEnergy`](@ref) for outstanding borrowed energy rather than
cumulative usage.
"""
struct DemandResponseEnergyUsage <: ResultSpec end

mutable struct DemandResponseEnergyUsageAccumulator <: ResultAccumulator{DemandResponseEnergyUsage}

    # Cross-simulation cumulative energy mean/variances
    energy_period::Vector{MeanVariance}
    energy_demandresponseperiod::Matrix{MeanVariance}

end

function accumulator(
    sys::SystemModel{N}, nsamples::Int, ::DemandResponseEnergyUsage
) where {N}

    ndemandresponses = length(sys.demandresponses)

    energy_period = [meanvariance() for _ in 1:N]
    energy_demandresponseperiod = [meanvariance() for _ in 1:ndemandresponses, _ in 1:N]

    return DemandResponseEnergyUsageAccumulator(
        energy_period, energy_demandresponseperiod)

end

function merge!(
    x::DemandResponseEnergyUsageAccumulator, y::DemandResponseEnergyUsageAccumulator
)

    foreach(merge!, x.energy_period, y.energy_period)
    foreach(merge!, x.energy_demandresponseperiod, y.energy_demandresponseperiod)

    return

end

accumulatortype(::DemandResponseEnergyUsage) = DemandResponseEnergyUsageAccumulator

struct DemandResponseEnergyUsageResult{N,L,T<:Period,E<:EnergyUnit} <: AbstractEnergyResult{N,L,T}

    nsamples::Union{Int,Nothing}
    demandresponses::Vector{String}
    timestamps::StepRange{ZonedDateTime,T}

    energy_mean::Matrix{Float64}

    energy_period_std::Vector{Float64}
    energy_regionperiod_std::Matrix{Float64}

end

names(x::DemandResponseEnergyUsageResult) = x.demandresponses

function getindex(x::DemandResponseEnergyUsageResult, t::ZonedDateTime)
    i_t = findfirstunique(x.timestamps, t)
    return sum(view(x.energy_mean, :, i_t)), x.energy_period_std[i_t]
end

function getindex(x::DemandResponseEnergyUsageResult, s::AbstractString, t::ZonedDateTime)
    i_dr = findfirstunique(x.demandresponses, s)
    i_t = findfirstunique(x.timestamps, t)
    return x.energy_mean[i_dr, i_t], x.energy_regionperiod_std[i_dr, i_t]
end

function finalize(
    acc::DemandResponseEnergyUsageAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    _, period_std = mean_std(acc.energy_period)
    demandresponseperiod_mean, demandresponseperiod_std = mean_std(acc.energy_demandresponseperiod)

    nsamples = first(first(acc.energy_period).stats).n

    return DemandResponseEnergyUsageResult{N,L,T,E}(
        nsamples, system.demandresponses.names, system.timestamps,
        demandresponseperiod_mean, period_std, demandresponseperiod_std)

end
