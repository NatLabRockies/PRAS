"""
    SystemModel{N, L, T<:Period, P<:PowerUnit, E<:EnergyUnit}

A SystemModel struct contains a representation of a power system to be studied
with PRAS. See [system specifications](@ref system_specification) for more 
details on components of a system model.

# Type Parameters
- `N`: Number of timesteps in the system model
- `L`: Length of each timestep in T units 
- `T`: Time period type (e.g., `Hour`, `Minute`)
- `P`: Power unit type (e.g., `MW`, `GW`)
- `E`: Energy unit type (e.g., `MWh`, `GWh`)

# Fields
- `regions`: Representation of system regions (Type - [Regions](@ref))
- `interfaces`: Information about connections between regions (Type - [Interfaces](@ref))
- `generators`: Collection of system generators (Type - [Generators](@ref))
- `region_gen_idxs`: Mapping of generators to their respective regions
- `storages`: Collection of system storages (Type - [Storages](@ref))
- `region_stor_idxs`: Mapping of storage resources to their respective regions
- `generatorstorages`: Collection of system generation-storages (Type - [GeneratorStorages](@ref))
- `region_genstor_idxs`: Mapping of hybrid resources to their respective regions
- `lines`: Collection of transmission lines connecting regions (Type - [Lines](@ref))
- `interface_line_idxs`: Mapping of transmission lines to interfaces
- `timestamps`: Time range for the simulation period
- `attrs`: Dictionary of system metadata and attributes

# Constructors
    SystemModel(regions, interfaces, generators, region_gen_idxs, storages, region_stor_idxs,
                generatorstorages, region_genstor_idxs, lines, interface_line_idxs,
                timestamps, [attrs])

Create a system model with all components specified.

    SystemModel(generators, storages, generatorstorages, timestamps, load, [attrs])

Create a single-node system model with specified generators, storage, and load profile.

    SystemModel(regions, interfaces, generators, region_gen_idxs, storages, region_stor_idxs,
                generatorstorages, region_genstor_idxs, lines, interface_line_idxs,
                timestamps::StepRange{DateTime}, [attrs])

Create a system model with `DateTime` timestamps (will be converted to UTC time zone).
"""
struct SystemModel{N, L, T <: Period, P <: PowerUnit, E <: EnergyUnit}
    regions::Regions{N, P}
    interfaces::Interfaces{N, P}

    generators::Generators{N,L,T,P}
    region_gen_idxs::Vector{UnitRange{Int}}

    storages::Storages{N,L,T,P,E}
    region_stor_idxs::Vector{UnitRange{Int}}

    generatorstorages::GeneratorStorages{N,L,T,P,E}
    region_genstor_idxs::Vector{UnitRange{Int}}

    demandresponses::DemandResponses{N,L,T,P,E}
    region_dr_idxs::Vector{UnitRange{Int}}

    lines::Lines{N,L,T,P}
    interface_line_idxs::Vector{UnitRange{Int}}

    timestamps::StepRange{ZonedDateTime,T}

    attrs::Dict{String, String}

    #base system constructor-demand response devices
    function SystemModel{}(
        regions::Regions{N,P}, interfaces::Interfaces{N,P},
        generators::Generators{N,L,T,P}, region_gen_idxs::Vector{UnitRange{Int}},
        storages::Storages{N,L,T,P,E}, region_stor_idxs::Vector{UnitRange{Int}},
        generatorstorages::GeneratorStorages{N,L,T,P,E},
        region_genstor_idxs::Vector{UnitRange{Int}},
        demandresponses::DemandResponses{N,L,T,P,E}, region_dr_idxs::Vector{UnitRange{Int}},
        lines::Lines{N,L,T,P}, interface_line_idxs::Vector{UnitRange{Int}},
        timestamps::StepRange{ZonedDateTime,T},
        attrs::Dict{String, String}=Dict{String, String}()
    ) where {N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit}

        n_regions = length(regions)
        n_gens = length(generators)
        n_stors = length(storages)
        n_genstors = length(generatorstorages)
        n_drs = length(demandresponses)

        n_interfaces = length(interfaces)
        n_lines = length(lines)

        @assert consistent_idxs(region_gen_idxs, n_gens, n_regions)
        @assert consistent_idxs(region_stor_idxs, n_stors, n_regions)
        @assert consistent_idxs(region_genstor_idxs, n_genstors, n_regions)
        @assert consistent_idxs(region_dr_idxs, n_drs, n_regions)
        @assert consistent_idxs(interface_line_idxs, n_lines, n_interfaces)

        @assert all(
            1 <= interfaces.regions_from[i] < interfaces.regions_to[i] <= n_regions
            for i in 1:n_interfaces)

        @assert step(timestamps) == T(L)
        @assert length(timestamps) == N

        new{N,L,T,P,E}(
            regions, interfaces,
            generators, region_gen_idxs, storages, region_stor_idxs,
            generatorstorages, region_genstor_idxs, 
            demandresponses, region_dr_idxs,
            lines, interface_line_idxs,
            timestamps, attrs)

    end

