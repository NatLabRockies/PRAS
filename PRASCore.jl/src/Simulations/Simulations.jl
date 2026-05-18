@reexport module Simulations

import ..Systems: SystemModel, AbstractAssets, Generators, Lines,
                  conversionfactor, energytopower

import ..Results
import ..Results: ResultSpec,
                  accumulator, finalize, issamplebased

import Base: broadcastable
import Base.Threads: nthreads, @spawn
import MinCostFlows
import MinCostFlows: FlowProblem, solveflows!,
                     updateinjection!, updateflowlimit!, updateflowcost!
import OnlineStatsBase: fit!
import Random: AbstractRNG, rand, seed!
import Random123: Philox4x

export assess, SequentialMonteCarlo

include("SystemState.jl")
include("DispatchProblem.jl")
include("recording.jl")
include("utils.jl")

"""
    SequentialMonteCarlo(;
        samples::Int=10_000,
        seed::Integer=rand(UInt64),
        verbose::Bool=false,
        threaded::Bool=true
    )

Sequential Monte Carlo simulation parameters for PRAS analysis

It it recommended that you fix the random seed for reproducibility.

# Arguments

  - `samples::Int=10_000`: Number of samples
  - `seed::Integer=rand(UInt64)`: Random seed
  - `verbose::Bool=false`: Print progress
  - `threaded::Bool=true`: Enable threaded Monte Carlo simulation

When `threaded=true`, sample-level result specifications are internally
partitioned across threads during simulation and assembled into dense
result arrays during finalization.

# Returns

  - `SequentialMonteCarlo`: PRAS simulation specification
"""
struct SequentialMonteCarlo

    nsamples::Int
    seed::UInt64
    verbose::Bool
    threaded::Bool

    function SequentialMonteCarlo(;
        samples::Int=10_000, seed::Integer=rand(UInt64),
        verbose::Bool=false, threaded::Bool=true
    )
        samples <= 0 && throw(DomainError("Sample count must be positive"))
        seed < 0 && throw(DomainError("Random seed must be non-negative"))
        new(samples, UInt64(seed), verbose, threaded)
    end
end

broadcastable(x::SequentialMonteCarlo) = Ref(x)

function sample_ranges(nsamples::Int, nworkers::Int)
    base, rem = divrem(nsamples, nworkers)

    ranges = UnitRange{Int}[]
    start = 1

    for i in 1:nworkers
        len = base + (i <= rem ? 1 : 0)

        if len > 0
            stop = start + len - 1
            push!(ranges, start:stop)
            start = stop + 1
        end
    end

    return ranges
end

function partition_recorders(
    system::SystemModel,
    nsamples::Int,
    local_nsamples::Int,
    resultspecs::Tuple{Vararg{ResultSpec}},
)
    return map(resultspecs) do spec
        accumulator(system, issamplebased(spec) ? local_nsamples : nsamples, spec)
    end
end

"""
    assess(system::SystemModel, method::SequentialMonteCarlo, resultspecs::ResultSpec...)

Run a Sequential Monte Carlo simulation on a `system` using the `method` data
and return `resultspecs`.

# Arguments

  - `system::SystemModel`: PRAS data structure
  - `method::SequentialMonteCarlo`: method for PRAS analysis
  - `resultspecs::ResultSpec...`: PRAS metric for metrics like [`Shortfall`](@ref PRASCore.Results.Shortfall) missing generation

# Returns

  - `results::Tuple`: PRAS metric results
"""
function assess(
    system::SystemModel,
    method::SequentialMonteCarlo,
    resultspecs::ResultSpec...
)

    threads = method.threaded ? nthreads() : 1

    if method.threaded && threads == 1
        @warn "It looks like you haven't configured JULIA_NUM_THREADS before you started the julia repl. \n If you want to use multi-threading, stop the execution and start your julia repl using : \n julia --project --threads auto"
    end

    ranges = sample_ranges(method.nsamples, threads)
    actual_threads = length(ranges)

    results = Channel{Any}(actual_threads)

    for sampleids in ranges
        if method.threaded
            @spawn assess(system, method, sampleids, results, resultspecs...)
        else
            assess(system, method, sampleids, results, resultspecs...)
        end
    end

    return finalize(results, system, actual_threads, method.nsamples, resultspecs)

