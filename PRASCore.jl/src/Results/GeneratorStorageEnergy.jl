"""
    GeneratorStorageEnergy

The `GeneratorStorageEnergy` result specification reports the average state of
charge of `GeneratorStorages`, producing a `GeneratorStorageEnergyResult`.

A `GeneratorStorageEnergyResult` can be indexed by generator-storage device
name and a timestamp to retrieve a tuple of sample mean and standard deviation,
estimating the average energy level for the given generator-storage device in
that timestep.

Example:

```julia
genstorenergy, =
    assess(sys, SequentialMonteCarlo(samples=1000), GeneratorStorageEnergy())

soc_mean, soc_std =
    genstorenergy["MyGeneratorStorage123", ZonedDateTime(2020, 1, 1, 0, tz"UTC")]
```
See [`GeneratorStorageEnergySamples`](@ref) for sample-level generator-storage
states of charge.

See [`StorageEnergy`](@ref) for average storage states of charge.
"""
struct GeneratorStorageEnergy <: ResultSpec end

mutable struct GenStorageEnergyAccumulator <: ResultAccumulator{GeneratorStorageEnergy}

    # Cross-simulation energy mean/variances
    energy_period::Vector{MeanVariance}
    energy_genstorperiod::Matrix{MeanVariance}

end

function accumulator(
    sys::SystemModel{N}, nsamples::Int, ::GeneratorStorageEnergy
) where {N}

    ngenstors = length(sys.generatorstorages)

    energy_period = [meanvariance() for _ in 1:N]
    energy_genstorperiod = [meanvariance() for _ in 1:ngenstors, _ in 1:N]

    return GenStorageEnergyAccumulator(
        energy_period, energy_genstorperiod)

end

function merge!(
    x::GenStorageEnergyAccumulator, y::GenStorageEnergyAccumulator
)

    foreach(merge!, x.energy_period, y.energy_period)
    foreach(merge!, x.energy_genstorperiod, y.energy_genstorperiod)

    return

end

accumulatortype(::GeneratorStorageEnergy) = GenStorageEnergyAccumulator

struct GeneratorStorageEnergyResult{N,L,T<:Period,E<:EnergyUnit} <: AbstractEnergyResult{N,L,T}

    nsamples::Union{Int,Nothing}
    generatorstorages::Vector{String}
    timestamps::AbstractVector{ZonedDateTime}

    energy_mean::Matrix{Float64}

    energy_period_std::Vector{Float64}
    energy_regionperiod_std::Matrix{Float64}

end

names(x::GeneratorStorageEnergyResult) = x.generatorstorages

function getindex(x::GeneratorStorageEnergyResult, t::ZonedDateTime)
    i_t = findfirstunique(x.timestamps, t)
    return sum(view(x.energy_mean, :, i_t)), x.energy_period_std[i_t]
end

function getindex(x::GeneratorStorageEnergyResult, gs::AbstractString, t::ZonedDateTime)
    i_gs = findfirstunique(x.generatorstorages, gs)
    i_t = findfirstunique(x.timestamps, t)
    return x.energy_mean[i_gs, i_t], x.energy_regionperiod_std[i_gs, i_t]
end

function finalize(
    acc::GenStorageEnergyAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    _, period_std = mean_std(acc.energy_period)
    genstorperiod_mean, genstorperiod_std = mean_std(acc.energy_genstorperiod)

    nsamples = first(first(acc.energy_period).stats).n

    return GeneratorStorageEnergyResult{N,L,T,E}(
        nsamples, system.generatorstorages.names, system.timestamps,
        genstorperiod_mean, period_std, genstorperiod_std)

end