end

#base system constructor- no demand response devices
function SystemModel{}(
    regions::Regions{N,P}, interfaces::Interfaces{N,P},
    generators::Generators{N,L,T,P}, region_gen_idxs::Vector{UnitRange{Int}},
    storages::Storages{N,L,T,P,E}, region_stor_idxs::Vector{UnitRange{Int}},
    generatorstorages::GeneratorStorages{N,L,T,P,E},
    region_genstor_idxs::Vector{UnitRange{Int}},
    lines::Lines{N,L,T,P}, interface_line_idxs::Vector{UnitRange{Int}},
    timestamps::StepRange{ZonedDateTime,T},
    attrs::Dict{String, String}=Dict{String, String}()
) where {N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit}

    return SystemModel(
        regions, interfaces,
        generators, region_gen_idxs,
        storages, region_stor_idxs,
        generatorstorages, region_genstor_idxs,
        DemandResponses{N,L,T,P,E}(), repeat([1:0],length(regions)),
        lines, interface_line_idxs,
        timestamps, attrs)
end
    
# No time zone constructor - demand responses included
function SystemModel(
    regions::Regions{N,P}, interfaces::Interfaces{N,P},
    generators::Generators{N,L,T,P}, region_gen_idxs::Vector{UnitRange{Int}},
    storages::Storages{N,L,T,P,E}, region_stor_idxs::Vector{UnitRange{Int}},
    generatorstorages::GeneratorStorages{N,L,T,P,E}, region_genstor_idxs::Vector{UnitRange{Int}},
    demandresponses::DemandResponses{N,L,T,P,E}, region_dr_idxs::Vector{UnitRange{Int}},
    lines, interface_line_idxs::Vector{UnitRange{Int}},
    timestamps::StepRange{DateTime,T},
    attrs::Dict{String, String}=Dict{String, String}()
) where {N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit}

    @warn "No time zone data provided - defaulting to UTC. To specify a " *
          "time zone for the system timestamps, provide a range of " *
          "`ZonedDateTime` instead of `DateTime`."

    utc = tz"UTC"
    time_start = ZonedDateTime(first(timestamps), utc)
    time_end = ZonedDateTime(last(timestamps), utc)
    timestamps_tz = time_start:step(timestamps):time_end

    return SystemModel(
        regions, interfaces,
        generators, region_gen_idxs,
        storages, region_stor_idxs,
        generatorstorages, region_genstor_idxs,
        demandresponses, region_dr_idxs,
        lines, interface_line_idxs,
        timestamps_tz,attrs)

end

# No time zone constructor - demand responses not included
function SystemModel(
    regions::Regions{N,P}, interfaces::Interfaces{N,P},
    generators::Generators{N,L,T,P}, region_gen_idxs::Vector{UnitRange{Int}},
    storages::Storages{N,L,T,P,E}, region_stor_idxs::Vector{UnitRange{Int}},
    generatorstorages::GeneratorStorages{N,L,T,P,E}, region_genstor_idxs::Vector{UnitRange{Int}},
    lines, interface_line_idxs::Vector{UnitRange{Int}},
    timestamps::StepRange{DateTime,T},
    attrs::Dict{String, String}=Dict{String, String}()
) where {N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit}

    return SystemModel(
        regions, interfaces,
        generators, region_gen_idxs,
        storages, region_stor_idxs,
        generatorstorages, region_genstor_idxs,
        DemandResponses{N,L,T,P,E}(), repeat([1:0],length(regions)),
        lines, interface_line_idxs,
        timestamps,attrs)

end

