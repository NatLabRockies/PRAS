struct ELCC{M} <: CapacityValuationMethod{M}

    capacity_max::Int
    capacity_gap::Int
    p_value::Float64
    regions::Vector{Tuple{String,Float64}}
    verbose::Bool

    function ELCC{M}(
        capacity_max::Int, regions::Vector{Pair{String,Float64}};
        capacity_gap::Int=1, p_value::Float64=0.05, verbose::Bool=false) where M

        @assert capacity_max > 0
        @assert capacity_gap > 0
        @assert 0 < p_value < 1
        @assert sum(x.second for x in regions) ≈ 1.0

        return new{M}(capacity_max, capacity_gap, p_value, Tuple.(regions), verbose)

    end

end

function ELCC{M}(
    capacity_max::Int, region::String; kwargs...
) where M
    return ELCC{M}(capacity_max, [region=>1.0]; kwargs...)
end

function assess(sys_baseline::S, sys_augmented::S,
                params::ELCC{M}, simulationspec::SequentialMonteCarlo
) where {N, L, T, P, S <: SystemModel{N,L,T,P}, M <: ReliabilityMetric}

    _, powerunit, _ = unitsymbol(sys_baseline)

    regionnames = sys_baseline.regions.names
    regionnames != sys_augmented.regions.names &&
        error("Systems provided do not have matching regions")

    target_metric = M(first(assess(sys_baseline, simulationspec, Shortfall())))

    capacities = Int[]
    metrics = typeof(target_metric)[]

    elcc_regions, base_load, sys_variable =
        copy_load(sys_augmented, params.regions)

    lower_bound = 0
    lower_bound_metric = M(first(assess(sys_variable, simulationspec, Shortfall())))
    push!(capacities, lower_bound)
    push!(metrics, lower_bound_metric)

    upper_bound = params.capacity_max
    update_load!(sys_variable, elcc_regions, base_load, upper_bound)
    upper_bound_metric = M(first(assess(sys_variable, simulationspec, Shortfall())))
    push!(capacities, upper_bound)
    push!(metrics, upper_bound_metric)

    while true

        params.verbose && println(
            "\n$(lower_bound) $powerunit\t< ELCC <\t$(upper_bound) $powerunit\n",
            "$(lower_bound_metric)\t< $(target_metric) <\t$(upper_bound_metric)")

        midpoint = div(lower_bound + upper_bound, 2)
        capacity_gap = upper_bound - lower_bound

        # Stopping conditions

        ## Return the bounds if they are within solution tolerance of each other
        if capacity_gap <= params.capacity_gap
            params.verbose && @info "Capacity bound gap within tolerance, stopping bisection."
            break
        end

        # If the null hypothesis upper_bound_metric !>= lower_bound_metric
        # cannot be rejected, terminate and return the loose bounds
        pval = pvalue(lower_bound_metric, upper_bound_metric)
        if pval >= params.p_value
            @warn "Gap between upper and lower bound risk metrics is not " *
                  "statistically significant (p_value=$pval), stopping bisection. " *
                  "The gap between capacity bounds is $(capacity_gap) $powerunit, " *
                  "while the target stopping gap was $(params.capacity_gap) $powerunit."
            break
        end

        # Evaluate metric at midpoint
        update_load!(sys_variable, elcc_regions, base_load, midpoint)
        midpoint_metric = M(first(assess(sys_variable, simulationspec, Shortfall())))
        push!(capacities, midpoint)
        push!(metrics, midpoint_metric)

        # Tighten capacity bounds
        if val(midpoint_metric) < val(target_metric)
            lower_bound = midpoint
            lower_bound_metric = midpoint_metric
        else # midpoint_metric <= target_metric
            upper_bound = midpoint
            upper_bound_metric = midpoint_metric
        end

    end

    return CapacityCreditResult{typeof(params), typeof(target_metric), P}(
        target_metric, lower_bound, upper_bound, capacities, metrics)

end


