"""
    DemandResponseEnergySamples

The `DemandResponseEnergySamples` result specification reports the sample-level state
of borrowed energy of `DemandResponses`, producing a `DemandResponseEnergySamplesResult`.

A `DemandResponseEnergySamplesResult` can be indexed by demand response device name and
a timestamp to retrieve a vector of sample-level borrowed energy states for
the device in the given timestep.

Example:

```julia
demandresponseenergy, =
    assess(sys, SequentialMonteCarlo(samples=10), DemandResponseEnergySamples())

samples = demandresponseenergy["MyDemandResponse123", ZonedDateTime(2020, 1, 1, 0, tz"UTC")]

@assert samples isa Vector{Float64}
@assert length(samples) == 10
```

Note that this result specification requires large amounts of memory for
larger sample sizes. See [`DemandResponseEnergy`](@ref) for estimated average demand response
borrowed energy when sample-level granularity isn't required.
"""
struct DemandResponseEnergySamples <: ResultSpec end

struct DemandResponseEnergySamplesAccumulator <: ResultAccumulator{DemandResponseEnergySamples}

    energy::Array{Float64,3}

end

function accumulator(
    sys::SystemModel{N}, nsamples::Int, ::DemandResponseEnergySamples
) where {N}

    ndrs = length(sys.demandresponses)
    energy = zeros(Int, ndrs, N, nsamples)

    return DemandResponseEnergySamplesAccumulator(energy)

end

function merge!(
    x::DemandResponseEnergySamplesAccumulator, y::DemandResponseEnergySamplesAccumulator
)

    x.energy .+= y.energy
    return

end

accumulatortype(::DemandResponseEnergySamples) = DemandResponseEnergySamplesAccumulator

struct DemandResponseEnergySamplesResult{N,L,T<:Period,E<:EnergyUnit} <: AbstractEnergyResult{N,L,T}

    demandresponses::Vector{String}
    timestamps::StepRange{ZonedDateTime,T}

    energy::Array{Int,3}

end

names(x::DemandResponseEnergySamplesResult) = x.demandresponses

function getindex(x::DemandResponseEnergySamplesResult, t::ZonedDateTime)
    i_t = findfirstunique(x.timestamps, t)
    return vec(sum(view(x.energy, :, i_t, :), dims=1))
end

function getindex(x::DemandResponseEnergySamplesResult, s::AbstractString, t::ZonedDateTime)
    i_dr = findfirstunique(x.demandresponses, s)
    i_t = findfirstunique(x.timestamps, t)
    return vec(x.energy[i_dr, i_t, :])
end

function finalize(
    acc::DemandResponseEnergySamplesAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    return DemandResponseEnergySamplesResult{N,L,T,E}(
        system.demandresponses.names, system.timestamps, acc.energy)

end