# Single-node constructor - demand responses included
function SystemModel(
    generators::Generators{N,L,T,P},
    storages::Storages{N,L,T,P,E},
    generatorstorages::GeneratorStorages{N,L,T,P,E},
    demandresponses::DemandResponses{N,L,T,P,E},
    timestamps::StepRange{<:AbstractDateTime,T},
    load::Vector{Int},
    attrs::Dict{String, String}=Dict{String, String}()
) where {N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit}

    return SystemModel(
        Regions{N,P}(load),
        Interfaces{N,P}(),
        generators, [1:length(generators)],
        storages, [1:length(storages)],
        generatorstorages, [1:length(generatorstorages)],
        demandresponses, [1:length(demandresponses)],
        Lines{N,L,T,P}(),
        UnitRange{Int}[], timestamps, attrs)

end

# Single-node constructor - demand responses not included
function SystemModel(
    generators::Generators{N,L,T,P},
    storages::Storages{N,L,T,P,E},
    generatorstorages::GeneratorStorages{N,L,T,P,E},
    timestamps::StepRange{<:AbstractDateTime,T},
    load::Vector{Int},
    attrs::Dict{String, String}=Dict{String, String}()
) where {N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit}
    return SystemModel(
        Regions{N,P}(load),
        Interfaces{N,P}(),
        generators, [1:length(generators)],
        storages, [1:length(storages)],
        generatorstorages, [1:length(generatorstorages)],
        DemandResponses{N,L,T,P,E}(), [1:0],
        Lines{N,L,T,P}(),
        UnitRange{Int}[], timestamps, attrs)
end


Base.:(==)(x::T, y::T) where {T <: SystemModel} =
    x.regions == y.regions &&
    x.interfaces == y.interfaces &&
    x.generators == y.generators &&
    x.region_gen_idxs == y.region_gen_idxs &&
    x.storages == y.storages &&
    x.region_stor_idxs == y.region_stor_idxs &&
    x.generatorstorages == y.generatorstorages &&
    x.region_genstor_idxs == y.region_genstor_idxs &&
    x.demandresponses == y.demandresponses &&
    x.region_dr_idxs == y.region_dr_idxs &&
    x.lines == y.lines &&
    x.interface_line_idxs == y.interface_line_idxs &&
    x.timestamps == y.timestamps &&
    x.attrs == y.attrs

broadcastable(x::SystemModel) = Ref(x)

unitsymbol(::SystemModel{N,L,T,P,E}) where {
    N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit} =
    unitsymbol(T), unitsymbol(P), unitsymbol(E)

isnonnegative(x::Real) = x >= 0
ispositive(x::Real) = x > 0
isfractional(x::Real) = 0 <= x <= 1

get_params(::SystemModel{N,L,T,P,E}) where {N,L,T,P,E} = 
    (N,L,T,P,E)

function consistent_idxs(idxss::Vector{UnitRange{Int}}, nitems::Int, ngroups::Int)

    length(idxss) == ngroups || return false

    expected_next = 1
    for idxs in idxss
        first(idxs) == expected_next || return false
        expected_next = last(idxs) + 1
    end

    expected_next == nitems + 1 || return false
    return true

end

function Base.show(io::IO, sys::SystemModel{N,L,T,P,E}) where {N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit}
    time_unit = unitsymbol_long(T)
    print(io, "SystemModel($(length(sys.regions)) regions, $(length(sys.interfaces)) interfaces, ",
          "$(length(sys.generators)) generators, $(length(sys.storages)) storages, ",
          "$(length(sys.generatorstorages)) generator-storages,",
          "$(length(sys.demandresponses)) demand-responses,",
          " $(N) $(time_unit)s)")
end

function Base.show(io::IO, ::MIME"text/plain", sys::SystemModel{N,L,T,P,E}) where {N,L,T,P,E}
    time_unit = unitsymbol_long(T)
    println(io, "PRAS system with $(length(sys.regions)) regions, and $(length(sys.interfaces)) interfaces between these regions.")
    println(io, "Region names: $(join(sys.regions.names, ", "))")
    println(io, "\nAssets: ")
    println(io, "  Generators: $(length(sys.generators)) units")
    println(io, "  Storages: $(length(sys.storages)) units")
    println(io, "  GeneratorStorages: $(length(sys.generatorstorages)) units")
    println(io, "  DemandResponses: $(length(sys.demandresponses)) units")
    println(io, "  Lines: $(length(sys.lines))")
    println(io, "\nTime series:")
    println(io, "  Start time: $(first(sys.timestamps))")
    println(io, "  Resolution: $L $time_unit")
    println(io, "  Number of time steps: $(N)")
    println(io, "  End time: $(last(sys.timestamps))")
    println(io, "  Time zone: $(TimeZone(first(sys.timestamps)))")
    
    # Format attributes as key-value pairs
    sys_attributes = sys.attrs
    if !isempty(sys_attributes)
        println(io, "\nAttributes:")
        for (key, value) in sys_attributes
            println(io, "  $key: $value")
        end
    end
