"""
    GeneratorStorageAvailability

The `GeneratorStorageAvailability` result specification reports the sample-level
discrete availability of `GeneratorStorages`, producing a
`GeneratorStorageAvailabilityResult`.

A `GeneratorStorageAvailabilityResult` can be indexed by generator-storage
name and timestamp to retrieve a vector of sample-level availability states for
the unit in the given timestep. States are provided as a boolean with
`true` indicating that the unit is available and `false` indicating that
it's unavailable.

Example:

```julia
genstoravail, =
    assess(sys, SequentialMonteCarlo(samples=10), GeneratorStorageAvailability())

samples = genstoravail["MyGenerator123", ZonedDateTime(2020, 1, 1, 0, tz"UTC")]

@assert samples isa Vector{Bool}
@assert length(samples) == 10
```
"""
struct GeneratorStorageAvailability <: ResultSpec end

struct GenStorAvailabilityAccumulator <: ResultAccumulator{GeneratorStorageAvailability}

    available::Array{Bool,3}

end

function accumulator(
    sys::SystemModel{N}, nsamples::Int, ::GeneratorStorageAvailability
) where {N}

    ngenstors = length(sys.generatorstorages)
    available = zeros(Bool, ngenstors, N, nsamples)

    return GenStorAvailabilityAccumulator(available)

end

function merge!(
    x::GenStorAvailabilityAccumulator, y::GenStorAvailabilityAccumulator
)

    x.available .|= y.available
    return

end

accumulatortype(::GeneratorStorageAvailability) = GenStorAvailabilityAccumulator

struct GeneratorStorageAvailabilityResult{N,L,T<:Period} <: AbstractAvailabilityResult{N,L,T}

    generatorstorages::Vector{String}
    timestamps::AbstractVector{ZonedDateTime}

    available::Array{Bool,3}

end

names(x::GeneratorStorageAvailabilityResult) = x.generatorstorages

function getindex(x::GeneratorStorageAvailabilityResult, gs::AbstractString, t::ZonedDateTime)
    i_gs = findfirstunique(x.generatorstorages, gs)
    i_t = findfirstunique(x.timestamps, t)
    return vec(x.available[i_gs, i_t, :])
end

function finalize(
    acc::GenStorAvailabilityAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    return GeneratorStorageAvailabilityResult{N,L,T}(
        system.generatorstorages.names, system.timestamps, acc.available)

end
