"""

    SystemModel(filename::String)

Load a `SystemModel` from an appropriately-formatted HDF5 file on disk.
These files typically have a .pras filename extension.

# Examples

```julia
sys = SystemModel("path/to/prasfile.pras")
```
"""
function SystemModel(inputfile::String)

    system = h5open(inputfile, "r") do f::File

        version, versionstring = readversion(f)

        # Determine the appropriate version of the importer to use
        return if (0,5,0) <= version < (0,8,0)
            systemmodel_0_5(f)
        elseif (0,8,0) <= version < (0,9,0)
            systemmodel_0_8(f)
        else
            error("PRAS file format $versionstring not supported by this version of PRASBase.")
        end

    end

    return system

end

"""
Unexposed function which encapsulates the SystemModel reading logic from PRAS 
versions 0.5.x to 0.7.x., and is also used in version 0.8.x+ to read the 
components from the SystemModel which exist in the new format as well.
"""
function _systemmodel_core(f::File)
    
    metadata = attributes(f)

    start_timestamp = ZonedDateTime(read(metadata["start_timestamp"]),
                                    dateformat"yyyy-mm-ddTHH:MM:SSz")

    N = Int(read(metadata["timestep_count"]))
    L = Int(read(metadata["timestep_length"]))
    T = timeunits[read(metadata["timestep_unit"])]
    P = powerunits[read(metadata["power_unit"])]
    E = energyunits[read(metadata["energy_unit"])]

    type_params = (N,L,T,P,E)

    timestep = T(L)
    end_timestamp = start_timestamp + (N-1)*timestep
    timestamps = StepRange(start_timestamp, timestep, end_timestamp)

    has_regions = haskey(f, "regions")
    has_generators = haskey(f, "generators")
    has_storages = haskey(f, "storages")
    has_generatorstorages = haskey(f, "generatorstorages")
    has_interfaces = haskey(f, "interfaces")
    has_lines = haskey(f, "lines")

    has_regions ||
        error("Region data must be provided")

    has_generators || has_generatorstorages ||
        error("Generator or generator storage data (or both) must be provided")

    xor(has_interfaces, has_lines) &&
        error("Both (or neither) interface and line data must be provided")

    regionnames = readvector(f["regions/_core"], :name)
    regions = Regions{N,P}(
        regionnames,
        Int.(read(f["regions/load"]))
    )
    regionlookup = Dict(n=>i for (i, n) in enumerate(regionnames))
    n_regions = length(regions)

    if has_generators

        gen_core = read(f["generators/_core"])
        gen_names, gen_categories, gen_regionnames = readvector.(
            Ref(gen_core), [:name, :category, :region])

        gen_regions = getindex.(Ref(regionlookup), gen_regionnames)
        region_order = sortperm(gen_regions)

        generators = Generators{N,L,T,P}(
            gen_names[region_order], gen_categories[region_order],
            load_matrix(f["generators/capacity"], region_order, Int),
            load_matrix(f["generators/failureprobability"], region_order, Float64),
            load_matrix(f["generators/repairprobability"], region_order, Float64)
        )

        region_gen_idxs = makeidxlist(gen_regions[region_order], n_regions)

    else

        generators = Generators{N,L,T,P}()

        region_gen_idxs = fill(1:0, n_regions)

    end

    if has_storages

        stor_core = read(f["storages/_core"])
        stor_names, stor_categories, stor_regionnames = readvector.(
            Ref(stor_core), [:name, :category, :region])

        stor_regions = getindex.(Ref(regionlookup), stor_regionnames)
        region_order = sortperm(stor_regions)

        storages = Storages{N,L,T,P,E}(
            stor_names[region_order], stor_categories[region_order],
            load_matrix(f["storages/chargecapacity"], region_order, Int),
            load_matrix(f["storages/dischargecapacity"], region_order, Int),
            load_matrix(f["storages/energycapacity"], region_order, Int),
            load_matrix(f["storages/chargeefficiency"], region_order, Float64),
            load_matrix(f["storages/dischargeefficiency"], region_order, Float64),
            load_matrix(f["storages/carryoverefficiency"], region_order, Float64),
            load_matrix(f["storages/failureprobability"], region_order, Float64),
            load_matrix(f["storages/repairprobability"], region_order, Float64)
        )

        region_stor_idxs = makeidxlist(stor_regions[region_order], n_regions)

    else

        storages = Storages{N,L,T,P,E}()

        region_stor_idxs = fill(1:0, n_regions)

    end


    if has_generatorstorages

        genstor_core = read(f["generatorstorages/_core"])
        genstor_names, genstor_categories, genstor_regionnames = readvector.(
            Ref(genstor_core), [:name, :category, :region])

        genstor_regions = getindex.(Ref(regionlookup), genstor_regionnames)
        region_order = sortperm(genstor_regions)

        generatorstorages = GeneratorStorages{N,L,T,P,E}(
            genstor_names[region_order], genstor_categories[region_order],
            load_matrix(f["generatorstorages/chargecapacity"], region_order, Int),
            load_matrix(f["generatorstorages/dischargecapacity"], region_order, Int),
            load_matrix(f["generatorstorages/energycapacity"], region_order, Int),
            load_matrix(f["generatorstorages/chargeefficiency"], region_order, Float64),
            load_matrix(f["generatorstorages/dischargeefficiency"], region_order, Float64),
            load_matrix(f["generatorstorages/carryoverefficiency"], region_order, Float64),
            load_matrix(f["generatorstorages/inflow"], region_order, Int),
            load_matrix(f["generatorstorages/gridwithdrawalcapacity"], region_order, Int),
            load_matrix(f["generatorstorages/gridinjectioncapacity"], region_order, Int),
            load_matrix(f["generatorstorages/failureprobability"], region_order, Float64),
            load_matrix(f["generatorstorages/repairprobability"], region_order, Float64)
        )

        region_genstor_idxs = makeidxlist(genstor_regions[region_order], n_regions)

    else

        generatorstorages = GeneratorStorages{N,L,T,P,E}()

        region_genstor_idxs = fill(1:0, n_regions)

    end

    if has_interfaces

        interfaces_core = read(f["interfaces/_core"])
        from_regionnames, to_regionnames =
            readvector.(Ref(interfaces_core), [:region_from, :region_to])
        forwardcapacity = Int.(read(f["interfaces/forwardcapacity"]))
        backwardcapacity = Int.(read(f["interfaces/backwardcapacity"]))

        n_interfaces = length(from_regionnames)
        from_regions = getindex.(Ref(regionlookup), from_regionnames)
        to_regions = getindex.(Ref(regionlookup), to_regionnames)

        # Force interface definitions as smaller => larger region numbers
        for i in 1:n_interfaces
            from_region = from_regions[i]
            to_region = to_regions[i]
            if from_region > to_region
                from_regions[i] = to_region
                to_regions[i] = from_region
                new_forwardcapacity = backwardcapacity[i, :]
                backwardcapacity[i, :] .= forwardcapacity[i, :]
                forwardcapacity[i, :] .= new_forwardcapacity
            elseif from_region == to_region
                error("Cannot have an interface to and from " *
                      "the same region ($(from_region))")
            end
        end

        interfaces = Interfaces{N,P}(
            from_regions, to_regions, forwardcapacity, backwardcapacity)

        interface_lookup = Dict((r1, r2) => i for (i, (r1, r2))
                                in enumerate(tuple.(from_regions, to_regions)))

        lines_core = read(f["lines/_core"])
        line_names, line_categories, line_fromregionnames, line_toregionnames =
            readvector.(Ref(lines_core), [:name, :category, :region_from, :region_to])
        line_forwardcapacity = Int.(read(f["lines/forwardcapacity"]))
        line_backwardcapacity = Int.(read(f["lines/backwardcapacity"]))

        n_lines = length(line_names)
        line_fromregions = getindex.(Ref(regionlookup), line_fromregionnames)
        line_toregions  = getindex.(Ref(regionlookup), line_toregionnames)

        # Force line definitions as smaller => larger region numbers
        for i in 1:n_lines
            from_region = line_fromregions[i]
            to_region = line_toregions[i]
            if from_region > to_region
                line_fromregions[i] = to_region
                line_toregions[i] = from_region
                new_forwardcapacity = line_backwardcapacity[i, :]
                line_backwardcapacity[i, :] .= line_forwardcapacity[i, :]
                line_forwardcapacity[i, :] = new_forwardcapacity
            elseif from_region == to_region
                error("Cannot have a line ($(line_names[i])) to and from " *
                      "the same region ($(from_region))")
            end
        end

        line_interfaces = getindex.(Ref(interface_lookup),
                                    tuple.(line_fromregions, line_toregions))
        interface_order = sortperm(line_interfaces)

        lines = Lines{N,L,T,P}(
            line_names[interface_order], line_categories[interface_order],
            line_forwardcapacity[interface_order, :],
            line_backwardcapacity[interface_order, :],
            load_matrix(f["lines/failureprobability"], interface_order, Float64),
            load_matrix(f["lines/repairprobability"], interface_order, Float64)
        )

        interface_line_idxs = makeidxlist(line_interfaces[interface_order], n_interfaces)

    else

        interfaces = Interfaces{N,P}()

        lines = Lines{N,L,T,P}()

        interface_line_idxs = UnitRange{Int}[]

    end

    return (regions, interfaces,
            generators, region_gen_idxs,
            storages, region_stor_idxs,
            generatorstorages, region_genstor_idxs,
            lines, interface_line_idxs,
            timestamps),type_params
