@reexport module Simulations

import ..Systems: SystemModel, AbstractAssets, Generators, Lines,
                  conversionfactor, energytopower

import ..Results
import ..Results: ResultSpec, ResultAccumulator,
                  accumulator, resultchannel, finalize

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
  - `threaded::Bool=true`: Use multi-threading

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

"""
    assess(system::SystemModel, method::SequentialMonteCarlo, resultspecs::ResultSpec...)

Run a Sequential Monte Carlo simulation on a `system` using the `method` data
and return `resultspecs`.

# Arguments

  - `system::SystemModel`: PRAS data structure
  - `method::SequentialMonteCarlo`: method for PRAS analysis
  - `resultspecs::ResultSpec...`: PRAS metric for metrics like [`Shortfall`](@ref PRASCore.Results.Shortfall) missing generation

# Returns

  - `results::Tuple{Vararg{ResultAccumulator{SequentialMonteCarlo}}}`: PRAS metric results
"""
function assess(
    system::SystemModel,
    method::SequentialMonteCarlo,
    resultspecs::ResultSpec...
)

    threads = nthreads()
    sampleseeds = Channel{Int}(2*threads)
    results = resultchannel(resultspecs, threads)

    @spawn makeseeds(sampleseeds, method.nsamples)

    if method.threaded

        if (threads == 1)
            @warn "It looks like you haven't configured JULIA_NUM_THREADS before you started the julia repl. \n If you want to use multi-threading, stop the execution and start your julia repl using : \n julia --project --threads auto"
        end
        
        for _ in 1:threads
            @spawn assess(system, method, sampleseeds, results, resultspecs...)
        end
    else
        assess(system, method, sampleseeds, results, resultspecs...)
    end

    return finalize(results, system, method.threaded ? threads : 1)

end

function makeseeds(sampleseeds::Channel{Int}, nsamples::Int)

    for s in 1:nsamples
        put!(sampleseeds, s)
    end

    close(sampleseeds)

end

function assess(
    system::SystemModel{N}, method::SequentialMonteCarlo,
    sampleseeds::Channel{Int},
    results::Channel{<:Tuple{Vararg{ResultAccumulator}}},
    resultspecs::ResultSpec...
) where N

    dispatchproblem = DispatchProblem(system)
    systemstate = SystemState(system)
    recorders = accumulator.(system, method.nsamples, resultspecs)

    # TODO: Test performance of Philox vs Threefry, choice of rounds
    # Also consider implementing an efficient Bernoulli trial with direct
    # mantissa comparison
    rng = Philox4x((0, 0), 10)

    for s in sampleseeds

        seed!(rng, (method.seed, s))
        initialize!(rng, systemstate, system)

        for t in 1:N

            advance!(rng, systemstate, dispatchproblem, system, t)
            solve!(dispatchproblem, systemstate, system, t)
            foreach(recorder -> record!(
                        recorder, system, systemstate, dispatchproblem, s, t
                    ), recorders)

        end

        foreach(recorder -> reset!(recorder, s), recorders)

    end

    put!(results, recorders)

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
