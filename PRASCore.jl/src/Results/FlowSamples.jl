"""
    FlowSamples

The `FlowSamples` result specification reports the sample-level magnitude and
direction of power flows across `Interfaces`, producing a `FlowSamplesResult`.

A `FlowSamplesResult` can be indexed by a directional `Pair` of region names and a
timestamp to retrieve a vector of sample-level net flow magnitudes and
directions relative to the given directed interface in that timestep. For a
query of `"Region A" => "Region B"`, if flow in one sample was from A to B, the
reported value would be positive, while if flow was in the reverse direction,
from B to A, the value would be negative.

Example:

```julia
flows, =
    assess(sys, SequentialMonteCarlo(samples=10), FlowSamples())

samples = flows["Region A" => "Region B", ZonedDateTime(2020, 1, 1, 0, tz"UTC")]

@assert samples isa Vector{Float64}
@assert length(samples) == 10

samples2 = flows["Region B" => "Region A", ZonedDateTime(2020, 1, 1, 0, tz"UTC")]

@assert samples == -samples2
```

Note that this result specification requires large amounts of memory for
larger sample sizes. See [`Flow`](@ref) for estimated average flow results
when sample-level granularity isn't required.
"""
struct FlowSamples <: ResultSpec end

struct FlowSamplesAccumulator <: ResultAccumulator{FlowSamples}

    flow::Array{Int,3}

end

function accumulator(
    sys::SystemModel{N}, nsamples::Int, ::FlowSamples
) where {N}

    ninterfaces = length(sys.interfaces)
    flow = zeros(Int, ninterfaces, N, nsamples)

    return FlowSamplesAccumulator(flow)

end

function merge!(
    x::FlowSamplesAccumulator, y::FlowSamplesAccumulator
)

    x.flow .+= y.flow
    return

end

accumulatortype(::FlowSamples) = FlowSamplesAccumulator

struct FlowSamplesResult{N,L,T<:Period,P<:PowerUnit} <: AbstractFlowResult{N,L,T}

    interfaces::Vector{Pair{String,String}}
    timestamps::AbstractVector{ZonedDateTime}

    flow::Array{Int,3}

end

function getindex(x::FlowSamplesResult, i::Pair{<:AbstractString,<:AbstractString})
    i_i, reverse = findfirstunique_directional(x.interfaces, i)
    flow = vec(mean(view(x.flow, i_i, :, :), dims=1))
    return reverse ? -flow : flow
end


function getindex(x::FlowSamplesResult, i::Pair{<:AbstractString,<:AbstractString}, t::ZonedDateTime)
    i_i, reverse = findfirstunique_directional(x.interfaces, i)
    i_t = findfirstunique(x.timestamps, t)
    flow = vec(x.flow[i_i, i_t, :])
    return reverse ? -flow : flow
end

function finalize(
    acc::FlowSamplesAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    fromregions = getindex.(Ref(system.regions.names), system.interfaces.regions_from)
    toregions = getindex.(Ref(system.regions.names), system.interfaces.regions_to)

    return FlowSamplesResult{N,L,T,P}(
        Pair.(fromregions, toregions), system.timestamps, acc.flow)

end