end

"""
Read a SystemModel from a PRAS file in version 0.5.x - 0.7.x format.
"""
function systemmodel_0_5(f::File)

    systemmodel_0_5_objs, _ = _systemmodel_core(f)

    return SystemModel(systemmodel_0_5_objs...)

end

"""
Read a SystemModel from a PRAS file in version 0.8.x format.
"""
function systemmodel_0_8(f::File)
    
    (regions, interfaces,
    generators, region_gen_idxs,
    storages, region_stor_idxs,
    generatorstorages, region_genstor_idxs,
    lines, interface_line_idxs,
    timestamps), (N,L,T,P,E) = _systemmodel_core(f)

    n_regions = length(regions)
    regionlookup = Dict(n=>i for (i, n) in enumerate(regions.names))

    if haskey(f, "demandresponses")


        dr_core = read(f["demandresponses/_core"])
        dr_names, dr_categories, dr_regionnames = readvector.(
            Ref(dr_core), [:name, :category, :region])

        dr_regions = getindex.(Ref(regionlookup), dr_regionnames)
        region_order = sortperm(dr_regions)

        demandresponses = DemandResponses{N,L,T,P,E}(
            dr_names[region_order], dr_categories[region_order],
            load_matrix(f["demandresponses/borrowcapacity"], region_order, Int),
            load_matrix(f["demandresponses/paybackcapacity"], region_order, Int),
            load_matrix(f["demandresponses/energycapacity"], region_order, Int),
            load_matrix(f["demandresponses/borrowedenergyinterest"], region_order, Float64),
            load_matrix(f["demandresponses/allowablepaybackperiod"], region_order, Int),
            load_matrix(f["demandresponses/failureprobability"], region_order, Float64),
            load_matrix(f["demandresponses/repairprobability"], region_order, Float64),
            load_matrix(f["demandresponses/borrowefficiency"], region_order, Float64),
            load_matrix(f["demandresponses/paybackefficiency"], region_order, Float64),
        )

        region_dr_idxs = makeidxlist(dr_regions[region_order], n_regions)

    else
        demandresponses = DemandResponses{N,L,T,P,E}()

        region_dr_idxs = fill(1:0, n_regions)

    end

    attrs = read_attrs(f)

    return SystemModel(
        regions, interfaces,
        generators, region_gen_idxs,
        storages, region_stor_idxs,
        generatorstorages, region_genstor_idxs,
        demandresponses, region_dr_idxs,
        lines, interface_line_idxs,
        timestamps, attrs)
    
