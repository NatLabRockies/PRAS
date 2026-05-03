"""
    DemandResponseAvailability

The `DemandResponseAvailability` result specification reports the sample-level
discrete availability of `DemandResponses`, producing a `DemandResponseAvailabilityResult`.

A `DemandResponseAvailabilityResult` can be indexed by demand response device name and
a timestamp to retrieve a vector of sample-level availability states for
the unit in the given timestep. States are provided as a boolean with
`true` indicating that the unit is available and `false` indicating that
it's unavailable.

Example:

```julia
dravail, =
    assess(sys, SequentialMonteCarlo(samples=10), DemandResponseAvailability())

samples = dravail["MyDR123", ZonedDateTime(2020, 1, 1, 0, tz"UTC")]

@assert samples isa Vector{Bool}
@assert length(samples) == 10
```
"""
struct DemandResponseAvailability <: ResultSpec end

struct DRAvailabilityAccumulator <: ResultAccumulator{DemandResponseAvailability}

    available::Array{Bool,3}

end

function accumulator(
    sys::SystemModel{N}, nsamples::Int, ::DemandResponseAvailability
) where {N}

    ndrs = length(sys.demandresponses)
    available = zeros(Bool, ndrs, N, nsamples)

    return DRAvailabilityAccumulator(available)

end

function merge!(
    x::DRAvailabilityAccumulator, y::DRAvailabilityAccumulator
)

    x.available .|= y.available
    return

end

accumulatortype(::DemandResponseAvailability) = DRAvailabilityAccumulator

struct DemandResponseAvailabilityResult{N,L,T<:Period} <: AbstractAvailabilityResult{N,L,T}

    demandresponses::Vector{String}
    timestamps::StepRange{ZonedDateTime,T}

    available::Array{Bool,3}

end

names(x::DemandResponseAvailabilityResult) = x.demandresponses

function getindex(x::DemandResponseAvailabilityResult, s::AbstractString, t::ZonedDateTime)
    i_dr = findfirstunique(x.demandresponses, s)
    i_t = findfirstunique(x.timestamps, t)
    return vec(x.available[i_dr, i_t, :])
end

function finalize(
    acc::DRAvailabilityAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    return DemandResponseAvailabilityResult{N,L,T}(
        system.demandresponses.names, system.timestamps, acc.available)

end
