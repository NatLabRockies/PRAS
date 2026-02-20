# Shortfall

function record!(
    acc::Results.ShortfallAccumulator{S},
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E,S}

    totalshortfall = 0
    isshortfall = false

    edges = problem.fp.edges

    for (r, dr_idxs) in zip(problem.region_unserved_edges, system.region_dr_idxs)

        #count region shortfall and include dr shortfall
        #if shortfall include region and dr shortfall
        #if drshortfall don't include region shortfall

        regionshortfall = init_regionshortfall(S,edges,r)
            
        dr_shortfall = 0
        for i in dr_idxs
            dr_shortfall += state.drs_unservedenergy[i]
        end
        regionshortfall += dr_shortfall
        isregionshortfall = regionshortfall > 0


        fit!(acc.periodsdropped_regionperiod[r,t], isregionshortfall)
        fit!(acc.unservedload_regionperiod[r,t], regionshortfall)

        if isregionshortfall

            isshortfall = true
            totalshortfall += regionshortfall

            acc.periodsdropped_region_currentsim[r] += 1
            acc.unservedload_region_currentsim[r] += regionshortfall

        end
    end

    if isshortfall
        acc.periodsdropped_total_currentsim += 1
        acc.unservedload_total_currentsim += totalshortfall
    end

    fit!(acc.periodsdropped_period[t], isshortfall)
    fit!(acc.unservedload_period[t], totalshortfall)

    return

end

function reset!(acc::Results.ShortfallAccumulator, sampleid::Int)
    # Store total UE for each sample
    acc.unservedload_sample[sampleid] = acc.unservedload_total_currentsim 
    
    # Store regional / total sums for current simulation
    fit!(acc.periodsdropped_total, acc.periodsdropped_total_currentsim)
    fit!(acc.unservedload_total, acc.unservedload_total_currentsim)

    for r in eachindex(acc.periodsdropped_region)
        fit!(acc.periodsdropped_region[r], acc.periodsdropped_region_currentsim[r])
        fit!(acc.unservedload_region[r], acc.unservedload_region_currentsim[r])
        acc.unservedload_region_sample[r, sampleid] = acc.unservedload_region_currentsim[r]
    end

    # Reset for new simulation
    acc.periodsdropped_total_currentsim = 0
    fill!(acc.periodsdropped_region_currentsim, 0)
    acc.unservedload_total_currentsim = 0
    fill!(acc.unservedload_region_currentsim, 0)

    return

end

# ShortfallSamples

function record!(
    acc::Results.ShortfallSamplesAccumulator{S},
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E,S}

    for (r,dr_idxs) in zip(problem.region_unserved_edges,system.region_dr_idxs)
        #getting dr shortfall
        dr_shortfall = 0
        for i in dr_idxs
            dr_shortfall += state.drs_unservedenergy[i]
        end

        acc.shortfall[r, t, sampleid] = 
            init_regionshortfall(S,problem.fp.edges,r) +
            dr_shortfall
    end

    return

end

reset!(acc::Results.ShortfallSamplesAccumulator, sampleid::Int) = nothing

# Surplus

