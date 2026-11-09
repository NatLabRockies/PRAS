"""
    DemandResponseBorrowing

The `DemandResponseBorrowing` result specification reports the average realized
borrowing power of `DemandResponses`, producing a `DemandResponseBorrowingResult`.

A `DemandResponseBorrowingResult` can be indexed by demand response device
name and a timestamp to retrieve a tuple of sample mean and standard deviation
for gross demand reduction in that timestep, in the system's power units.
Borrowing is reported before efficiency adjustments and is not net of repayment.

Example:

```julia
borrowing, =
    assess(sys, SequentialMonteCarlo(samples=1000), DemandResponseBorrowing())

borrowing_mean, borrowing_std =
    borrowing["MyDemandResponse123", ZonedDateTime(2020, 1, 1, 0, tz"UTC")]
```

See [`DemandResponseBorrowingSamples`](@ref) for sample-level borrowing power.

See [`DemandResponseEnergy`](@ref) for outstanding borrowed energy.
"""
struct DemandResponseBorrowing <: ResultSpec end

mutable struct DemandResponseBorrowingAccumulator <: ResultAccumulator{DemandResponseBorrowing}

    # Cross-simulation borrowing power mean/variances
    borrowing_period::Vector{MeanVariance}
    borrowing_demandresponseperiod::Matrix{MeanVariance}

end

function accumulator(
    sys::SystemModel{N}, nsamples::Int, ::DemandResponseBorrowing
) where {N}

    ndemandresponses = length(sys.demandresponses)

    borrowing_period = [meanvariance() for _ in 1:N]
    borrowing_demandresponseperiod = [meanvariance() for _ in 1:ndemandresponses, _ in 1:N]

    return DemandResponseBorrowingAccumulator(
        borrowing_period, borrowing_demandresponseperiod)

end

function merge!(
    x::DemandResponseBorrowingAccumulator, y::DemandResponseBorrowingAccumulator
)

    foreach(merge!, x.borrowing_period, y.borrowing_period)
    foreach(merge!, x.borrowing_demandresponseperiod, y.borrowing_demandresponseperiod)

    return

end

accumulatortype(::DemandResponseBorrowing) = DemandResponseBorrowingAccumulator

struct DemandResponseBorrowingResult{N,L,T<:Period,P<:PowerUnit} <: AbstractBorrowingResult{N,L,T}

    nsamples::Union{Int,Nothing}
    demandresponses::Vector{String}
    timestamps::StepRange{ZonedDateTime,T}

    borrowing_mean::Matrix{Float64}

    borrowing_period_std::Vector{Float64}
    borrowing_demandresponseperiod_std::Matrix{Float64}

end

names(x::DemandResponseBorrowingResult) = x.demandresponses

function getindex(x::DemandResponseBorrowingResult, t::ZonedDateTime)
    i_t = findfirstunique(x.timestamps, t)
    return sum(view(x.borrowing_mean, :, i_t)), x.borrowing_period_std[i_t]
end

function getindex(x::DemandResponseBorrowingResult, s::AbstractString, t::ZonedDateTime)
    i_dr = findfirstunique(x.demandresponses, s)
    i_t = findfirstunique(x.timestamps, t)
    return x.borrowing_mean[i_dr, i_t], x.borrowing_demandresponseperiod_std[i_dr, i_t]
end

function finalize(
    acc::DemandResponseBorrowingAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    _, period_std = mean_std(acc.borrowing_period)
    demandresponseperiod_mean, demandresponseperiod_std = mean_std(acc.borrowing_demandresponseperiod)

    nsamples = first(first(acc.borrowing_period).stats).n

    return DemandResponseBorrowingResult{N,L,T,P}(
        nsamples, system.demandresponses.names, system.timestamps,
        demandresponseperiod_mean, period_std, demandresponseperiod_std)

end
