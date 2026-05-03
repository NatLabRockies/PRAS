"""
    DispatchProblem(sys::SystemModel)

Create a min-cost flow problem for the multi-region max power delivery problem
with generation and storage discharging in decreasing order of priority,
storage charging with excess capacity and demand response devices enabling load shed and shift functionality.
Storage, GeneratorStorage, and Demand Response devices within a region are represented individually on the network.


This involves injections/withdrawals at one node (regional capacity
surplus/shortfall) for each modelled region, as well as two/three nodes
associated with each Storage/GeneratorStorage device, and a supplementary
"slack" node in the network that can absorb undispatched power or pass
unserved energy or unused charging capability through to satisfy
power balance constraints. Demand Response devices are represented
in a structurally similar manner as storage charging and discharging.

Flows from the generation nodes are free, while flows to charging and
from discharging nodes are costed or rewarded according to the
time-to-discharge of the storage device, ensuring efficient coordination
across units, while enforcing that storage is only discharged once generation
capacity is exhausted (implying an operational strategy that prioritizes
resource adequacy over economic arbitrage). This is based on the storage
dispatch strategy of Evans, Tindemans, and Angeli, as outlined in "Minimizing
Unserved Energy Using Heterogenous Storage Units" (IEEE Transactions on Power
Systems, 2019). Demand Response devices will borrow energy in devices with the 
longest payback window first, and vice versa for payback energy. 
Demand Response devices are utilized only after discharging all storage/genstor
and paid back before storage/genstor charging.

Flows to the charging node have an attenuated negative cost (reward),
incentivizing immediate storage charging if generation and transmission
allows it, while avoiding charging by discharging other storage (since that
would incur an overall positive cost).

Flows to the slack node (representing unused generation or storage discharge
capacity) are free, but flows from the slack node to serve load incur the lost
load penalty of 9999. Flows from the slack node in lieu of storage charging
or discharging are free.

Flows on transmission interfaces assume a hurdle rate of 1
to keep unserved energy close to the source of the shortage and eliminate
loop flows. This has the side-effect of disincentivising wheeling power across
multiple regions for charging purposes, however.

Nodes in the problem are ordered as:

 1. Regions generation surplus/shortfall (Regions order)
 2. Storage discharge capacity (Storage order)
 3. Storage charge capacity (Storage order)
 4. GenerationStorage inflow capacity (GeneratorStorage order)
 5. GenerationStorage discharge capacity (GeneratorStorage order)
 6. GenerationStorage grid injection (GeneratorStorage order)
 7. GenerationStorage charge capacity (GeneratorStorage order)
 8. DemandResponse payback capacity (DemandResponse order)
 9. DemandResponse borrowing capacity (DemandResponse order)
 10. Slack node

Edges are ordered as:

 1. Regions demand unserved (Regions order)
 2. Regions generation unused (Regions order)
 3. Interfaces forward flow (Interfaces order)
 4. Interfaces reverse flow (Interfaces order)
 5. Storage discharge to grid (Storage order)
 6. Storage discharge unused (Storage order)
 7. Storage charge from grid (Storage order)
 8. Storage charge unused (Storage order)
 9. GenerationStorage discharge to grid (GeneratorStorage order)
 10. GenerationStorage discharge unused (GeneratorStorage order)
 11. GenerationStorage inflow to grid (GenerationStorage order)
 12. GenerationStorage total to grid (GeneratorStorage order)
 13. GenerationStorage charge from grid (GeneratorStorage order)
 14. GenerationStorage charge from inflow (GeneratorStorage order)
 15. GenerationStorage charge unused (GeneratorStorage order)
 16. GenerationStorage inflow unused (GeneratorStorage order)
 17. DemandResponse payback to grid (DemandResponse order)
 18. DemandResponse payback unused (DemandResponse order)
 19. DemandResponse borrowing from grid (DemandResponse order)
 20. DemandResponse borrowing unused (DemandResponse order)
"""
struct DispatchProblem

    fp::FlowProblem

    # Node labels
    region_nodes::UnitRange{Int}
    storage_discharge_nodes::UnitRange{Int}
    storage_charge_nodes::UnitRange{Int}
    genstorage_inflow_nodes::UnitRange{Int}
    genstorage_discharge_nodes::UnitRange{Int}
    genstorage_togrid_nodes::UnitRange{Int}
    genstorage_charge_nodes::UnitRange{Int}
    demandresponse_payback_nodes::UnitRange{Int}
    demandresponse_borrow_nodes::UnitRange{Int}
    slack_node::Int

    # Edge labels
    region_unserved_edges::UnitRange{Int}
    region_unused_edges::UnitRange{Int}
    interface_forward_edges::UnitRange{Int}
    interface_reverse_edges::UnitRange{Int}
    storage_discharge_edges::UnitRange{Int}
    storage_dischargeunused_edges::UnitRange{Int}
    storage_charge_edges::UnitRange{Int}
    storage_chargeunused_edges::UnitRange{Int}
    genstorage_dischargegrid_edges::UnitRange{Int}
    genstorage_dischargeunused_edges::UnitRange{Int}
    genstorage_inflowgrid_edges::UnitRange{Int}
    genstorage_totalgrid_edges::UnitRange{Int}
    genstorage_gridcharge_edges::UnitRange{Int}
    genstorage_inflowcharge_edges::UnitRange{Int}
    genstorage_chargeunused_edges::UnitRange{Int}
    genstorage_inflowunused_edges::UnitRange{Int}
    demandresponse_payback_edges::UnitRange{Int}
    demandresponse_paybackunused_edges::UnitRange{Int}
    demandresponse_borrow_edges::UnitRange{Int}
    demandresponse_borrowunused_edges::UnitRange{Int}

    #stor/genstor costs
    min_chargecost::Int
    max_dischargecost::Int

    #dr costs
    max_borrowcost_dr::Int
    min_paybackcost_dr::Int

    function DispatchProblem(
        sys::SystemModel; unlimited::Int=999_999_999)

        nregions = length(sys.regions)
        nifaces = length(sys.interfaces)
        nstors = length(sys.storages)
        ngenstors = length(sys.generatorstorages)
        ndrs = length(sys.demandresponses)


        #Implied merit order:
        # dr payback_cost < stor/genstor charge cost < stor/genstor discharge cost < borrow cost < unserved energy

        #for storage/genstor
        maxchargetime, maxdischargetime = maxtimetocharge_discharge(sys)
        min_chargecost = - maxchargetime - 1
        max_dischargecost = - min_chargecost + maxdischargetime + 1

        #for demand response-we want to borrow energy in devices with the longest payback window, and payback energy from devices with the smallest payback window
        maxpaybacktime_dr = max_payback_window_dr(sys)
        cost_for_storage_wheeling_prevention = 75 #prevent storage discharging and wheeling across large number of regions which then results in it being cheaper to borrow than to discharge from storage
        min_paybackcost_dr = - max_dischargecost - maxpaybacktime_dr - 1 - cost_for_storage_wheeling_prevention #add max_dischargecost (will mean greater than storage charge as well) to always have DR devices be paybacked first
        max_borrowcost_dr = - min_paybackcost_dr + maxpaybacktime_dr + 1 #will always be greater than max_dischargecost and paybacktime, need to add 1 to not overlap with payback reward

        #for unserved energy
        shortagepenalty = 10 * (nifaces + max_borrowcost_dr)


        stor_regions = assetgrouplist(sys.region_stor_idxs)
        genstor_regions = assetgrouplist(sys.region_genstor_idxs)
        dr_regions = assetgrouplist(sys.region_dr_idxs)

        region_nodes = 1:nregions
        stor_discharge_nodes = indices_after(region_nodes, nstors)
        stor_charge_nodes = indices_after(stor_discharge_nodes, nstors)
        genstor_inflow_nodes = indices_after(stor_charge_nodes, ngenstors)
        genstor_discharge_nodes = indices_after(genstor_inflow_nodes, ngenstors)
        genstor_togrid_nodes = indices_after(genstor_discharge_nodes, ngenstors)
        genstor_charge_nodes = indices_after(genstor_togrid_nodes, ngenstors)
        dr_payback_nodes = indices_after(genstor_charge_nodes, ndrs)        
        dr_borrow_nodes = indices_after(dr_payback_nodes, ndrs)
        slack_node = nnodes = last(dr_borrow_nodes) + 1

        region_unservedenergy = 1:nregions
        region_unusedcapacity = indices_after(region_unservedenergy, nregions)
        iface_forward = indices_after(region_unusedcapacity, nifaces)
        iface_reverse = indices_after(iface_forward, nifaces)
        stor_dischargeused = indices_after(iface_reverse, nstors)
        stor_dischargeunused = indices_after(stor_dischargeused, nstors)
        stor_chargeused = indices_after(stor_dischargeunused, nstors)
        stor_chargeunused = indices_after(stor_chargeused, nstors)
        genstor_dischargegrid = indices_after(stor_chargeunused, ngenstors)
        genstor_dischargeunused = indices_after(genstor_dischargegrid, ngenstors)
        genstor_inflowgrid = indices_after(genstor_dischargeunused, ngenstors)
        genstor_totalgrid = indices_after(genstor_inflowgrid, ngenstors)
        genstor_gridcharge = indices_after(genstor_totalgrid, ngenstors)
        genstor_inflowcharge = indices_after(genstor_gridcharge, ngenstors)
        genstor_chargeunused = indices_after(genstor_inflowcharge, ngenstors)
        genstor_inflowunused = indices_after(genstor_chargeunused, ngenstors)
        dr_paybackused = indices_after(genstor_inflowunused, ndrs)
        dr_paybackunused = indices_after(dr_paybackused, ndrs)       
        dr_borrowused = indices_after(dr_paybackunused, ndrs)
        dr_borrowunused = indices_after(dr_borrowused, ndrs)   
        nedges = last(dr_borrowunused)

        nodesfrom = Vector{Int}(undef, nedges)
        nodesto = Vector{Int}(undef, nedges)
        costs = zeros(Int, nedges)
        limits = fill(unlimited, nedges)
        injections = zeros(Int, nnodes)

        function initedges(idxs::UnitRange{Int}, from::AbstractVector{Int}, to::AbstractVector{Int})
            nodesfrom[idxs] = from
            nodesto[idxs] = to
        end

        function initedges(idxs::UnitRange{Int}, from::AbstractVector{Int}, to::Int)
            nodesfrom[idxs] = from
            nodesto[idxs] .= to
        end

        function initedges(idxs::UnitRange{Int}, from::Int, to::AbstractVector{Int})
            nodesfrom[idxs] .= from
            nodesto[idxs] = to
        end

        # Unserved energy edges
        initedges(region_unservedenergy, slack_node, region_nodes)
        costs[region_unservedenergy] .= shortagepenalty

        # Unused generation edges
        initedges(region_unusedcapacity, region_nodes, slack_node)

        # Transmission edges
        initedges(iface_forward, sys.interfaces.regions_from, sys.interfaces.regions_to)
        costs[iface_forward] .= 1
        initedges(iface_reverse, sys.interfaces.regions_to, sys.interfaces.regions_from)
        costs[iface_reverse] .= 1

        # Storage discharging / charging
        initedges(stor_dischargeused, stor_discharge_nodes, stor_regions)
        initedges(stor_dischargeunused, stor_discharge_nodes, slack_node)
        initedges(stor_chargeused, stor_regions, stor_charge_nodes)
        initedges(stor_chargeunused, slack_node, stor_charge_nodes)

        # GeneratorStorage discharging / grid injections
        initedges(genstor_dischargegrid, genstor_discharge_nodes, genstor_togrid_nodes)
        initedges(genstor_dischargeunused, genstor_discharge_nodes, slack_node)
        initedges(genstor_inflowgrid, genstor_inflow_nodes, genstor_togrid_nodes)
        initedges(genstor_totalgrid, genstor_togrid_nodes, genstor_regions)

        # GeneratorStorage charging
        initedges(genstor_gridcharge, genstor_regions, genstor_charge_nodes)
        initedges(genstor_inflowcharge, genstor_inflow_nodes, genstor_charge_nodes)
        initedges(genstor_chargeunused, slack_node, genstor_charge_nodes)
        initedges(genstor_inflowunused, genstor_inflow_nodes, slack_node)

        # Demand Response borrowing / payback
        initedges(dr_paybackused, dr_regions, dr_payback_nodes)
        initedges(dr_paybackunused, slack_node,dr_payback_nodes)
        initedges(dr_borrowused, dr_borrow_nodes, dr_regions)
        initedges(dr_borrowunused, dr_borrow_nodes, slack_node)

        return new(

            FlowProblem(nodesfrom, nodesto, limits, costs, injections),

            region_nodes, stor_discharge_nodes, stor_charge_nodes,
            genstor_inflow_nodes, genstor_discharge_nodes,
            genstor_togrid_nodes, genstor_charge_nodes,
            dr_payback_nodes, dr_borrow_nodes, slack_node,

            region_unservedenergy, region_unusedcapacity,
            iface_forward, iface_reverse,
            stor_dischargeused, stor_dischargeunused,
            stor_chargeused, stor_chargeunused,
            genstor_dischargegrid, genstor_dischargeunused, genstor_inflowgrid,
            genstor_totalgrid,
            genstor_gridcharge, genstor_inflowcharge, genstor_chargeunused,
            genstor_inflowunused, 
            dr_paybackused, dr_paybackunused,
            dr_borrowused, dr_borrowunused,
            min_chargecost, max_dischargecost,
            max_borrowcost_dr, min_paybackcost_dr
        )

    end

