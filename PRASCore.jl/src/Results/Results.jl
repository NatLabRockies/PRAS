@reexport module Results

import Base: broadcastable, getindex, merge!
import OnlineStats: Series
import OnlineStatsBase: EqualWeight, Mean, Variance, value
import Printf: @sprintf
import StatsBase: mean, std, stderror, quantile

import ..Systems: SystemModel, ZonedDateTime, Period,
                  PowerUnit, EnergyUnit, conversionfactor,
                  unitsymbol, Regions
export

    # Metrics
    ReliabilityMetric, LOLE, EUE, NEUE,
    val, stderror, CVAR, NCVAR,

    # Result specifications
    Shortfall, ShortfallSamples,
    DemandResponseShortfall, DemandResponseShortfallSamples,
    Surplus, SurplusSamples,
    Flow, FlowSamples, Utilization, UtilizationSamples,
    StorageEnergy, StorageEnergySamples,
    GeneratorStorageEnergy, GeneratorStorageEnergySamples,
    DemandResponseEnergy, DemandResponseEnergySamples,
    GeneratorAvailability, StorageAvailability,
    GeneratorStorageAvailability,DemandResponseAvailability,
    LineAvailability

include("utils.jl")
include("metrics.jl")

abstract type ResultSpec end

abstract type ResultAccumulator{R<:ResultSpec} end

abstract type Result{
    N, # Number of timesteps simulated
    L, # Length of each simulation timestep
    T <: Period, # Units of each simulation timestep
} end

broadcastable(x::ResultSpec) = Ref(x)
broadcastable(x::Result) = Ref(x)

abstract type AbstractShortfallResult{N,L,T} <: Result{N,L,T} end

getindex(x::AbstractShortfallResult, ::Colon, t::ZonedDateTime) =
    getindex.(x, x.regions, t)

getindex(x::AbstractShortfallResult, r::AbstractString, ::Colon) =
    getindex.(x, r, x.timestamps)

getindex(x::AbstractShortfallResult, ::Colon, ::Colon) =
    getindex.(x, x.regions, permutedims(x.timestamps))


LOLE(x::AbstractShortfallResult, ::Colon, t::ZonedDateTime) =
    LOLE.(x, x.regions.names, t)

LOLE(x::AbstractShortfallResult, r::AbstractString, ::Colon) =
    LOLE.(x, r, x.timestamps)

LOLE(x::AbstractShortfallResult, ::Colon, ::Colon) =
    LOLE.(x, x.regions.names, permutedims(x.timestamps))


EUE(x::AbstractShortfallResult, ::Colon, t::ZonedDateTime) =
    EUE.(x, x.regions.names, t)

EUE(x::AbstractShortfallResult, r::AbstractString, ::Colon) =
    EUE.(x, r, x.timestamps)

EUE(x::AbstractShortfallResult, ::Colon, ::Colon) =
    EUE.(x, x.regions.names, permutedims(x.timestamps))

NEUE(x::AbstractShortfallResult, r::AbstractString, ::Colon) =
    NEUE.(x, r, x.timestamps)

NEUE(x::AbstractShortfallResult, ::Colon, ::Colon) =
    NEUE.(x, x.regions.names, permutedims(x.timestamps))

include("Shortfall.jl")
include("ShortfallSamples.jl")


abstract type AbstractSurplusResult{N,L,T} <: Result{N,L,T} end

getindex(x::AbstractSurplusResult, ::Colon) =
    getindex.(x, x.timestamps)

getindex(x::AbstractSurplusResult, ::Colon, t::ZonedDateTime) =
    getindex.(x, x.regions, t)

getindex(x::AbstractSurplusResult, r::AbstractString, ::Colon) =
    getindex.(x, r, x.timestamps)

getindex(x::AbstractSurplusResult, ::Colon, ::Colon) =
    getindex.(x, x.regions, permutedims(x.timestamps))

include("Surplus.jl")
include("SurplusSamples.jl")

abstract type AbstractFlowResult{N,L,T} <: Result{N,L,T} end

getindex(x::AbstractFlowResult, ::Colon) =
    getindex.(x, x.interfaces)

getindex(x::AbstractFlowResult, ::Colon, t::ZonedDateTime) =
    getindex.(x, x.interfaces, t)

getindex(x::AbstractFlowResult, i::Pair{<:AbstractString,<:AbstractString}, ::Colon) =
    getindex.(x, i, x.timestamps)

getindex(x::AbstractFlowResult, ::Colon, ::Colon) =
    getindex.(x, x.interfaces, permutedims(x.timestamps))

include("Flow.jl")
include("FlowSamples.jl")

abstract type AbstractUtilizationResult{N,L,T} <: Result{N,L,T} end

getindex(x::AbstractUtilizationResult, ::Colon) =
    getindex.(x, x.interfaces)

getindex(x::AbstractUtilizationResult, ::Colon, t::ZonedDateTime) =
    getindex.(x, x.interfaces, t)

getindex(x::AbstractUtilizationResult, i::Pair{<:AbstractString,<:AbstractString}, ::Colon) =
    getindex.(x, i, x.timestamps)

getindex(x::AbstractUtilizationResult, ::Colon, ::Colon) =
    getindex.(x, x.interfaces, permutedims(x.timestamps))

include("Utilization.jl")
include("UtilizationSamples.jl")

abstract type AbstractAvailabilityResult{N,L,T} <: Result{N,L,T} end

getindex(x::AbstractAvailabilityResult, ::Colon, t::ZonedDateTime) =
    getindex.(x, names(x), t)

getindex(x::AbstractAvailabilityResult, name::String, ::Colon) =
    getindex.(x, name, x.timestamps)

getindex(x::AbstractAvailabilityResult, ::Colon, ::Colon) =
    getindex.(x, names(x), permutedims(x.timestamps))

include("GeneratorAvailability.jl")
include("StorageAvailability.jl")
include("GeneratorStorageAvailability.jl")
include("DemandResponseAvailability.jl")
include("LineAvailability.jl")

abstract type AbstractEnergyResult{N,L,T} <: Result{N,L,T} end

getindex(x::AbstractEnergyResult, ::Colon) =
    getindex.(x, x.timestamps)

getindex(x::AbstractEnergyResult, ::Colon, t::ZonedDateTime) =
    getindex.(x, names(x), t)

getindex(x::AbstractEnergyResult, name::String, ::Colon) =
    getindex.(x, name, x.timestamps)

getindex(x::AbstractEnergyResult, ::Colon, ::Colon) =
    getindex.(x, names(x), permutedims(x.timestamps))

include("StorageEnergy.jl")
include("GeneratorStorageEnergy.jl")
include("DemandResponseEnergy.jl")
include("StorageEnergySamples.jl")
include("GeneratorStorageEnergySamples.jl")
include("DemandResponseEnergySamples.jl")

function resultchannel(
    results::T, threads::Int
) where T <: Tuple{Vararg{ResultSpec}}

    types = accumulatortype.(results)
    return Channel{Tuple{types...}}(threads)

end

merge!(xs::T, ys::T) where T <: Tuple{Vararg{ResultAccumulator}} =
    foreach(merge!, xs, ys)

function finalize(
    results::Channel{<:Tuple{Vararg{ResultAccumulator}}},
    system::SystemModel{N,L,T,P,E},
    threads::Int
) where {N,L,T,P,E}

    total_result = take!(results)

    for _ in 2:threads
        thread_result = take!(results)
        merge!(total_result, thread_result)
    end
    close(results)

    return finalize.(total_result, system)

end

end
