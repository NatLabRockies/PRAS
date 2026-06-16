function generate_systemresult(shortfall::AbstractShortfallResult, pras_sys::SystemModel)
    
    region_results = RegionResult[]
    shortfall_mean = get_shortfall_mean(shortfall)
    for (idx,reg_name) in enumerate(pras_sys.regions.names)
        region_gen_cats = unique(pras_sys.generators.categories[pras_sys.region_gen_idxs[idx]])
        region_stor_cats = unique(pras_sys.storages.categories[pras_sys.region_stor_idxs[idx]])
        append!(region_gen_cats,region_stor_cats)
        region_gen_cap = pras_sys.generators.capacity[pras_sys.region_gen_idxs[idx],:]
        region_stor_cap = pras_sys.storages.energy_capacity[pras_sys.region_stor_idxs[idx],:]

        installed_cap = Dict(region_gen_cats .=> [Vector{Int64}[] for i in range(1,length=length(region_gen_cats))])
        for (gen_idx,gen_cat) in enumerate(pras_sys.generators.categories[pras_sys.region_gen_idxs[idx]])
            push!(installed_cap[gen_cat],region_gen_cap[gen_idx,:])
        end
        for (gen_idx,gen_cat) in enumerate(pras_sys.storages.categories[pras_sys.region_stor_idxs[idx]])
            push!(installed_cap[gen_cat],region_stor_cap[gen_idx,:])
        end

        capacity = Dict(map(=>, keys(installed_cap), sum.(values(installed_cap))))
        peak_load = maximum(pras_sys.regions.load[idx,:])
        reg_shortfall_mean = shortfall_mean[idx,:]
        shortfall_timestamps = collect(shortfall.timestamps)[findall(reg_shortfall_mean .!= 0.0)]

        push!(region_results,
        RegionResult(
            reg_name,
            EUEResult(shortfall, region = reg_name),
            LOLEResult(shortfall, region = reg_name),
            NEUEResult(shortfall, region = reg_name),
            get_lold_result(shortfall, region = reg_name),
            pras_sys.regions.load[idx,:],
            peak_load,
            capacity,
            reg_shortfall_mean,
            shortfall_timestamps,
        )
        )

    end

    sys_result = SystemResult(
        get_nsamples(shortfall),
        TypeParams(pras_sys),
        pras_sys.attrs,
        collect(shortfall.timestamps),
        EUEResult(shortfall),
        LOLEResult(shortfall),
        NEUEResult(shortfall),
        get_lold_result(shortfall),
        region_results,
    )

    return sys_result

end

"""
    saveshortfall(
        shortfall::AbstractShortfallResult,
        pras_sys::SystemModel,
        outfile::String,
    )

Save ShortfallResult or ShortfallSample Result in JSON format. Only aggregate system and region level results are exported. Sample level results are not exported..

# Arguments

    - `shortfall::AbstractShortfallResult`: ShortfallResult (or) ShortfallSamplesResult
    - `pras_sys::SystemModel`: PRAS SystemModel
    - `outfile::String`: Location to save the ShortfallResult

# Returns

  - Location where ShortfallResult (or) ShortfallSamplesResult is exported in JSON format.
"""
function saveshortfall(
    shortfall::AbstractShortfallResult,
    pras_sys::SystemModel,
    outfile::String,
)
    _lold_warned[] = false
    
    dt_now = format(now(), "dd-u-yy-H-M-S")
    export_location = joinpath(outfile, dt_now)
    if ~(isdir(export_location))
        mkpath(export_location)
    end

    sys_result = generate_systemresult(shortfall, pras_sys);
    open(joinpath(export_location, "pras_results.json"), "w") do io
        pretty(io, sys_result)
    end

    @info "Successfully exported PRAS ShortfallResult here: $(export_location)"
    return export_location
end

function saveshortfall(
    shortfall::R,
    pras_sys::SystemModel,
    outfile::String,
) where {R <: Result}

    error("saveshortfall is not implemented for $(typeof(shortfall))")
end