end

indices_after(lastset::UnitRange{Int}, setsize::Int) =
    last(lastset) .+ (1:setsize)

function update_problem!(
    problem::DispatchProblem, state::SystemState,
    system::SystemModel{N,L,T,P,E}, t::Int
) where {N,L,T,P,E}

    fp = problem.fp
    slack_node = fp.nodes[problem.slack_node]

    # Update regional net available injection / withdrawal (from generators)
    for (r, gen_idxs) in zip(problem.region_nodes, system.region_gen_idxs)

        region_node = fp.nodes[r]

        region_netgenavailable = available_capacity(
            state.gens_available, system.generators, gen_idxs, t
            ) - system.regions.load[r, t]

        updateinjection!(region_node, slack_node, region_netgenavailable)
    end

    # Update bidirectional interface limits (from lines)
    for (i, line_idxs) in enumerate(system.interface_line_idxs)

        interface_forwardedge = fp.edges[problem.interface_forward_edges[i]]
        interface_backwardedge = fp.edges[problem.interface_reverse_edges[i]]

        lines_capacity_forward, lines_capacity_backward =
            available_capacity(state.lines_available, system.lines, line_idxs, t)

        interface_capacity_forward = min(
            lines_capacity_forward, system.interfaces.limit_forward[i,t])
        updateflowlimit!(interface_forwardedge, interface_capacity_forward)

        interface_capacity_backward = min(
            lines_capacity_backward, system.interfaces.limit_backward[i,t])
        updateflowlimit!(interface_backwardedge, interface_capacity_backward)

    end

    # Update Storage charge/discharge limits and priorities
    for (i, (charge_node, charge_edge, discharge_node, discharge_edge)) in
        enumerate(zip(
        problem.storage_charge_nodes, problem.storage_charge_edges,
        problem.storage_discharge_nodes, problem.storage_discharge_edges))

        stor_online = state.stors_available[i]
        stor_energy = state.stors_energy[i]
        maxenergy = system.storages.energy_capacity[i, t]

        # Update discharging
        maxdischarge = stor_online * system.storages.discharge_capacity[i, t]
        dischargeefficiency = system.storages.discharge_efficiency[i, t]
        energydischargeable = stor_energy * dischargeefficiency

        if iszero(maxdischarge)
            timetodischarge = N + 1
        else
            timetodischarge = round(Int, energydischargeable / maxdischarge)
        end

        discharge_capacity =
            min(maxdischarge, floor(Int, energytopower(
                energydischargeable, E, L, T, P)))
        updateinjection!(
            fp.nodes[discharge_node], slack_node, discharge_capacity)

        # Largest time-to-discharge = highest priority (discharge first)
        dischargecost = problem.max_dischargecost - timetodischarge # Positive cost
        updateflowcost!(fp.edges[discharge_edge], dischargecost)

        # Update charging

        maxcharge = stor_online * system.storages.charge_capacity[i, t]
        chargeefficiency = system.storages.charge_efficiency[i, t]
        energychargeable = (maxenergy - stor_energy) / chargeefficiency

        charge_capacity =
            min(maxcharge, floor(Int, energytopower(
                energychargeable, E, L, T, P)))
        updateinjection!(
            fp.nodes[charge_node], slack_node, -charge_capacity)

        # Smallest time-to-discharge = highest priority (charge first)
        chargecost = problem.min_chargecost + timetodischarge # Negative cost
        updateflowcost!(fp.edges[charge_edge], chargecost)

    end

    # Update GeneratorStorage inflow/charge/discharge limits and priorities
    for (i, (charge_node, gridcharge_edge, inflowcharge_edge,
            discharge_node, dischargegrid_edge, totalgrid_edge,
            inflow_node)) in enumerate(zip(
        problem.genstorage_charge_nodes, problem.genstorage_gridcharge_edges,
        problem.genstorage_inflowcharge_edges, problem.genstorage_discharge_nodes,
        problem.genstorage_dischargegrid_edges, problem.genstorage_totalgrid_edges,
        problem.genstorage_inflow_nodes))

        stor_online = state.genstors_available[i]
        stor_energy = state.genstors_energy[i]
        maxenergy = system.generatorstorages.energy_capacity[i, t]

        # Update inflow and grid injection / withdrawal limits

        inflow_capacity = stor_online * system.generatorstorages.inflow[i, t]
        updateinjection!(
            fp.nodes[inflow_node], slack_node, inflow_capacity)

        gridinjection_capacity = system.generatorstorages.gridinjection_capacity[i, t]
        updateflowlimit!(fp.edges[totalgrid_edge], gridinjection_capacity)

        gridwithdrawal_capacity = system.generatorstorages.gridwithdrawal_capacity[i, t]
        updateflowlimit!(fp.edges[gridcharge_edge], gridwithdrawal_capacity)

        # Update discharging

        maxdischarge = stor_online * system.generatorstorages.discharge_capacity[i, t]
        dischargeefficiency = system.generatorstorages.discharge_efficiency[i, t]
        energydischargeable = stor_energy * dischargeefficiency

        if iszero(maxdischarge)
            timetodischarge = N + 1
        else
            timetodischarge = round(Int, energydischargeable / maxdischarge)
        end

        discharge_capacity =
            min(maxdischarge, floor(Int, energytopower(
                energydischargeable, E, L, T, P)))
        updateinjection!(
            fp.nodes[discharge_node], slack_node, discharge_capacity)

        # Largest time-to-discharge = highest priority (discharge first)
        dischargecost = problem.max_dischargecost - timetodischarge # Positive cost
        updateflowcost!(fp.edges[dischargegrid_edge], dischargecost)

        # Update charging

        maxcharge = stor_online * system.generatorstorages.charge_capacity[i, t]
        chargeefficiency = system.generatorstorages.charge_efficiency[i, t]
        energychargeable = (maxenergy - stor_energy) / chargeefficiency

        charge_capacity =
            min(maxcharge, floor(Int, energytopower(
                energychargeable, E, L, T, P)))
        updateinjection!(
            fp.nodes[charge_node], slack_node, -charge_capacity)

        # Smallest time-to-discharge = highest priority (charge first)
        chargecost = problem.min_chargecost + timetodischarge # Negative cost
        updateflowcost!(fp.edges[gridcharge_edge], chargecost)
        updateflowcost!(fp.edges[inflowcharge_edge], chargecost)

    end



    # Update Demand Response charge/discharge limits and priorities
    for (i, (borrow_node, borrow_edge, payback_node, payback_edge)) in
        enumerate(zip(
        problem.demandresponse_borrow_nodes, problem.demandresponse_borrow_edges,
        problem.demandresponse_payback_nodes, problem.demandresponse_payback_edges))

        dr_online = state.drs_available[i]
        dr_energy = state.drs_energy[i]
        maxenergy = system.demandresponses.energy_capacity[i, t]

        # Update energy payback

        maxpayback = dr_online * system.demandresponses.payback_capacity[i, t]
        paybackefficiency = system.demandresponses.payback_efficiency[i, t]
        energy_payback_allowed = dr_energy * paybackefficiency

        allowablepayback = state.drs_paybackcounter[i]

        payback_capacity =  min(
            maxpayback, floor(Int, energytopower(
            energy_payback_allowed, E, L, T, P))
            )
        updateinjection!(
            fp.nodes[payback_node], slack_node, -payback_capacity)

        # smallest allowable payback window = highest priority (payback first)
        paybackcost = problem.min_paybackcost_dr + allowablepayback
        updateflowcost!(fp.edges[payback_edge], paybackcost)

        # Update borrowing-make sure no borrowing is allowed if allowable payback period is equal to zero
        maxborrow = system.demandresponses.allowable_payback_period[i,t] != 0 ? dr_online * system.demandresponses.borrow_capacity[i, t] : 0
        borrowefficiency = system.demandresponses.borrow_efficiency[i, t]
        energyborrowable = (maxenergy - dr_energy) * borrowefficiency
        borrow_capacity =  min(
            maxborrow, floor(Int, energytopower(
            energyborrowable, E, L, T, P))
            )
        updateinjection!(
            fp.nodes[borrow_node], slack_node, borrow_capacity)

        # Longest allowable payback window = highest priority (borrow first)
        borrowcost = problem.max_borrowcost_dr - allowablepayback # Positive cost
        updateflowcost!(fp.edges[borrow_edge], borrowcost)

    end

