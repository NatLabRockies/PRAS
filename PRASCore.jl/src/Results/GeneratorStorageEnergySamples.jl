"""
    GeneratorStorageEnergySamples

The `GeneratorStorageEnergySamples` result specification reports the
sample-level state of charge of `GeneratorStorages`, producing a
`GeneratorStorageEnergySamplesResult`.

A `GeneratorStorageEnergySamplesResult` can be indexed by generator-storage
device name and a timestamp to retrieve a vector of sample-level charge states
for the device in the given timestep.

Example:

```julia
genstorenergy, =
    assess(sys, SequentialMonteCarlo(samples=10), GeneratorStorageEnergySamples())

samples = genstorenergy["MyGeneratorStorage123", ZonedDateTime(2020, 1, 1, 0, tz"UTC")]

@assert samples isa Vector{Float64}
@assert length(samples) == 10
```

Note that this result specification requires large amounts of memory for
larger sample sizes. See [`GeneratorStorageEnergy`](@ref) for estimated average
generator-storage state of charge when sample-level granularity isn't required.
"""
struct GeneratorStorageEnergySamples <: ResultSpec end

struct GenStorageEnergySamplesAccumulator <: ResultAccumulator{GeneratorStorageEnergySamples}

    energy::Array{Float64,3}

end

function accumulator(
    sys::SystemModel{N}, nsamples::Int, ::GeneratorStorageEnergySamples
) where {N}

    ngenstors = length(sys.generatorstorages)
    energy = zeros(Int, ngenstors, N, nsamples)

    return GenStorageEnergySamplesAccumulator(energy)

end

function merge!(
    x::GenStorageEnergySamplesAccumulator,
    y::GenStorageEnergySamplesAccumulator
)

    x.energy .+= y.energy
    return

end

accumulatortype(::GeneratorStorageEnergySamples) = GenStorageEnergySamplesAccumulator

struct GeneratorStorageEnergySamplesResult{N,L,T<:Period,E<:EnergyUnit} <: AbstractEnergyResult{N,L,T}

    generatorstorages::Vector{String}
    timestamps::AbstractVector{ZonedDateTime}

    energy::Array{Int,3}

end

names(x::GeneratorStorageEnergySamplesResult) = x.generatorstorages

function getindex(x::GeneratorStorageEnergySamplesResult, t::ZonedDateTime)
    i_t = findfirstunique(x.timestamps, t)
    return vec(sum(view(x.energy, :, i_t, :), dims=1))
end

function getindex(x::GeneratorStorageEnergySamplesResult, gs::AbstractString, t::ZonedDateTime)
    i_gs = findfirstunique(x.generatorstorages, gs)
    i_t = findfirstunique(x.timestamps, t)
    return vec(x.energy[i_gs, i_t, :])
end

function finalize(
    acc::GenStorageEnergySamplesAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    return GeneratorStorageEnergySamplesResult{N,L,T,E}(
        system.generatorstorages.names, system.timestamps, acc.energy)

end
