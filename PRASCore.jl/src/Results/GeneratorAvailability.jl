"""
    GeneratorAvailability

The `GeneratorAvailability` result specification reports the sample-level
discrete availability of `Generators`, producing a `GeneratorAvailabilityResult`.

A `GeneratorAvailabilityResult` can be indexed by generator name and
timestamp to retrieve a vector of sample-level availability states for
the unit in the given timestep. States are provided as a boolean with
`true` indicating that the unit is available and `false` indicating that
it's unavailable.

Example:

```julia
genavail, =
    assess(sys, SequentialMonteCarlo(samples=10), GeneratorAvailability())

samples = genavail["MyGenerator123", ZonedDateTime(2020, 1, 1, 0, tz"UTC")]

@assert samples isa Vector{Bool}
@assert length(samples) == 10
```
"""
struct GeneratorAvailability <: ResultSpec end

function accumulator(
    sys::SystemModel{N}, nsamples::Int, ::GeneratorAvailability
) where {N}

    ngens = length(sys.generators)
    available = zeros(Bool, ngens, N, nsamples)

    return GenAvailabilityAccumulator(available)

end

struct GenAvailabilityAccumulator <:
    ResultAccumulator{GeneratorAvailability}

    available::Array{Bool,3}

end

function merge!(
    x::GenAvailabilityAccumulator, y::GenAvailabilityAccumulator
)

    x.available .|= y.available
    return

end

accumulatortype(::GeneratorAvailability) = GenAvailabilityAccumulator

struct GeneratorAvailabilityResult{N,L,T<:Period} <: AbstractAvailabilityResult{N,L,T}

    generators::Vector{String}
    timestamps::AbstractVector{ZonedDateTime}

    available::Array{Bool,3}

end

names(x::GeneratorAvailabilityResult) = x.generators

function getindex(x::GeneratorAvailabilityResult, g::AbstractString, t::ZonedDateTime)
    i_g = findfirstunique(x.generators, g)
    i_t = findfirstunique(x.timestamps, t)
    return vec(x.available[i_g, i_t, :])
end

function finalize(
    acc::GenAvailabilityAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    return GeneratorAvailabilityResult{N,L,T}(
        system.generators.names, system.timestamps, acc.available)

end