end

function assess(
    system::SystemModel{N},
    method::SequentialMonteCarlo,
    sampleids::UnitRange{Int},
    results::Channel,
    resultspecs::ResultSpec...
) where N

    dispatchproblem = DispatchProblem(system)
    systemstate = SystemState(system)

    recorders = partition_recorders(
        system,
        method.nsamples,
        length(sampleids),
        resultspecs,
    )

    # TODO: Test performance of Philox vs Threefry, choice of rounds
    # Also consider implementing an efficient Bernoulli trial with direct
    # mantissa comparison
    rng = Philox4x((0, 0), 10)

    for (local_sampleid, global_sampleid) in enumerate(sampleids)

        seed!(rng, (method.seed, global_sampleid))
        initialize!(rng, systemstate, system)

        for t in 1:N
            advance!(rng, systemstate, dispatchproblem, system, t)
            solve!(dispatchproblem, systemstate, system, t)

            foreach(recorders) do recorder
                record!(
                    recorder,
                    system,
                    systemstate,
                    dispatchproblem,
                    local_sampleid,
                    t,
                )
            end
        end

        foreach(recorders) do recorder
            reset!(recorder, local_sampleid)
        end
    end

    put!(results, (recorders, sampleids))

    return

end

function initialize!(
    rng::AbstractRNG, state::SystemState, system::SystemModel{N}
) where N

        initialize_availability!(
            rng, state.gens_available, state.gens_nexttransition,
            system.generators, N)

        initialize_availability!(
            rng, state.stors_available, state.stors_nexttransition,
            system.storages, N)

        initialize_availability!(
            rng, state.genstors_available, state.genstors_nexttransition,
            system.generatorstorages, N)

        initialize_availability!(
            rng, state.drs_available, state.drs_nexttransition,
            system.demandresponses, N)

        initialize_availability!(
            rng, state.lines_available, state.lines_nexttransition,
            system.lines, N)

        fill!(state.stors_energy, 0)
        fill!(state.genstors_energy, 0)
        fill!(state.drs_energy, 0)
        fill!(state.drs_unservedenergy, 0)
        fill!(state.drs_paybackcounter, -1)
        return

end

function advance!(
    rng::AbstractRNG,
    state::SystemState,
    dispatchproblem::DispatchProblem,
    system::SystemModel{N}, t::Int) where N

    update_availability!(
        rng, state.gens_available, state.gens_nexttransition,
        system.generators, t, N)

    update_availability!(
        rng, state.stors_available, state.stors_nexttransition,
        system.storages, t, N)

    update_availability!(
        rng, state.genstors_available, state.genstors_nexttransition,
        system.generatorstorages, t, N)

    update_availability!(
        rng, state.drs_available, state.drs_nexttransition,
        system.demandresponses, t, N)

    update_availability!(
        rng, state.lines_available, state.lines_nexttransition,
        system.lines, t, N)

    update_energy!(state.stors_energy, system.storages, t)
    update_energy!(state.genstors_energy, system.generatorstorages, t)
    update_dr_energy!(state.drs_energy, state.drs_unservedenergy, system.demandresponses, t)

    update_paybackcounter!(state.drs_paybackcounter,state.drs_energy, system.demandresponses,t)


    update_problem!(dispatchproblem, state, system, t)


end

function solve!(
    dispatchproblem::DispatchProblem, state::SystemState,
    system::SystemModel, t::Int
)
    solveflows!(dispatchproblem.fp)
    update_state!(state, dispatchproblem, system, t)
end

end
