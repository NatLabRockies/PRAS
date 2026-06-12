"""
    LineAvailability

The `LineAvailability` result specification reports the sample-level
discrete availability of `Lines`, producing a `LineAvailabilityResult`.

A `LineAvailabilityResult` can be indexed by line name and
timestamp to retrieve a vector of sample-level availability states for
the unit in the given timestep. States are provided as a boolean with
`true` indicating that the unit is available and `false` indicating that
it's unavailable.

Example:

```julia
lineavail, =
    assess(sys, SequentialMonteCarlo(samples=10), LineAvailability())

samples = lineavail["MyLine123", ZonedDateTime(2020, 1, 1, 0, tz"UTC")]

@assert samples isa Vector{Bool}
@assert length(samples) == 10
```
"""
struct LineAvailability <: ResultSpec end

struct LineAvailabilityResult{N,L,T<:Period} <: AbstractAvailabilityResult{N,L,T}

    lines::Vector{String}
    timestamps::AbstractVector{ZonedDateTime}

    available::Array{Bool,3}

end

names(x::LineAvailabilityResult) = x.lines

function getindex(x::LineAvailabilityResult, l::AbstractString, t::ZonedDateTime)
    i_l = findfirstunique(x.lines, l)
    i_t = findfirstunique(x.timestamps, t)
    return vec(x.available[i_l, i_t, :])
end

struct LineAvailabilityAccumulator <: ResultAccumulator{LineAvailability}

    available::Array{Bool,3}

end

accumulatortype(::LineAvailability) = LineAvailabilityAccumulator

function accumulator(
    sys::SystemModel{N}, nsamples::Int, ::LineAvailability
) where {N}

    nlines = length(sys.lines)
    available = zeros(Bool, nlines, N, nsamples)

    return LineAvailabilityAccumulator(available)

end

function merge!(
    x::LineAvailabilityAccumulator, y::LineAvailabilityAccumulator
)

    x.available .|= y.available
    return

end

function finalize(
    acc::LineAvailabilityAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    return LineAvailabilityResult{N,L,T}(
        system.lines.names, system.timestamps, acc.available)

end
