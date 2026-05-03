"""
    Regions{N,P<:PowerUnit}

A struct representing regions within a power system.

# Type Parameters
- `N`: Number of timesteps in the system model
- `P`: The power unit used for demand measurements, subtype of `PowerUnit`

# Fields
 - `names`: Name of region (unique)
 - `load`: Aggregated electricity demand in each region for each timeperiod, in
   `power_units` (`P`)
"""
struct Regions{N,P<:PowerUnit}

    names::Vector{String}
    load::Matrix{Int}

    function Regions{N,P}(
        names::Vector{<:AbstractString}, load::Matrix{Int}
    ) where {N,P<:PowerUnit}

        n_regions = length(names)

        @assert size(load) == (n_regions, N)
        @assert all(isnonnegative, load)

        new{N,P}(string.(names), load)

    end

end

# Single Regions constructor
function Regions{N,P}(load::Vector{Int}) where {N,P}
    return Regions{N,P}(["Region"], reshape(load, 1, :))
end

Base.:(==)(x::T, y::T) where {T <: Regions} =
    x.names == y.names &&
    x.load == y.load

Base.length(r::Regions) = length(r.names)

"""
    Interfaces{N,P<:PowerUnit}

A struct representing transmission interfaces between regions in a power system.

# Type Parameters
- `N`: Number of timesteps in the system model
- `P`: The power unit used for interface limits, subtype of `PowerUnit`

# Fields
 - `regions_from`: Index of the first region connected by the interface
 - `regions_to`: Index of the second region connected by the interface
 - `limit_forward`: Maximum possible total power transfer from `regions_from` to
   `regions_to`, for each interface in each timeperiod, in `power_units` (`P`)
 - `limit_backward`: Maximum possible total power transfer from `regions_to` to
   `regions_from`, for each interface in each timeperiod, in `power_units` (`P`)
"""
struct Interfaces{N,P<:PowerUnit}

    regions_from::Vector{Int}
    regions_to::Vector{Int}
    limit_forward::Matrix{Int}
    limit_backward::Matrix{Int}

    function Interfaces{N,P}(
        regions_from::Vector{Int}, regions_to::Vector{Int},
        forwardcapacity::Matrix{Int}, backwardcapacity::Matrix{Int}
    ) where {N,P<:PowerUnit}

        n_interfaces = length(regions_from)
        @assert length(regions_to) == n_interfaces

        @assert size(forwardcapacity) == (n_interfaces, N)
        @assert size(backwardcapacity) == (n_interfaces, N)
        @assert all(isnonnegative, forwardcapacity)
        @assert all(isnonnegative, backwardcapacity)

        new{N,P}(regions_from, regions_to, forwardcapacity, backwardcapacity)

    end

end

# Empty Interfaces constructor
function Interfaces{N,P}() where {N,P}
    return Interfaces{N,P}(
                Int[], Int[], zeros(Int, 0, N), zeros(Int, 0, N))
end

Base.:(==)(x::T, y::T) where {T <: Interfaces} =
    x.regions_from == y.regions_from &&
    x.regions_to == y.regions_to &&
    x.limit_forward == y.limit_forward &&
    x.limit_backward == y.limit_backward

Base.length(i::Interfaces) = length(i.regions_from)
