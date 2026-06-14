function pvalue(lower::T, upper::T) where {T<:ReliabilityMetric}

    vl = val(lower)
    sl = stderror(lower)

    vu = val(upper)
    su = stderror(upper)

    if iszero(sl) && iszero(su)
        result = Float64(vl ≈ vu)
    else
        # single-sided z-test with null hypothesis that (vu - vl) not > 0
        z = (vu - vl) / sqrt(su^2 + sl^2)
        result = ccdf(Normal(), z)
    end

    return result

end

function allocate_regions(
    region_names::Vector{String},
    regionname_shares::Vector{Tuple{String,Float64}}
)

    region_allocations = similar(regionname_shares, Tuple{Int,Float64})

    for (i, (name, share)) in enumerate(regionname_shares)

        r = findfirst(isequal(name), region_names)

        isnothing(r) &&
            error("$name is not a region name in the provided systems")

        region_allocations[i] = (r, share)

    end

    return sort!(region_allocations)

end

incr_range(rnge::UnitRange{Int}, inc::Int) = rnge .+ inc
incr_range(rnge::UnitRange{Int}, inc1::Int, inc2::Int) =
    (first(rnge) + inc1):(last(rnge) + inc2)

function copy_load(
    sys::SystemModel{N,L,T,P,E},
    region_shares::Vector{Tuple{String,Float64}}
) where {N,L,T,P,E}

    region_allocations = allocate_regions(sys.regions.names, region_shares)

    new_regions = Regions{N,P}(sys.regions.names, copy(sys.regions.load))

    return region_allocations, sys.regions.load, SystemModel(
        new_regions, sys.interfaces,
        sys.generators, sys.region_gen_idxs,
        sys.storages, sys.region_stor_idxs,
        sys.generatorstorages, sys.region_genstor_idxs,
        sys.lines, sys.interface_line_idxs, sys.timestamps)

end

function update_load!(
    sys::SystemModel,
    region_shares::Vector{Tuple{Int,Float64}},
    load_base::Matrix{Int},
    load_increase::Int
)
    for (r, share) in region_shares
        sys.regions.load[r, :] .= load_base[r, :] .+
                                  round(Int, share * load_increase)
    end

end

function add_firmcapacity(
    s1::SystemModel{N,L,T,P,E}, s2::SystemModel{N,L,T,P,E},
    region_shares::Vector{Tuple{String,Float64}}
) where {N,L,T,P,E}

    n_regions = length(s1.regions.names)
    n_region_allocs = length(region_shares)

    region_allocations = allocate_regions(s1.regions.names, region_shares)
    efc_gens = similar(region_allocations)

    new_gen(i::Int) = Generators{N,L,T,P}(
        ["_EFC_$i"], ["_EFC Calculation Dummy Generator"],
        zeros(Int, 1, N), zeros(1, N), ones(1, N))

    variable_gens = Generators{N,L,T,P}[]
    variable_region_gen_idxs = similar(s1.region_gen_idxs)

    target_gens = similar(variable_gens)
    target_region_gen_idxs = similar(s2.region_gen_idxs)

    ra_idx = 0

    for r in 1:n_regions

        s1_range = s1.region_gen_idxs[r]
        s2_range = s2.region_gen_idxs[r]

        if (ra_idx < n_region_allocs) && (r == first(region_allocations[ra_idx+1]))

            ra_idx += 1

            variable_region_gen_idxs[r] = incr_range(s1_range, ra_idx-1, ra_idx)
            target_region_gen_idxs[r] = incr_range(s2_range, ra_idx-1, ra_idx)

            gen = new_gen(ra_idx)
            push!(variable_gens, gen)
            push!(target_gens, gen)
            efc_gens[ra_idx] = (
                 first(s1_range) + ra_idx - 1,
                 last(region_allocations[ra_idx]))

        else

            variable_region_gen_idxs[r] = incr_range(s1_range, ra_idx)
            target_region_gen_idxs[r] = incr_range(s2_range, ra_idx)

        end

        push!(variable_gens, s1.generators[s1_range])
        push!(target_gens, s2.generators[s2_range])

    end

    sys_variable = SystemModel(
        s1.regions, s1.interfaces,
        vcat(variable_gens...), variable_region_gen_idxs,
        s1.storages, s1.region_stor_idxs,
        s1.generatorstorages, s1.region_genstor_idxs,
        s1.lines, s1.interface_line_idxs, s1.timestamps)

    sys_target = SystemModel(
        s2.regions, s2.interfaces,
        vcat(target_gens...), target_region_gen_idxs,
        s2.storages, s2.region_stor_idxs,
        s2.generatorstorages, s2.region_genstor_idxs,
        s2.lines, s2.interface_line_idxs, s2.timestamps)

    return efc_gens, sys_variable, sys_target

end

function update_firmcapacity!(
    sys::SystemModel, gens::Vector{Tuple{Int,Float64}}, capacity::Int)

    for (g, share) in gens
        sys.generators.capacity[g, :] .= round(Int, share * capacity)
    end

end
