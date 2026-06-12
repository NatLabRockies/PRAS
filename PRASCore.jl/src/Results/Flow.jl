"""
    Flow

The `Flow` result specification reports the estimated average flow across
transmission `Interfaces`, producing a `FlowResult`.

A `FlowResult` can be indexed by a directional `Pair` of region names and a
timestamp to retrieve a tuple of sample mean and standard deviation, estimating
the average net flow magnitude and direction relative to the given directed
interface in that timestep. For a query of `"Region A" => "Region B"`, if
estimated average flow was from A to B, the reported value would be positive,
while if average flow was in the reverse direction, from B to A, the value
would be negative.

Example:

```julia
flows, =
    assess(sys, SequentialMonteCarlo(samples=1000), Flow())

flow_mean, flow_std =
    flows["Region A" => "Region B", ZonedDateTime(2020, 1, 1, 0, tz"UTC")]
flow2_mean, flow2_std =
    flows["Region B" => "Region A", ZonedDateTime(2020, 1, 1, 0, tz"UTC")]
@assert flow_mean == -flow2_mean
```

See [`FlowSamples`](@ref) for sample-level flow results.
"""
struct Flow <: ResultSpec end

struct FlowAccumulator <: ResultAccumulator{Flow}

    flow_interface::Vector{MeanVariance}
    flow_interfaceperiod::Matrix{MeanVariance}

    flow_interface_currentsim::Vector{Int}

end

function accumulator(
    sys::SystemModel{N}, nsamples::Int, ::Flow
) where {N}

    n_interfaces = length(sys.interfaces)
    flow_interface = [meanvariance() for _ in 1:n_interfaces]
    flow_interfaceperiod = [meanvariance() for _ in 1:n_interfaces, _ in 1:N]

    flow_interface_currentsim = zeros(Int, n_interfaces)

    return FlowAccumulator(
        flow_interface, flow_interfaceperiod,  flow_interface_currentsim)

end

function merge!(
    x::FlowAccumulator, y::FlowAccumulator
)

    foreach(merge!, x.flow_interface, y.flow_interface)
    foreach(merge!, x.flow_interfaceperiod, y.flow_interfaceperiod)

end

accumulatortype(::Flow) = FlowAccumulator

struct FlowResult{N,L,T<:Period,P<:PowerUnit} <: AbstractFlowResult{N,L,T}

    nsamples::Union{Int,Nothing}
    interfaces::Vector{Pair{String,String}}
    timestamps::AbstractVector{ZonedDateTime}

    flow_mean::Matrix{Float64}

    flow_interface_std::Vector{Float64}
    flow_interfaceperiod_std::Matrix{Float64}

end

function getindex(x::FlowResult, i::Pair{<:AbstractString,<:AbstractString})
    i_i, reverse = findfirstunique_directional(x.interfaces, i)
    flow = mean(view(x.flow_mean, i_i, :))
    return reverse ? -flow : flow, x.flow_interface_std[i_i]
end

function getindex(x::FlowResult, i::Pair{<:AbstractString,<:AbstractString}, t::ZonedDateTime)
    i_i, reverse = findfirstunique_directional(x.interfaces, i)
    i_t = findfirstunique(x.timestamps, t)
    flow = x.flow_mean[i_i, i_t]
    return reverse ? -flow : flow, x.flow_interfaceperiod_std[i_i, i_t]
end

function finalize(
    acc::FlowAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    nsamples = length(system.interfaces) > 0 ?
        first(acc.flow_interface[1].stats).n : nothing

    flow_mean, flow_interfaceperiod_std = mean_std(acc.flow_interfaceperiod)
    flow_interface_std = last(mean_std(acc.flow_interface)) / N

    fromregions = getindex.(Ref(system.regions.names), system.interfaces.regions_from)
    toregions = getindex.(Ref(system.regions.names), system.interfaces.regions_to)

    return FlowResult{N,L,T,P}(
        nsamples,  Pair.(fromregions, toregions), system.timestamps,
        flow_mean, flow_interface_std, flow_interfaceperiod_std)

end
