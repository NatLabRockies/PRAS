@reexport module Results

import Base: broadcastable, getindex, merge!
import OnlineStats: Series
import OnlineStatsBase: EqualWeight, Mean, Variance, value
import Printf: @sprintf
import StatsBase: mean, std, stderror
import Dates: Date

import ..Systems: SystemModel, ZonedDateTime, Period,
                  PowerUnit, EnergyUnit, conversionfactor,
                  unitsymbol, Regions
export

    # Metrics
    ReliabilityMetric, LOLE, EUE, NEUE, LOLD, LOLEv, 
    MeanEventDuration, MaxEventDuration, MeanEventEnergy, MaxEventEnergy, 
    val, stderror,

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
    LineAvailability, ShortfallEvents

include("utils.jl")
include("metrics.jl")

abstract type ResultSpec end

abstract type ResultAccumulator{R<:ResultSpec} end

issamplebased(::ResultSpec) = false

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

abstract type AbstractShortfallEventResult{N,L,T} <: Result{N,L,T} end

include("StorageEnergy.jl")
include("GeneratorStorageEnergy.jl")
include("DemandResponseEnergy.jl")
include("StorageEnergySamples.jl")
include("GeneratorStorageEnergySamples.jl")
include("DemandResponseEnergySamples.jl")
include("ShortfallEvents.jl")

issamplebased(::ShortfallSamples) = true
issamplebased(::DemandResponseShortfallSamples) = true
issamplebased(::SurplusSamples) = true
issamplebased(::FlowSamples) = true
issamplebased(::UtilizationSamples) = true
issamplebased(::StorageEnergySamples) = true
issamplebased(::GeneratorStorageEnergySamples) = true
issamplebased(::DemandResponseEnergySamples) = true
issamplebased(::GeneratorAvailability) = true
issamplebased(::StorageAvailability) = true
issamplebased(::GeneratorStorageAvailability) = true
issamplebased(::DemandResponseAvailability) = true
issamplebased(::LineAvailability) = true

function resultchannel(
    results::T, threads::Int
) where T <: Tuple{Vararg{ResultSpec}}

    types = accumulatortype.(results)
    return Channel{Tuple{types...}}(threads)

end

merge!(xs::T, ys::T) where T <: Tuple{Vararg{ResultAccumulator}} =
    foreach(merge!, xs, ys)

function copy_sample_partition!(
    x::A,
    y::A,
    sampleids::UnitRange{Int},
) where {A<:ResultAccumulator}

    field = fieldnames(A)[1]
    xarr = getfield(x, field)
    yarr = getfield(y, field)

    @views xarr[:, :, sampleids] .= yarr
    return
end

function finalize(
    results::Channel,
    system::SystemModel{N,L,T,P,E},
    threads::Int,
    nsamples::Int,
    resultspecs::Tuple{Vararg{ResultSpec}},
) where {N,L,T,P,E}

    first_recorders, first_sampleids = take!(results)

    total_result = map(resultspecs, first_recorders) do spec, recorder
        issamplebased(spec) ? accumulator(system, nsamples, spec) : recorder
    end

    for i in eachindex(total_result)
        if issamplebased(resultspecs[i])
            copy_sample_partition!(total_result[i], first_recorders[i], first_sampleids)
        end
    end

    for _ in 2:threads
        thread_recorders, sampleids = take!(results)

        for i in eachindex(total_result)
            if issamplebased(resultspecs[i])
                copy_sample_partition!(total_result[i], thread_recorders[i], sampleids)
            else
                merge!(total_result[i], thread_recorders[i])
            end
        end
    end

    close(results)

    return finalize.(total_result, system)

end

end
