"""
    DemandResponseEnergyUsageSamples

The `DemandResponseEnergyUsageSamples` result specification reports
sample-level cumulative activated energy of `DemandResponses`, producing a
`DemandResponseEnergyUsageSamplesResult`.

A `DemandResponseEnergyUsageSamplesResult` can be indexed by demand response
device name and a timestamp to retrieve a vector of sample-level cumulative
usage through that timestep.

Usage follows the same cumulative accounting as
[`DemandResponseEnergyUsage`](@ref).
Total horizon usage is the final value, not the sum over timestamps.

Example:

```julia
usage, =
    assess(sys, SequentialMonteCarlo(samples=10), DemandResponseEnergyUsageSamples())

samples = usage["MyDemandResponse123", ZonedDateTime(2020, 1, 1, 0, tz"UTC")]

@assert samples isa Vector{Float64}
@assert length(samples) == 10
```

Note that this result specification requires large amounts of memory for
larger sample sizes.
See [`DemandResponseEnergyUsage`](@ref) for estimated average cumulative usage
when sample-level granularity isn't required.

See [`DemandResponseEnergySamples`](@ref) for outstanding borrowed energy
rather than cumulative usage.
"""
struct DemandResponseEnergyUsageSamples <: ResultSpec end

struct DemandResponseEnergyUsageSamplesAccumulator <: ResultAccumulator{DemandResponseEnergyUsageSamples}

    energy::Array{Float64,3}

end

sampledata(acc::DemandResponseEnergyUsageSamplesAccumulator) = acc.energy
usesamplepartitions(::DemandResponseEnergyUsageSamples) = true

function accumulator(
    sys::SystemModel{N}, nsamples::Int, ::DemandResponseEnergyUsageSamples
) where {N}

    ndrs = length(sys.demandresponses)
    energy = zeros(Float64, ndrs, N, nsamples)

    return DemandResponseEnergyUsageSamplesAccumulator(energy)

end

function merge!(
    x::DemandResponseEnergyUsageSamplesAccumulator, y::DemandResponseEnergyUsageSamplesAccumulator
)

    x.energy .+= y.energy
    return

end

accumulatortype(::DemandResponseEnergyUsageSamples) = DemandResponseEnergyUsageSamplesAccumulator

struct DemandResponseEnergyUsageSamplesResult{N,L,T<:Period,E<:EnergyUnit} <: AbstractEnergyResult{N,L,T}

    demandresponses::Vector{String}
    timestamps::StepRange{ZonedDateTime,T}

    energy::Array{Float64,3}

end

names(x::DemandResponseEnergyUsageSamplesResult) = x.demandresponses

function getindex(x::DemandResponseEnergyUsageSamplesResult, t::ZonedDateTime)
    i_t = findfirstunique(x.timestamps, t)
    return vec(sum(view(x.energy, :, i_t, :), dims=1))
end

function getindex(x::DemandResponseEnergyUsageSamplesResult, s::AbstractString, t::ZonedDateTime)
    i_dr = findfirstunique(x.demandresponses, s)
    i_t = findfirstunique(x.timestamps, t)
    return vec(x.energy[i_dr, i_t, :])
end

function finalize(
    acc::DemandResponseEnergyUsageSamplesAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    return DemandResponseEnergyUsageSamplesResult{N,L,T,E}(
        system.demandresponses.names, system.timestamps, acc.energy)

end
