"""
    SurplusSamples

The `SurplusSamples` result specification reports sample-level unused
generation and storage discharge capability of `Regions`, producing a
`SurplusSamplesResult`.

A `SurplusSamplesResult` can be indexed by region name and timestamp to retrieve
a vector of sample-level surplus values in that region and timestep.

Example:

```julia
surplus, =
    assess(sys, SequentialMonteCarlo(samples=10), SurplusSamples())

samples = surplus["Region A", ZonedDateTime(2020, 1, 1, 0, tz"UTC")]

@assert samples isa Vector{Float64}
@assert length(samples) == 10
```

Note that this result specification requires large amounts of memory for
larger sample sizes. See [`Surplus`](@ref) for estimated average surplus values
when sample-level granularity isn't required.
"""
struct SurplusSamples <: ResultSpec end

struct SurplusSamplesAccumulator <: ResultAccumulator{SurplusSamples}

    surplus::Array{Int,3}

end

function accumulator(
    sys::SystemModel{N}, nsamples::Int, ::SurplusSamples
) where {N}

    nregions = length(sys.regions)
    surplus = zeros(Int, nregions, N, nsamples)

    return SurplusSamplesAccumulator(surplus)

end

function merge!(
    x::SurplusSamplesAccumulator, y::SurplusSamplesAccumulator
)

    x.surplus .+= y.surplus
    return

end

accumulatortype(::SurplusSamples) = SurplusSamplesAccumulator

struct SurplusSamplesResult{N,L,T<:Period,P<:PowerUnit} <: AbstractSurplusResult{N,L,T}

    regions::Vector{String}
    timestamps::AbstractVector{ZonedDateTime}

    surplus::Array{Int,3}

end

function getindex(x::SurplusSamplesResult, t::ZonedDateTime)
    i_t = findfirstunique(x.timestamps, t)
    return vec(sum(view(x.surplus, :, i_t, :), dims=1))
end

function getindex(x::SurplusSamplesResult, r::AbstractString, t::ZonedDateTime)
    i_r = findfirstunique(x.regions, r)
    i_t = findfirstunique(x.timestamps, t)
    return vec(x.surplus[i_r, i_t, :])
end

function finalize(
    acc::SurplusSamplesAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    return SurplusSamplesResult{N,L,T,P}(
        system.regions.names, system.timestamps, acc.surplus)

end
