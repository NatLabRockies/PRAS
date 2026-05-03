function initialize_availability!(
    rng::AbstractRNG,
    availability::Vector{Bool}, nexttransition::Vector{Int},
    devices::AbstractAssets, t_last::Int)

    for i in 1:length(devices)

        λ = devices.λ[i, 1]
        μ = devices.μ[i, 1]
        online = rand(rng) < μ / (λ + μ)

        availability[i] = online

        transitionprobs = online ? devices.λ : devices.μ
        nexttransition[i] = randtransitiontime(
            rng, transitionprobs, i, 1, t_last)

    end

    return availability

end

function update_availability!(
    rng::AbstractRNG,
    availability::Vector{Bool}, nexttransition::Vector{Int},
    devices::AbstractAssets, t_now::Int, t_last::Int)

    for i in 1:length(devices)

        if nexttransition[i] == t_now # Unit switches states
            transitionprobs = (availability[i] ⊻= true) ? devices.λ : devices.μ
            nexttransition[i] = randtransitiontime(
                rng, transitionprobs, i, t_now, t_last)
        end

    end

end

function randtransitiontime(
    rng::AbstractRNG, p::Matrix{Float64},
    i::Int, t_now::Int, t_last::Int
)

    cdf = 0.
    p_noprevtransition = 1.

    x = rand(rng)
    t = t_now + 1

    while t <= t_last
        p_it = p[i,t]
        cdf += p_noprevtransition * p_it
        x < cdf && return t
        p_noprevtransition *= (1. - p_it)
        t += 1
    end

    return t_last + 1

end

function available_capacity(
    availability::Vector{Bool},
    lines::Lines,
    idxs::UnitRange{Int}, t::Int
)

    avcap_forward = 0
    avcap_backward = 0

    for i in idxs
        if availability[i]
            avcap_forward += lines.forward_capacity[i, t]
            avcap_backward += lines.backward_capacity[i, t]
        end
    end

    return avcap_forward, avcap_backward

end

function available_capacity(
    availability::Vector{Bool},
    gens::Generators,
    idxs::UnitRange{Int}, t::Int
)

    caps = gens.capacity
    avcap = 0

    for i in idxs
        availability[i] && (avcap += caps[i, t])
    end

    return avcap

end

function update_energy!(
    stors_energy::Vector{Int},
    stors::AbstractAssets,
    t::Int
)

    for i in 1:length(stors_energy)

        soc = stors_energy[i]
        efficiency = stors.carryover_efficiency[i,t]
        maxenergy = stors.energy_capacity[i,t]

        # Decay SoC
        soc = round(Int, soc * efficiency)

        # Shed SoC above current energy limit
        stors_energy[i] = min(soc, maxenergy)

    end

end

function update_dr_energy!(
    drs_energy::Vector{Int},
    drs_unservedenergy::Vector{Int},
    drs::AbstractAssets,
    t::Int
)

    for i in 1:length(drs_energy)

        soc = drs_energy[i]
        borrowed_energy_interest = drs.borrowed_energy_interest[i,t] + 1.0
        maxenergy = drs.energy_capacity[i,t]

        # Decay SoC
        soc = round(Int, soc * borrowed_energy_interest)

        unserved_energy_above_max_energy = max(0, soc - maxenergy)

        # Shed SoC above current energy limit
        drs_energy[i] = min(soc, maxenergy)

        drs_unservedenergy[i] = unserved_energy_above_max_energy
    end

end

function update_paybackcounter!(
    payback_counter::Vector{Int},
    drs_energy::Vector{Int},
    drs::AbstractAssets,
    t::Int
)

    for i in 1:length(payback_counter)
        #if energy is zero or negative, set counter to -1 (to start counting new)
        if drs_energy[i] <= 0
            if payback_counter[i] >= 0
                #if no energy borrowed and counter is positive, reset it to -1
                payback_counter[i] = -1
            end
        elseif payback_counter[i] == -1
            #if energy is borrowed and counter is -1, set it to payback window-start of counting
            payback_counter[i] =  drs.allowable_payback_period[i,t]-1
        elseif payback_counter[i] >= 0
            #if counter is positive, decrement by one
            payback_counter[i] -= 1
        end


    end

end


function maxtimetocharge_discharge(system::SystemModel)

    if length(system.storages) > 0

        if any(iszero, system.storages.charge_capacity)
            stor_charge_max = length(system.timestamps) + 1
        else
            stor_charge_durations =
                system.storages.energy_capacity ./ system.storages.charge_capacity
            stor_charge_max = ceil(Int, maximum(stor_charge_durations))
        end

        if any(iszero, system.storages.discharge_capacity)
            stor_discharge_max = length(system.timestamps) + 1
        else
            stor_discharge_durations =
                system.storages.energy_capacity ./ system.storages.discharge_capacity
            stor_discharge_max = ceil(Int, maximum(stor_discharge_durations))
        end

    else

        stor_charge_max = 0
        stor_discharge_max = 0

    end

    if length(system.generatorstorages) > 0

        if any(iszero, system.generatorstorages.charge_capacity)
            genstor_charge_max = length(system.timestamps) + 1
        else
            genstor_charge_durations =
                system.generatorstorages.energy_capacity ./ system.generatorstorages.charge_capacity
            genstor_charge_max = ceil(Int, maximum(genstor_charge_durations))
        end

        if any(iszero, system.generatorstorages.discharge_capacity)
            genstor_discharge_max = length(system.timestamps) + 1
        else
            genstor_discharge_durations =
                system.generatorstorages.energy_capacity ./ system.generatorstorages.discharge_capacity
            genstor_discharge_max = ceil(Int, maximum(genstor_discharge_durations))
        end

    else

        genstor_charge_max = 0
        genstor_discharge_max = 0

    end

    return (max(stor_charge_max, genstor_charge_max),
            max(stor_discharge_max, genstor_discharge_max))

end

function max_payback_window_dr(system::SystemModel)

    if length(system.demandresponses) > 0
        #no need to check for zero since allowable_payback_period is force to positive
        maxpaybacktime_dr = maximum(system.demandresponses.allowable_payback_period)
    else
        maxpaybacktime_dr = 0
    end

    return maxpaybacktime_dr

end

function init_regionshortfall(
    ::Type{S},
    edges,
    region) where {S <: Union{
                            Results.Shortfall,
                            Results.ShortfallSamples,
                            Results.ShortfallEvents}}
    return edges[region].flow
end

function init_regionshortfall(
    ::Type{S},
    edges,
    region) where {S <: Union{
                            Results.DemandResponseShortfall,
                            Results.DemandResponseShortfallSamples}}
    return 0
end

function utilization(f::MinCostFlows.Edge, b::MinCostFlows.Edge)

    flow_forward = f.flow
    max_forward = f.limit

    flow_back = b.flow
    max_back = b.limit

    util = if flow_forward > 0
        flow_forward/max_forward
    elseif flow_back > 0
        flow_back/max_back
    elseif iszero(max_forward) && iszero(max_back)
        1.0
    else
        0.0
    end

    return util

end
