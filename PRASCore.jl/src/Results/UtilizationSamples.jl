"""
    UtilizationSamples

The `UtilizationSamples` result specification reports the sample-level
absolute utilization of `Interfaces`, producing a `UtilizationSamplesResult`.

Whereas `FlowSamples` reports the directional power transfer across an
interface, `UtilizationSamples` reports the absolute value of flow relative to the
interface's transfer capability (counting the effects of line outages).
For example, a 100 MW symmetrically-constrained interface which is fully
congested may have a flow of +100 or -100 MW, but in both cases the utilization
will be 100%. If a 50 MW line in the interface went on outage, flow may drop
to +50 or -50 MW, but utilization would remain at 100%.

A `UtilizationSamplesResult` can be indexed by a `Pair` of region
names and a timestamp to retrieve a vector of sample-level utilizations of the
interface in that timestep. Given the absolute value nature of the outcome,
results are independent of direction. Querying
`"Region A" => "Region B"` will yield the same result as
`"Region B" => "Region A"`.

Example:

```julia
utils, =
    assess(sys, SequentialMonteCarlo(samples=10), UtilizationSamples())

samples =
    utils["Region A" => "Region B", ZonedDateTime(2020, 1, 1, 0, tz"UTC")]

@assert samples isa Vector{Float64}
@assert length(samples) == 10

samples2 =
    utils["Region B" => "Region A", ZonedDateTime(2020, 1, 1, 0, tz"UTC")]

@assert samples == samples2
```

Note that this result specification requires large amounts of memory for
larger sample sizes. See [`Utilization`](@ref) for sample-averaged utilization
results when sample-level granularity isn't required.
"""
struct UtilizationSamples <: ResultSpec end

struct UtilizationSamplesAccumulator <: ResultAccumulator{UtilizationSamples}

    utilization::Array{Float64,3}

end

function accumulator(
    sys::SystemModel{N}, nsamples::Int, ::UtilizationSamples
) where {N}

    ninterfaces = length(sys.interfaces)
    utilization = zeros(Float64, ninterfaces, N, nsamples)

    return UtilizationSamplesAccumulator(utilization)

end

function merge!(
    x::UtilizationSamplesAccumulator, y::UtilizationSamplesAccumulator
)

    x.utilization .+= y.utilization
    return

end

accumulatortype(::UtilizationSamples) = UtilizationSamplesAccumulator

struct UtilizationSamplesResult{N,L,T<:Period} <: AbstractUtilizationResult{N,L,T}

    interfaces::Vector{Pair{String,String}}
    timestamps::AbstractVector{ZonedDateTime}

    utilization::Array{Float64,3}

end

function getindex(x::UtilizationSamplesResult,
                  i::Pair{<:AbstractString,<:AbstractString})
    i_i, _ = findfirstunique_directional(x.interfaces, i)
    return vec(mean(view(x.utilization, i_i, :, :), dims=1))
end


function getindex(x::UtilizationSamplesResult,
                  i::Pair{<:AbstractString,<:AbstractString}, t::ZonedDateTime)
    i_i, _ = findfirstunique_directional(x.interfaces, i)
    i_t = findfirstunique(x.timestamps, t)
    return vec(x.utilization[i_i, i_t, :])
end

function finalize(
    acc::UtilizationSamplesAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    fromregions = getindex.(Ref(system.regions.names), system.interfaces.regions_from)
    toregions = getindex.(Ref(system.regions.names), system.interfaces.regions_to)

    return UtilizationSamplesResult{N,L,T}(
        Pair.(fromregions, toregions), system.timestamps, acc.utilization)

end
