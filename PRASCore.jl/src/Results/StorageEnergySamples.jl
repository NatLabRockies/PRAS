"""
    StorageEnergySamples

The `StorageEnergySamples` result specification reports the sample-level state
of charge of `Storages`, producing a `StorageEnergySamplesResult`.

A `StorageEnergySamplesResult` can be indexed by storage device name and
a timestamp to retrieve a vector of sample-level charge states for
the device in the given timestep.

Example:

```julia
storenergy, =
    assess(sys, SequentialMonteCarlo(samples=10), StorageEnergySamples())

samples = storenergy["MyStorage123", ZonedDateTime(2020, 1, 1, 0, tz"UTC")]

@assert samples isa Vector{Float64}
@assert length(samples) == 10
```

Note that this result specification requires large amounts of memory for
larger sample sizes. See [`StorageEnergy`](@ref) for estimated average storage
state of charge when sample-level granularity isn't required.
"""
struct StorageEnergySamples <: ResultSpec end

struct StorageEnergySamplesAccumulator <: ResultAccumulator{StorageEnergySamples}

    energy::Array{Float64,3}

end

function accumulator(
    sys::SystemModel{N}, nsamples::Int, ::StorageEnergySamples
) where {N}

    nstors = length(sys.storages)
    energy = zeros(Int, nstors, N, nsamples)

    return StorageEnergySamplesAccumulator(energy)

end

function merge!(
    x::StorageEnergySamplesAccumulator, y::StorageEnergySamplesAccumulator
)

    x.energy .+= y.energy
    return

end

accumulatortype(::StorageEnergySamples) = StorageEnergySamplesAccumulator

struct StorageEnergySamplesResult{N,L,T<:Period,E<:EnergyUnit} <: AbstractEnergyResult{N,L,T}

    storages::Vector{String}
    timestamps::AbstractVector{ZonedDateTime}

    energy::Array{Int,3}

end

names(x::StorageEnergySamplesResult) = x.storages

function getindex(x::StorageEnergySamplesResult, t::ZonedDateTime)
    i_t = findfirstunique(x.timestamps, t)
    return vec(sum(view(x.energy, :, i_t, :), dims=1))
end

function getindex(x::StorageEnergySamplesResult, s::AbstractString, t::ZonedDateTime)
    i_s = findfirstunique(x.storages, s)
    i_t = findfirstunique(x.timestamps, t)
    return vec(x.energy[i_s, i_t, :])
end

function finalize(
    acc::StorageEnergySamplesAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    return StorageEnergySamplesResult{N,L,T,E}(
        system.storages.names, system.timestamps, acc.energy)

end