end

function update_state!(
    state::SystemState, problem::DispatchProblem,
    system::SystemModel{N,L,T,P,E}, t::Int
) where {N,L,T,P,E}

    edges = problem.fp.edges
    p2e = conversionfactor(L, T, P, E)

    # Storage Update

    #discharging
    for (i, e) in enumerate(problem.storage_discharge_edges)
        energy = state.stors_energy[i]
        energy_drop = ceil(Int, edges[e].flow * p2e /
                                system.storages.discharge_efficiency[i, t])
        state.stors_energy[i] = max(0, energy - energy_drop)

    end
    
    #charging
    for (i, e) in enumerate(problem.storage_charge_edges)
        state.stors_energy[i] +=
            ceil(Int, edges[e].flow * p2e * system.storages.charge_efficiency[i, t])
    end

    # GeneratorStorage Update

    #discharging
    for (i, e) in enumerate(problem.genstorage_dischargegrid_edges)
        energy = state.genstors_energy[i]
        energy_drop = ceil(Int, edges[e].flow * p2e /
                                system.generatorstorages.discharge_efficiency[i, t])
        state.genstors_energy[i] = max(0, energy - energy_drop)
    end

    #charging
    for (i, (e1, e2)) in enumerate(zip(problem.genstorage_gridcharge_edges,
                                       problem.genstorage_inflowcharge_edges))
        totalcharge = (edges[e1].flow + edges[e2].flow) * p2e
        state.genstors_energy[i] +=
            ceil(Int, totalcharge * system.generatorstorages.charge_efficiency[i, t])
    end

    #Demand Response Update
    for (i, e) in enumerate(problem.demandresponse_borrow_edges)
        state.drs_energy[i] +=
            ceil(Int, edges[e].flow * p2e * system.demandresponses.borrow_efficiency[i, t])
    end

    #paybacking
    for (i, e) in enumerate(problem.demandresponse_payback_edges)
        energy = state.drs_energy[i]
        energy_drop = ceil(Int, edges[e].flow * p2e / system.demandresponses.payback_efficiency[i, t])
        state.drs_energy[i] = max(0, energy - energy_drop)

        if (state.drs_paybackcounter[i] == 0) || (t == N)
            #if payback window is over or you reach the end of the sim, count the unserved energy in drs_unservedenergy state and reset energy
            #adding to exisiting unserved energy as we count any unserved energy above soc during borrowed_energy_interest
            #we want to keep a running total (will be either zero or the unserved energy above energy capacity)
            state.drs_unservedenergy[i] += state.drs_energy[i]
            state.drs_energy[i] = 0
        end
    end





end

function assetgrouplist(idxss::Vector{UnitRange{Int}})
    results = Vector{Int}(undef, last(idxss[end]))
    for (g, idxs) in enumerate(idxss)
        results[idxs] .= g
    end
    return results
end
