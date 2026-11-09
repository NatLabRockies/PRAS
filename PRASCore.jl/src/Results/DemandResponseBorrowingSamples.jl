"""
    DemandResponseBorrowingSamples

The `DemandResponseBorrowingSamples` result specification reports sample-level
realized borrowing power of `DemandResponses`, producing a
`DemandResponseBorrowingSamplesResult`.

A `DemandResponseBorrowingSamplesResult` can be indexed by demand response
device name and a timestamp to retrieve a vector of sample-level gross demand
reductions in that timestep, in the system's power units.
Borrowing is reported before efficiency adjustments and is not net of repayment.

Example:

```julia
borrowing, =
    assess(sys, SequentialMonteCarlo(samples=10), DemandResponseBorrowingSamples())

samples = borrowing["MyDemandResponse123", ZonedDateTime(2020, 1, 1, 0, tz"UTC")]

@assert samples isa Vector{Int}
@assert length(samples) == 10
```

Note that this result specification requires large amounts of memory for
larger sample sizes.
See [`DemandResponseBorrowing`](@ref) for estimated average borrowing power
when sample-level granularity isn't required.

See [`DemandResponseEnergySamples`](@ref) for outstanding borrowed energy.
"""
struct DemandResponseBorrowingSamples <: ResultSpec end

struct DemandResponseBorrowingSamplesAccumulator <: ResultAccumulator{DemandResponseBorrowingSamples}

    borrowing::Array{Int,3}

end

sampledata(acc::DemandResponseBorrowingSamplesAccumulator) = acc.borrowing
usesamplepartitions(::DemandResponseBorrowingSamples) = true

function accumulator(
    sys::SystemModel{N}, nsamples::Int, ::DemandResponseBorrowingSamples
) where {N}

    ndrs = length(sys.demandresponses)
    borrowing = zeros(Int, ndrs, N, nsamples)

    return DemandResponseBorrowingSamplesAccumulator(borrowing)

end

function merge!(
    x::DemandResponseBorrowingSamplesAccumulator, y::DemandResponseBorrowingSamplesAccumulator
)

    x.borrowing .+= y.borrowing
    return

end

accumulatortype(::DemandResponseBorrowingSamples) = DemandResponseBorrowingSamplesAccumulator

struct DemandResponseBorrowingSamplesResult{N,L,T<:Period,P<:PowerUnit} <: AbstractBorrowingResult{N,L,T}

    demandresponses::Vector{String}
    timestamps::StepRange{ZonedDateTime,T}

    borrowing::Array{Int,3}

end

names(x::DemandResponseBorrowingSamplesResult) = x.demandresponses

function getindex(x::DemandResponseBorrowingSamplesResult, t::ZonedDateTime)
    i_t = findfirstunique(x.timestamps, t)
    return vec(sum(view(x.borrowing, :, i_t, :), dims=1))
end

function getindex(x::DemandResponseBorrowingSamplesResult, s::AbstractString, t::ZonedDateTime)
    i_dr = findfirstunique(x.demandresponses, s)
    i_t = findfirstunique(x.timestamps, t)
    return vec(x.borrowing[i_dr, i_t, :])
end

function finalize(
    acc::DemandResponseBorrowingSamplesAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    return DemandResponseBorrowingSamplesResult{N,L,T,P}(
        system.demandresponses.names, system.timestamps, acc.borrowing)

end