function record!(
    acc::Results.SurplusAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    totalsurplus = 0
    edges = problem.fp.edges

    for (r, e_idx) in enumerate(problem.region_unused_edges)

        regionsurplus = edges[e_idx].flow

        for s in system.region_stor_idxs[r]
            se_idx = problem.storage_dischargeunused_edges[s]
            regionsurplus += edges[se_idx].flow
        end

        for gs in system.region_genstor_idxs[r]

            gse_discharge_idx = problem.genstorage_dischargeunused_edges[gs]
            gse_inflow_idx = problem.genstorage_inflowunused_edges[gs]

            grid_limit = system.generatorstorages.gridinjection_capacity[gs, t]
            total_unused = edges[gse_discharge_idx].flow + edges[gse_inflow_idx].flow

            regionsurplus += min(grid_limit, total_unused)

        end
        fit!(acc.surplus_regionperiod[r,t], regionsurplus)
        totalsurplus += regionsurplus

    end

    fit!(acc.surplus_period[t], totalsurplus)

    return

end

reset!(acc::Results.SurplusAccumulator, sampleid::Int) = nothing

# SurplusSamples

function record!(
    acc::Results.SurplusSamplesAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    edges = problem.fp.edges

    for (r, e) in enumerate(problem.region_unused_edges)

        regionsurplus = edges[e].flow

        for s in system.region_stor_idxs[r]
            se_idx = problem.storage_dischargeunused_edges[s]
            regionsurplus += edges[se_idx].flow
        end

        for gs in system.region_genstor_idxs[r]

            gse_discharge_idx = problem.genstorage_dischargeunused_edges[gs]
            gse_inflow_idx = problem.genstorage_inflowunused_edges[gs]

            grid_limit = system.generatorstorages.gridinjection_capacity[gs, t]
            total_unused = edges[gse_discharge_idx].flow + edges[gse_inflow_idx].flow

            regionsurplus += min(grid_limit, total_unused)

        end
        acc.surplus[r, t, sampleid] = regionsurplus

    end

    return

end

reset!(acc::Results.SurplusSamplesAccumulator, sampleid::Int) = nothing

# Flow

function record!(
    acc::Results.FlowAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    edges = problem.fp.edges

    for (i, (f, b)) in enumerate(zip(problem.interface_forward_edges,
                                     problem.interface_reverse_edges))

        flow = edges[f].flow - edges[b].flow
        acc.flow_interface_currentsim[i] += flow
        fit!(acc.flow_interfaceperiod[i,t], flow)

    end

end

function reset!(acc::Results.FlowAccumulator, sampleid::Int)

    for i in eachindex(acc.flow_interface_currentsim)
        fit!(acc.flow_interface[i], acc.flow_interface_currentsim[i])
        acc.flow_interface_currentsim[i] = 0
    end

end

# FlowSamples

function record!(
    acc::Results.FlowSamplesAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    for (i, (e_f, e_r)) in enumerate(zip(problem.interface_forward_edges,
                                problem.interface_reverse_edges))
        acc.flow[i, t, sampleid] = problem.fp.edges[e_f].flow -
                                   problem.fp.edges[e_r].flow
    end

    return

end

reset!(acc::Results.FlowSamplesAccumulator, sampleid::Int) = nothing

# Utilization

function record!(
    acc::Results.UtilizationAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    edges = problem.fp.edges

    for (i, (f, b)) in enumerate(zip(problem.interface_forward_edges,
                                     problem.interface_reverse_edges))

        util = utilization(problem.fp.edges[f], problem.fp.edges[b])
        acc.util_interface_currentsim[i] += util
        fit!(acc.util_interfaceperiod[i,t], util)

    end

end

function reset!(acc::Results.UtilizationAccumulator, sampleid::Int)

    for i in eachindex(acc.util_interface_currentsim)
        fit!(acc.util_interface[i], acc.util_interface_currentsim[i])
        acc.util_interface_currentsim[i] = 0
    end

end

# UtilizationSamples

function record!(
    acc::Results.UtilizationSamplesAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    for (i, (e_f, e_r)) in enumerate(zip(problem.interface_forward_edges,
                                         problem.interface_reverse_edges))

        acc.utilization[i, t, sampleid] =
            utilization(problem.fp.edges[e_f], problem.fp.edges[e_r])

    end

    return

end

reset!(acc::Results.UtilizationSamplesAccumulator, sampleid::Int) = nothing

# GeneratorAvailability

function record!(
    acc::Results.GenAvailabilityAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    acc.available[:, t, sampleid] .= state.gens_available
    return

end

reset!(acc::Results.GenAvailabilityAccumulator, sampleid::Int) = nothing

# StorageAvailability

function record!(
    acc::Results.StorAvailabilityAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    acc.available[:, t, sampleid] .= state.stors_available
    return

end

reset!(acc::Results.StorAvailabilityAccumulator, sampleid::Int) = nothing

# GeneratorStorageAvailability

function record!(
    acc::Results.GenStorAvailabilityAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    acc.available[:, t, sampleid] .= state.genstors_available
    return

end

reset!(acc::Results.GenStorAvailabilityAccumulator, sampleid::Int) = nothing

# DemandResponseAvailability

function record!(
    acc::Results.DRAvailabilityAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    acc.available[:, t, sampleid] .= state.drs_available
    return

end

reset!(acc::Results.DRAvailabilityAccumulator, sampleid::Int) = nothing


# LineAvailability

function record!(
    acc::Results.LineAvailabilityAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    acc.available[:, t, sampleid] .= state.lines_available
    return

end

reset!(acc::Results.LineAvailabilityAccumulator, sampleid::Int) = nothing

# StorageEnergy

function record!(
    acc::Results.StorageEnergyAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    totalenergy = 0
    nstorages = length(system.storages)

    for s in 1:nstorages

        storageenergy = state.stors_energy[s]
        fit!(acc.energy_storageperiod[s,t], storageenergy)
        totalenergy += storageenergy

    end

    fit!(acc.energy_period[t], totalenergy)

    return

end

reset!(acc::Results.StorageEnergyAccumulator, sampleid::Int) = nothing

# GeneratorStorageEnergy

function record!(
    acc::Results.GenStorageEnergyAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    totalenergy = 0
    ngenstors = length(system.generatorstorages)

    for s in 1:ngenstors

        genstorenergy = state.genstors_energy[s]
        fit!(acc.energy_genstorperiod[s,t], genstorenergy)
        totalenergy += genstorenergy

    end

    fit!(acc.energy_period[t], totalenergy)

    return

end

reset!(acc::Results.GenStorageEnergyAccumulator, sampleid::Int) = nothing


# DemandResponseEnergy

function record!(
    acc::Results.DemandResponseEnergyAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    totalenergy = 0
    ndemandresponses = length(system.demandresponses)

    for s in 1:ndemandresponses

        drenergy = state.drs_energy[s]
        fit!(acc.energy_demandresponseperiod[s,t], drenergy)
        totalenergy += drenergy

    end

    fit!(acc.energy_period[t], totalenergy)

    return

end

reset!(acc::Results.DemandResponseEnergyAccumulator, sampleid::Int) = nothing



# StorageEnergySamples

function record!(
    acc::Results.StorageEnergySamplesAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    acc.energy[:, t, sampleid] .= state.stors_energy
    return

end

reset!(acc::Results.StorageEnergySamplesAccumulator, sampleid::Int) = nothing

# GeneratorStorageEnergySamples

function record!(
    acc::Results.GenStorageEnergySamplesAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    acc.energy[:, t, sampleid] .= state.genstors_energy
    return

end

reset!(acc::Results.GenStorageEnergySamplesAccumulator, sampleid::Int) = nothing


# DemandResponseEnergySamples

function record!(
    acc::Results.DemandResponseEnergySamplesAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    acc.energy[:, t, sampleid] .= state.drs_energy
    return

end

reset!(acc::Results.DemandResponseEnergySamplesAccumulator, sampleid::Int) = nothing