end

"""
Attempts to parse the file's "vX.Y.Z" version label into (x::Int, y::Int, z::Int).
Errors if the label cannot be found or parsed as expected.
"""
function readversion(f::File)

    haskey(attributes(f), "pras_dataversion") || error(
          "File format version indicator could not be found - the file may " *
          "not be a PRAS SystemModel representation.")

    versionstring = read(attributes(f)["pras_dataversion"])

    version = match(r"^v(\d+)\.(\d+)\.(\d+)$", versionstring)
    isnothing(version) && error("File format version $versionstring not recognized")

    major, minor, patch = parse.(Int, version.captures)

    return (major, minor, patch), versionstring

end

"""
Reads user defined metadata from the file containing the PRAS system.
"""
function read_attrs(inputfile::String)

    h5open(inputfile, "r") do f::File
        sys_attributes = read_attrs(f)

        if isempty(sys_attributes)
            println("No system attributes found in the file.")
            return Dict{String, String}()
        else    
            println("System attribute(s) found in the file:")
            for key in keys(sys_attributes)
                println("  $key: $(sys_attributes[key])")
            end
            return sys_attributes
        end
    end
end

"""
Reads additional user defined metadata from the file containing the PRAS system,
Input here is filehandle.
"""
function read_attrs(f::File)

    metadata = attributes(f)

    reqd_attrs_keys = ["pras_dataversion", "start_timestamp", "timestep_count",
                "timestep_length", "timestep_unit", "power_unit", "energy_unit"]
    
    addl_attrs_keys = setdiff(keys(metadata), reqd_attrs_keys)
    
    return Dict{String,String}(key => read(metadata[key]) for key in addl_attrs_keys)

end

"""
Attempts to extract a vector of elements from an HDF5 compound datatype,
corresponding to `field`.
"""
readvector(d::Dataset, field::Union{Symbol,Int}) = readvector(read(d), field)
readvector(d::Vector{<:NamedTuple}, field::Union{Symbol,Int}) = getindex.(d, field)