end

struct RegionInfo
    name::String
    index::Int
    generators::NamedTuple
    storages::NamedTuple
    generatorstorages::NamedTuple
    demandresponses::NamedTuple
    peak_load::Int
    power_unit::String
end

"""
Access region information from a SystemModel by region index (Int)
"""
function Base.getindex(sys::SystemModel, region_idx::Int)

    if region_idx > length(sys.regions)
        throw(BoundsError(sys.regions, region_idx))
    end
    
    region_name = sys.regions.names[region_idx]
    _, power_unit, _ = unitsymbol(sys)
    
    # Get unit ranges
    gen_range = sys.region_gen_idxs[region_idx]
    stor_range = sys.region_stor_idxs[region_idx]
    genstor_range = sys.region_genstor_idxs[region_idx]
    dr_range = sys.region_dr_idxs[region_idx]

    # Get peak load for this region
    peak_load = maximum(sys.regions.load[region_idx, :])
    
    # Return a RegionInfo object with all the information
    return RegionInfo(
        region_name,
        region_idx,
        (
            indices = gen_range,
            count = length(gen_range),
        ),
        (
            indices = stor_range,
            count = length(stor_range),
        ),
        (
            indices = genstor_range,
            count = length(genstor_range),
        ),
        (
            indices = dr_range,
            count = length(dr_range),
        ),
        peak_load,
        power_unit,
    )
end

"""
Access region information from a SystemModel by region name (String)
"""
function Base.getindex(sys::SystemModel, region::String)
    region_idx = findfirst(==(region), sys.regions.names)
    
    if region_idx === nothing
        throw(KeyError("Region '$(region)' does not exist in the system"))
    end

    return sys[region_idx]
end

function Base.show(io::IO, info::RegionInfo)
    println(io, "Region: $(info.name) (index - $(info.index))")
    println(io, "  Peak load: $(info.peak_load) $(info.power_unit)")
    println(io, "  Generators: $(info.generators.count) units [indices - $(info.generators.indices)]")
    println(io, "  Storages: $(info.storages.count) units [indices - $(info.storages.indices)]")
    println(io, "  GeneratorStorages: $(info.generatorstorages.count) units [indices - $(info.generatorstorages.indices)]")
    println(io, "  DemandResponses: $(info.demandresponses.count) units [indices - $(info.demandresponses.indices)]")
end

"""
Access device information from a SystemModel by asset type and region index
"""
function Base.getindex(sys::SystemModel, region_idx::Int, assetType::Type{T}) where {T}

    if region_idx > length(sys.regions)
            throw(BoundsError(sys.regions, region_idx))
    end
        
    # Dispatch based on asset type
    return _get_asset_by_type(sys, region_idx, assetType)
end

"""
Access device information from a SystemModel by asset type and region name (String)
"""
function Base.getindex(sys::SystemModel, region::String, assetType::Type{T}) where {T}
    region_idx = findfirst(==(region), sys.regions.names)
    
    if region_idx === nothing
        throw(KeyError("Region '$(region)' does not exist in the system"))
    end

    return sys[region_idx, assetType]
end

# Handle different asset types
function _get_asset_by_type(sys::SystemModel, region_idx::Int, ::Type{Generators})
    gen_range = sys.region_gen_idxs[region_idx]
    return sys.generators[gen_range]
end

function _get_asset_by_type(sys::SystemModel, region_idx::Int, ::Type{Storages})
    stor_range = sys.region_stor_idxs[region_idx]
    return sys.storages[stor_range]
end

function _get_asset_by_type(sys::SystemModel, region_idx::Int, ::Type{GeneratorStorages})
    genstor_range = sys.region_genstor_idxs[region_idx]
    return sys.generatorstorages[genstor_range]
end

function _get_asset_by_type(sys::SystemModel, region_idx::Int, ::Type{DemandResponses})
    dr_range = sys.region_dr_idxs[region_idx]
    return sys.demandresponses[dr_range]
end

# Fallback for unsupported types
function _get_asset_by_type(sys::SystemModel, region_idx::Int, ::Type{T}) where {T}
    error("Asset type $T is not supported. Supported types are: Generators, Storages, GeneratorStorages, DemandResponses")
end
