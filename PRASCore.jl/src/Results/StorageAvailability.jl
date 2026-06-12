"""
    StorageAvailability

The `StorageAvailability` result specification reports the sample-level
discrete availability of `Storages`, producing a `StorageAvailabilityResult`.

A `StorageAvailabilityResult` can be indexed by storage device name and
a timestamp to retrieve a vector of sample-level availability states for
the unit in the given timestep. States are provided as a boolean with
`true` indicating that the unit is available and `false` indicating that
it's unavailable.

Example:

```julia
storavail, =
    assess(sys, SequentialMonteCarlo(samples=10), StorageAvailability())

samples = storavail["MyStorage123", ZonedDateTime(2020, 1, 1, 0, tz"UTC")]

@assert samples isa Vector{Bool}
@assert length(samples) == 10
```
"""
struct StorageAvailability <: ResultSpec end

struct StorAvailabilityAccumulator <: ResultAccumulator{StorageAvailability}

    available::Array{Bool,3}

end

function accumulator(
    sys::SystemModel{N}, nsamples::Int, ::StorageAvailability
) where {N}

    nstors = length(sys.storages)
    available = zeros(Bool, nstors, N, nsamples)

    return StorAvailabilityAccumulator(available)

end

function merge!(
    x::StorAvailabilityAccumulator, y::StorAvailabilityAccumulator
)

    x.available .|= y.available
    return

end

accumulatortype(::StorageAvailability) = StorAvailabilityAccumulator

struct StorageAvailabilityResult{N,L,T<:Period} <: AbstractAvailabilityResult{N,L,T}

    storages::Vector{String}
    timestamps::AbstractVector{ZonedDateTime}

    available::Array{Bool,3}

end

names(x::StorageAvailabilityResult) = x.storages

function getindex(x::StorageAvailabilityResult, s::AbstractString, t::ZonedDateTime)
    i_s = findfirstunique(x.storages, s)
    i_t = findfirstunique(x.timestamps, t)
    return vec(x.available[i_s, i_t, :])
end

function finalize(
    acc::StorAvailabilityAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    return StorageAvailabilityResult{N,L,T}(
        system.storages.names, system.timestamps, acc.available)

end
