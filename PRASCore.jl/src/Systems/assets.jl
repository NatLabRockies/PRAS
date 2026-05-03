abstract type AbstractAssets{N,L,T<:Period,P<:PowerUnit} end
Base.length(a::AbstractAssets) = length(a.names)

function Base.getindex(a::AbstractAssets, reqd_names::AbstractVector{String})
    !allunique(reqd_names) && error("Names must be unique.")
    idxs = findall(a.names .∈ Ref(reqd_names))
    length(idxs) != length(reqd_names) && error("One or more names not found.")
    return a[idxs]
end

function Base.getindex(a::AbstractAssets, name::String)
    idx = findall(==(name), a.names)
    isempty(idx) && error("'$name' not found.")
    return a[idx]
end

function Base.show(io::IO, a::AbstractAssets)

    # Count occurrences of each category
    category_counts = Dict{String, Int}()
    for category in a.categories
        category_counts[category] = get(category_counts, category, 0) + 1
    end
    
    # Format category counts as strings in a table
    category_strings = [@sprintf("%-10s | %-10s",category,count) for (category, count) in category_counts]
    column_names = @sprintf("  %-10s | %-5s", "Category", "Count")
    header_separator = @sprintf("  %-10s%3s%-5s","-"^10,"-"^5,"-"^5)
    
    asset_type = typeof(a)

    # Printing logic
    println(io, "$(length(a.names)) $(asset_type.name.wrapper):")
    println(io, column_names)
    println(io, header_separator)
    println(io, "  $(join(category_strings, "\n  "))")
    
end

"""
    Generators{N,L,T<:Period,P<:PowerUnit}

A struct representing generating assets within a power system.

# Type Parameters
- `N`: Number of timesteps in the system model
- `L`: Length of each timestep in T units 
- `T`: The time period type used for temporal representation, subtype of `Period`
- `P`: The power unit used for capacity measurements, subtype of `PowerUnit`

# Fields
 - `names`: Name of generator
 - `categories`: Category of generator
 - `capacity`: Maximum available generation capacity in each timeperiod, expressed 
   in units given by the `power_units` (`P`) type parameter
 - `λ` (failure probability): probability the generator transitions from 
   operational to forced outage during a given simulation timestep (unitless)
 - `μ` (repair probability): probability the generator transitions from forced 
   outage to operational during a given simulation timestep (unitless)
"""
struct Generators{N,L,T<:Period,P<:PowerUnit} <: AbstractAssets{N,L,T,P}

    names::Vector{String}
    categories::Vector{String}

    capacity::Matrix{Int} # power

    λ::Matrix{Float64}
    μ::Matrix{Float64}

    function Generators{N,L,T,P}(
        names::Vector{<:AbstractString}, categories::Vector{<:AbstractString},
        capacity::Matrix{Int}, λ::Matrix{Float64}, μ::Matrix{Float64}
    ) where {N,L,T,P}

        n_gens = length(names)
        @assert length(categories) == n_gens
        @assert allunique(names)

        @assert size(capacity) == (n_gens, N)
        @assert all(isnonnegative, capacity) # Why not just use unsigned integers?

        @assert size(λ) == (n_gens, N)
        @assert size(μ) == (n_gens, N)
        @assert all(isfractional, λ)
        @assert all(isfractional, μ)

        new{N,L,T,P}(string.(names), string.(categories), capacity, λ, μ)

    end

end

# Empty Generators constructor
function Generators{N,L,T,P}() where {N,L,T,P}

    return Generators{N,L,T,P}(
            String[], String[], zeros(Int, 0, N),
            zeros(Float64, 0, N), zeros(Float64, 0, N))
    
end

Base.:(==)(x::T, y::T) where {T <: Generators} =
    x.names == y.names &&
    x.categories == y.categories &&
    x.capacity == y.capacity &&
    x.λ == y.λ &&
    x.μ == y.μ

Base.getindex(g::G, idxs::AbstractVector{Int}) where {G <: Generators} =
    G(g.names[idxs], g.categories[idxs],
      g.capacity[idxs, :], g.λ[idxs, :], g.μ[idxs, :])

function Base.vcat(gs::Generators{N,L,T,P}...) where {N, L, T, P}

    n_gens = sum(length(g) for g in gs)

    names = Vector{String}(undef, n_gens)
    categories = Vector{String}(undef, n_gens)

    capacity = Matrix{Int}(undef, n_gens, N)

    λ = Matrix{Float64}(undef, n_gens, N)
    μ = Matrix{Float64}(undef, n_gens, N)

    last_idx = 0

    for g in gs

        n = length(g)
        rows = last_idx .+ (1:n)

        names[rows] = g.names
        categories[rows] = g.categories
        capacity[rows, :] = g.capacity
        λ[rows, :] = g.λ
        μ[rows, :] = g.μ

        last_idx += n

    end

    return Generators{N,L,T,P}(names, categories, capacity, λ, μ)

end

"""
    Storages{N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit}

A struct representing storage devices in the system.

# Type Parameters
- `N`: Number of timesteps in the system model
- `L`: Length of each timestep in T units
- `T`: The time period type used for temporal representation, subtype of `Period`
- `P`: The power unit used for capacity measurements, subtype of `PowerUnit`
- `E`: The energy unit used for energy storage, subtype of `EnergyUnit`

# Fields
 - `names`: Name of storage device
 - `categories`: Category of storage device
 - `charge_capacity`: Maximum available charging capacity for each storage unit in each
   timeperiod, expressed in units given by the `power_units` (`P`) type parameter
 - `discharge_capacity`: Maximum available discharging capacity for each storage unit in
   each timeperiod, expressed in units given by the `power_units` (`P`) type parameter
 - `energy_capacity`: Maximum available energy storage capacity for each storage unit in
   each timeperiod, expressed in units given by the `energy_units` (`E`) type parameter
 - `charge_efficiency`: Ratio of power injected into the storage device's reservoir to
   power withdrawn from the grid, for each storage unit in each timeperiod. Unitless.
 - `discharge_efficiency`: Ratio of power injected into the grid to power withdrawn from
   the storage device's reservoir, for each storage unit in each timeperiod. Unitless.
 - `carryover_efficiency`: Ratio of energy available in the storage device's reservoir at
   the beginning of one period to energy retained at the end of the previous period, for
   each storage unit in each timeperiod. Unitless.
 - `λ` (failure probability): Probability the unit transitions from operational to forced
   outage during a given simulation timestep, for each storage unit in each timeperiod.
   Unitless.
 - `μ` (repair probability): Probability the unit transitions from forced outage to
   operational during a given simulation timestep, for each storage unit in each
   timeperiod. Unitless.
"""
struct Storages{N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit} <: AbstractAssets{N,L,T,P}

    names::Vector{String}
    categories::Vector{String}

    charge_capacity::Matrix{Int} # power
    discharge_capacity::Matrix{Int} # power
    energy_capacity::Matrix{Int} # energy

    charge_efficiency::Matrix{Float64}
    discharge_efficiency::Matrix{Float64}
    carryover_efficiency::Matrix{Float64}

    λ::Matrix{Float64}
    μ::Matrix{Float64}

    function Storages{N,L,T,P,E}(
        names::Vector{<:AbstractString}, categories::Vector{<:AbstractString},
        chargecapacity::Matrix{Int}, dischargecapacity::Matrix{Int},
        energycapacity::Matrix{Int}, chargeefficiency::Matrix{Float64},
        dischargeefficiency::Matrix{Float64}, carryoverefficiency::Matrix{Float64},
        λ::Matrix{Float64}, μ::Matrix{Float64}
    ) where {N,L,T,P,E}

        n_stors = length(names)
        @assert length(categories) == n_stors
        @assert allunique(names)

        @assert size(chargecapacity) == (n_stors, N)
        @assert size(dischargecapacity) == (n_stors, N)
        @assert size(energycapacity) == (n_stors, N)
        @assert all(isnonnegative, chargecapacity)
        @assert all(isnonnegative, dischargecapacity)
        @assert all(isnonnegative, energycapacity)

        @assert size(chargeefficiency) == (n_stors, N)
        @assert size(dischargeefficiency) == (n_stors, N)
        @assert size(carryoverefficiency) == (n_stors, N)
        @assert all(isfractional, chargeefficiency)
        @assert all(isfractional, dischargeefficiency)
        @assert all(isfractional, carryoverefficiency)

        @assert size(λ) == (n_stors, N)
        @assert size(μ) == (n_stors, N)
        @assert all(isfractional, λ)
        @assert all(isfractional, μ)

        new{N,L,T,P,E}(string.(names), string.(categories),
                       chargecapacity, dischargecapacity, energycapacity,
                       chargeefficiency, dischargeefficiency, carryoverefficiency,
                       λ, μ)

    end

end

# Empty Storages constructor
function Storages{N,L,T,P,E}() where {N,L,T,P,E}

    return Storages{N,L,T,P,E}(
                String[], String[], 
                zeros(Int, 0, N), zeros(Int, 0, N), zeros(Int, 0, N),
                zeros(Float64, 0, N), zeros(Float64, 0, N), zeros(Float64, 0, N),
                zeros(Float64, 0, N), zeros(Float64, 0, N))
end

Base.:(==)(x::T, y::T) where {T <: Storages} =
    x.names == y.names &&
    x.categories == y.categories &&
    x.charge_capacity == y.charge_capacity &&
    x.discharge_capacity == y.discharge_capacity &&
    x.energy_capacity == y.energy_capacity &&
    x.charge_efficiency == y.charge_efficiency &&
    x.discharge_efficiency == y.discharge_efficiency &&
    x.carryover_efficiency == y.carryover_efficiency &&
    x.λ == y.λ &&
    x.μ == y.μ

Base.getindex(s::S, idxs::AbstractVector{Int}) where {S <: Storages} =
    S(s.names[idxs], s.categories[idxs],s.charge_capacity[idxs,:],
      s.discharge_capacity[idxs, :],s.energy_capacity[idxs, :],
      s.charge_efficiency[idxs, :], s.discharge_efficiency[idxs, :], 
      s.carryover_efficiency[idxs, :],s.λ[idxs, :], s.μ[idxs, :])

function Base.vcat(stors::Storages{N,L,T,P,E}...) where {N, L, T, P, E}

    n_stors = sum(length(s) for s in stors)

    names = Vector{String}(undef, n_stors)
    categories = Vector{String}(undef, n_stors)

    charge_capacity = Matrix{Int}(undef, n_stors, N)
    discharge_capacity = Matrix{Int}(undef, n_stors, N)
    energy_capacity = Matrix{Int}(undef, n_stors, N) 

    charge_efficiency = Matrix{Float64}(undef, n_stors, N)
    discharge_efficiency = Matrix{Float64}(undef, n_stors, N)
    carryover_efficiency = Matrix{Float64}(undef, n_stors, N)

    λ = Matrix{Float64}(undef, n_stors, N)
    μ = Matrix{Float64}(undef, n_stors, N)

    last_idx = 0

    for s in stors

        n = length(s)
        rows = last_idx .+ (1:n)

        names[rows] = s.names
        categories[rows] = s.categories

        charge_capacity[rows, :] = s.charge_capacity
        discharge_capacity[rows, :] = s.discharge_capacity
        energy_capacity[rows, :] = s.energy_capacity

        charge_efficiency[rows, :] = s.charge_efficiency
        discharge_efficiency[rows, :] = s.discharge_efficiency
        carryover_efficiency[rows, :] = s.carryover_efficiency

        λ[rows, :] = s.λ
        μ[rows, :] = s.μ

        last_idx += n

    end

    return Storages{N,L,T,P,E}(names, categories, charge_capacity, discharge_capacity, energy_capacity, charge_efficiency, discharge_efficiency, 
                               carryover_efficiency, λ, μ)

end

"""
    GeneratorStorages{N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit}

A struct representing generator-storage hybrid devices within a power system.

# Type Parameters
- `N`: Number of timesteps in the system model
- `L`: Length of each timestep in T units
- `T`: The time period type used for temporal representation, subtype of `Period`
- `P`: The power unit used for capacity measurements, subtype of `PowerUnit`
- `E`: The energy unit used for energy storage, subtype of `EnergyUnit`

# Fields
 - `names`: Name of generator-storage unit
 - `categories`: Category of generator-storage unit
 - `charge_capacity`: Maximum available charging capacity for each generator-storage
   unit in each timeperiod, in `power_units` (`P`)
 - `discharge_capacity`: Maximum available discharging capacity for each generator-storage
   unit in each timeperiod, in `power_units` (`P`)
 - `energy_capacity`: Maximum available energy storage capacity for each generator-storage
   unit in each timeperiod, in `energy_units` (`E`)
 - `charge_efficiency`: Ratio of power injected into the device's reservoir to power
   withdrawn from the grid, for each generator-storage unit in each timeperiod. Unitless.
 - `discharge_efficiency`: Ratio of power injected into the grid to power withdrawn from
   the device's reservoir, for each generator-storage unit in each timeperiod. Unitless.
 - `carryover_efficiency`: Ratio of energy available in the device's reservoir at the
   beginning of one period to energy retained at the end of the previous period, for each
   generator-storage unit in each timeperiod. Unitless.
 - `inflow`: Exogenous power inflow available to each generator-storage unit in each
   timeperiod, in `power_units` (`P`)
 - `gridwithdrawal_capacity`: Maximum available capacity to withdraw power from the grid
   for each generator-storage unit in each timeperiod, in `power_units` (`P`)
 - `gridinjection_capacity`: Maximum available capacity to inject power to the grid for
   each generator-storage unit in each timeperiod, in `power_units` (`P`)
 - `λ` (failure probability): Probability the unit transitions from operational to forced
   outage during a given simulation timestep, for each generator-storage unit in each
   timeperiod. Unitless.
 - `μ` (repair probability): Probability the unit transitions from forced outage to
   operational during a given simulation timestep, for each generator-storage unit in each
   timeperiod. Unitless.
"""
struct GeneratorStorages{N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit} <: AbstractAssets{N,L,T,P}

    names::Vector{String}
    categories::Vector{String}

    charge_capacity::Matrix{Int} # power
    discharge_capacity::Matrix{Int} # power
    energy_capacity::Matrix{Int} # energy

    charge_efficiency::Matrix{Float64}
    discharge_efficiency::Matrix{Float64}
    carryover_efficiency::Matrix{Float64}

    inflow::Matrix{Int} # power
    gridwithdrawal_capacity::Matrix{Int} # power
    gridinjection_capacity::Matrix{Int} # power

    λ::Matrix{Float64}
    μ::Matrix{Float64}

    function GeneratorStorages{N,L,T,P,E}(
        names::Vector{<:AbstractString}, categories::Vector{<:AbstractString},
        charge_capacity::Matrix{Int}, discharge_capacity::Matrix{Int},
        energy_capacity::Matrix{Int},
        charge_efficiency::Matrix{Float64}, discharge_efficiency::Matrix{Float64},
        carryover_efficiency::Matrix{Float64},
        inflow::Matrix{Int},
        gridwithdrawal_capacity::Matrix{Int}, gridinjection_capacity::Matrix{Int},
        λ::Matrix{Float64}, μ::Matrix{Float64}
    ) where {N,L,T,P,E}

        n_stors = length(names)
        @assert length(categories) == n_stors
        @assert allunique(names)

        @assert size(charge_capacity) == (n_stors, N)
        @assert size(discharge_capacity) == (n_stors, N)
        @assert size(energy_capacity) == (n_stors, N)

        @assert all(isnonnegative, charge_capacity)
        @assert all(isnonnegative, discharge_capacity)
        @assert all(isnonnegative, energy_capacity)

        @assert size(charge_efficiency) == (n_stors, N)
        @assert size(discharge_efficiency) == (n_stors, N)
        @assert size(carryover_efficiency) == (n_stors, N)

        @assert all(isfractional, charge_efficiency)
        @assert all(isfractional, discharge_efficiency)
        @assert all(isfractional, carryover_efficiency)

        @assert size(inflow) == (n_stors, N)
        @assert size(gridwithdrawal_capacity) == (n_stors, N)
        @assert size(gridinjection_capacity) == (n_stors, N)

        @assert all(isnonnegative, inflow)
        @assert all(isnonnegative, gridwithdrawal_capacity)
        @assert all(isnonnegative, gridinjection_capacity)

        @assert size(λ) == (n_stors, N)
        @assert size(μ) == (n_stors, N)
        @assert all(isfractional, λ)
        @assert all(isfractional, μ)

        new{N,L,T,P,E}(
            string.(names), string.(categories),
            charge_capacity, discharge_capacity, energy_capacity,
            charge_efficiency, discharge_efficiency, carryover_efficiency,
            inflow, gridwithdrawal_capacity, gridinjection_capacity,
            λ, μ)

    end

end

# Empty GeneratorStorages constructor
function GeneratorStorages{N,L,T,P,E}() where {N,L,T,P,E}

    return GeneratorStorages{N,L,T,P,E}(
                String[], String[], 
                zeros(Int, 0, N), zeros(Int, 0, N), zeros(Int, 0, N),
                zeros(Float64, 0, N), zeros(Float64, 0, N), zeros(Float64, 0, N),
                zeros(Int, 0, N), zeros(Int, 0, N), zeros(Int, 0, N),
                zeros(Float64, 0, N), zeros(Float64, 0, N))
    
end

Base.:(==)(x::T, y::T) where {T <: GeneratorStorages} =
    x.names == y.names &&
    x.categories == y.categories &&
    x.charge_capacity == y.charge_capacity &&
    x.discharge_capacity == y.discharge_capacity &&
    x.energy_capacity == y.energy_capacity &&
    x.charge_efficiency == y.charge_efficiency &&
    x.discharge_efficiency == y.discharge_efficiency &&
    x.carryover_efficiency == y.carryover_efficiency &&
    x.inflow == y.inflow &&
    x.gridwithdrawal_capacity == y.gridwithdrawal_capacity &&
    x.gridinjection_capacity == y.gridinjection_capacity &&
    x.λ == y.λ &&
    x.μ == y.μ

Base.getindex(g_s::G, idxs::AbstractVector{Int}) where {G <: GeneratorStorages} =
    G(g_s.names[idxs], g_s.categories[idxs], g_s.charge_capacity[idxs,:],
      g_s.discharge_capacity[idxs, :], g_s.energy_capacity[idxs, :],
      g_s.charge_efficiency[idxs, :], g_s.discharge_efficiency[idxs, :], 
      g_s.carryover_efficiency[idxs, :],g_s.inflow[idxs, :],
      g_s.gridwithdrawal_capacity[idxs, :],g_s.gridinjection_capacity[idxs, :],
      g_s.λ[idxs, :], g_s.μ[idxs, :])

function Base.vcat(gen_stors::GeneratorStorages{N,L,T,P,E}...) where {N, L, T, P, E}

    n_gen_stors = sum(length(g_s) for g_s in gen_stors)

    names = Vector{String}(undef, n_gen_stors)
    categories = Vector{String}(undef, n_gen_stors)

    charge_capacity = Matrix{Int}(undef, n_gen_stors, N)
    discharge_capacity = Matrix{Int}(undef, n_gen_stors, N)
    energy_capacity = Matrix{Int}(undef, n_gen_stors, N) 

    charge_efficiency = Matrix{Float64}(undef, n_gen_stors, N)
    discharge_efficiency = Matrix{Float64}(undef, n_gen_stors, N)
    carryover_efficiency = Matrix{Float64}(undef, n_gen_stors, N)

    inflow = Matrix{Int}(undef, n_gen_stors, N)
    gridwithdrawal_capacity = Matrix{Int}(undef, n_gen_stors, N)
    gridinjection_capacity = Matrix{Int}(undef, n_gen_stors, N)

    λ = Matrix{Float64}(undef, n_gen_stors, N)
    μ = Matrix{Float64}(undef, n_gen_stors, N)

    last_idx = 0

    for g_s in gen_stors

        n = length(g_s)
        rows = last_idx .+ (1:n)

        names[rows] = g_s.names
        categories[rows] = g_s.categories

        charge_capacity[rows, :] = g_s.charge_capacity
        discharge_capacity[rows, :] = g_s.discharge_capacity
        energy_capacity[rows, :] = g_s.energy_capacity

        charge_efficiency[rows, :] = g_s.charge_efficiency
        discharge_efficiency[rows, :] = g_s.discharge_efficiency
        carryover_efficiency[rows, :] = g_s.carryover_efficiency

        inflow[rows, :] = g_s.inflow
        gridwithdrawal_capacity[rows, :] = g_s.gridwithdrawal_capacity
        gridinjection_capacity[rows, :] = g_s.gridinjection_capacity

        λ[rows, :] = g_s.λ
        μ[rows, :] = g_s.μ

        last_idx += n

    end

    return GeneratorStorages{N,L,T,P,E}(names, categories, charge_capacity, discharge_capacity, energy_capacity, charge_efficiency, discharge_efficiency, 
                               carryover_efficiency,inflow, gridwithdrawal_capacity, gridinjection_capacity, λ, μ)

end

"""
    DemandResponses{N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit}

A struct representing demand response devices in the system.

# Type Parameters
- `N`: Number of timesteps in the system model
- `L`: Length of each timestep in T units
- `T`: The time period type used for temporal representation, subtype of `Period`
- `P`: The power unit used for capacity measurements, subtype of `PowerUnit`
- `E`: The energy unit used for energy storage, subtype of `EnergyUnit`

# Fields
 - `names`: Name of demand response device
 - `categories`: Category of demand response device
 - `borrow_capacity`: Maximum available borrowing capacity for each demand response unit in each
   timeperiod, expressed in units given by the `power_units` (`P`) type parameter
 - `payback_capacity`: Maximum available payback capacity for each demand response unit in
   each timeperiod, expressed in units given by the `power_units` (`P`) type parameter
 - `energy_capacity`: Maximum available energy capable of being held for each demand response unit in
   each timeperiod, expressed in units given by the `energy_units` (`E`) type parameter
 - `borrowed_energy_interest`: Growth or decay rate of borrowed energy in the demand response device
   from the beginning of one period to energy retained at the end of the previous period, for
   each demand response unit in each timeperiod. A `borrowed_energy_interest` of 0.0 has no growth or decay. Unitless.
 - `allowable_payback_period`: Maximum number of time steps a demand response device can hold borrowed load.
    Any energy still contained at the end of the period will be counted as unserved load for that hour.
    If borrowed load is paid back before the end of the `allowable_payback_period`, counter is reset upn further use. (`T`) type parameter
 - `λ` (failure probability): Probability the unit transitions from operational to forced
   outage during a given simulation timestep, for each storage unit in each timeperiod.
   Unitless.
 - `μ` (repair probability): Probability the unit transitions from forced outage to
   operational during a given simulation timestep, for each storage unit in each
   timeperiod. Unitless.
"""
struct DemandResponses{N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit} <: AbstractAssets{N,L,T,P}

    names::Vector{String}
    categories::Vector{String}

    borrow_capacity::Matrix{Int} # power
    payback_capacity::Matrix{Int} # power
    energy_capacity::Matrix{Int} # energy

    borrowed_energy_interest::Matrix{Float64}

    allowable_payback_period::Matrix{Int}

    λ::Matrix{Float64}
    μ::Matrix{Float64}

    borrow_efficiency::Matrix{Float64}
    payback_efficiency::Matrix{Float64}

    function DemandResponses{N,L,T,P,E}(
        names::Vector{<:AbstractString}, categories::Vector{<:AbstractString},
        borrowcapacity::Matrix{Int}, paybackcapacity::Matrix{Int},
        energycapacity::Matrix{Int}, borrowedenergyinterest::Matrix{Float64},
        allowablepaybackperiod::Matrix{Int},
        λ::Matrix{Float64}, μ::Matrix{Float64},
        borrowefficiency::Matrix{Float64},paybackefficiency::Matrix{Float64}
    ) where {N,L,T,P,E}

        n_drs = length(names)
        @assert length(categories) == n_drs
        @assert allunique(names)

        
        @assert size(borrowcapacity) == (n_drs, N)
        @assert size(paybackcapacity) == (n_drs, N)
        @assert size(energycapacity) == (n_drs, N)
        @assert all(isnonnegative, borrowcapacity)
        @assert all(isnonnegative, paybackcapacity)
        @assert all(isnonnegative, energycapacity)

        @assert size(borrowefficiency) == (n_drs, N)
        @assert size(paybackefficiency) == (n_drs, N)
        @assert size(borrowedenergyinterest) == (n_drs, N)
        @assert all(isfractional, borrowefficiency)
        @assert all(isfractional, paybackefficiency)
        @assert all(borrowedenergyinterest .<= 1.0)
        @assert all(borrowedenergyinterest .>= -1.0)

        @assert size(allowablepaybackperiod) == (n_drs, N)
        @assert all(ispositive, allowablepaybackperiod)


        @assert size(λ) == (n_drs, N)
        @assert size(μ) == (n_drs, N)
        @assert all(isfractional, λ)
        @assert all(isfractional, μ)

        new{N,L,T,P,E}(string.(names), string.(categories),
                       borrowcapacity, paybackcapacity, energycapacity,
                      borrowedenergyinterest,
                       allowablepaybackperiod,
                       λ, μ,borrowefficiency, paybackefficiency,)
    end
end

# second constructor if borrow and payback efficiencies are not provided
function DemandResponses{N,L,T,P,E}(
  names::Vector{<:AbstractString}, categories::Vector{<:AbstractString},
  borrowcapacity::Matrix{Int}, paybackcapacity::Matrix{Int},
  energycapacity::Matrix{Int}, borrowedenergyinterest::Matrix{Float64},
  allowablepaybackperiod::Matrix{Int},
  λ::Matrix{Float64}, μ::Matrix{Float64}
) where {N,L,T,P,E}
    return DemandResponses{N,L,T,P,E}(
        names, categories,
        borrowcapacity, paybackcapacity, energycapacity,
        borrowedenergyinterest, allowablepaybackperiod,
        λ, μ,
        ones(Float64, size(borrowcapacity)), ones(Float64, size(paybackcapacity))
    )
end


# Empty DemandResponses constructor
function DemandResponses{N,L,T,P,E}() where {N,L,T,P,E}

    return DemandResponses{N,L,T,P,E}(
                String[], String[],
                Matrix{Int}(undef, 0, N),Matrix{Int}(undef, 0, N),Matrix{Int}(undef, 0, N),
                Matrix{Float64}(undef, 0, N),
                Matrix{Int}(undef, 0, N),Matrix{Float64}(undef, 0, N),Matrix{Float64}(undef, 0, N),
                Matrix{Float64}(undef, 0, N),Matrix{Float64}(undef, 0, N))
end

Base.:(==)(x::T, y::T) where {T <: DemandResponses} =
    x.names == y.names &&
    x.categories == y.categories &&
    x.borrow_capacity == y.borrow_capacity &&
    x.payback_capacity == y.payback_capacity &&
    x.energy_capacity == y.energy_capacity &&
    x.borrow_efficiency == y.borrow_efficiency &&
    x.payback_efficiency == y.payback_efficiency &&
    x.borrowed_energy_interest == y.borrowed_energy_interest &&
    x.allowable_payback_period == y.allowable_payback_period &&
    x.λ == y.λ &&
    x.μ == y.μ

Base.getindex(dr::DR, idxs::AbstractVector{Int}) where {DR <: DemandResponses} =
    DR(dr.names[idxs], dr.categories[idxs],dr.borrow_capacity[idxs,:],
      dr.payback_capacity[idxs, :],dr.energy_capacity[idxs, :],
      dr.borrowed_energy_interest[idxs, :],dr.allowable_payback_period[idxs, :],dr.λ[idxs, :], dr.μ[idxs, :],
      dr.borrow_efficiency[idxs, :], dr.payback_efficiency[idxs, :])

function Base.vcat(drs::DemandResponses{N,L,T,P,E}...) where {N, L, T, P, E}

    n_drs = sum(length(dr) for dr in drs)

    names = Vector{String}(undef, n_drs)
    categories = Vector{String}(undef, n_drs)

    borrow_capacity = Matrix{Int}(undef, n_drs, N)
    payback_capacity = Matrix{Int}(undef, n_drs, N)
    energy_capacity = Matrix{Int}(undef, n_drs, N) 

    borrow_efficiency = Matrix{Float64}(undef, n_drs, N)
    payback_efficiency = Matrix{Float64}(undef, n_drs, N)
    borrowed_energy_interest = Matrix{Float64}(undef, n_drs, N)

    allowable_payback_period = Matrix{Int}(undef, n_drs, N)


    λ = Matrix{Float64}(undef, n_drs, N)
    μ = Matrix{Float64}(undef, n_drs, N)

    last_idx = 0

    for dr in drs

        n = length(dr)
        rows = last_idx .+ (1:n)

        names[rows] = dr.names
        categories[rows] = dr.categories

        borrow_capacity[rows, :] = dr.borrow_capacity
        payback_capacity[rows, :] = dr.payback_capacity
        energy_capacity[rows, :] = dr.energy_capacity

        borrow_efficiency[rows, :] = dr.borrow_efficiency
        payback_efficiency[rows, :] = dr.payback_efficiency
        borrowed_energy_interest[rows, :] = dr.borrowed_energy_interest

        allowable_payback_period[rows, :] = dr.allowable_payback_period

        λ[rows, :] = dr.λ
        μ[rows, :] = dr.μ

        last_idx += n

    end

    return DemandResponses{N,L,T,P,E}(names, categories, borrow_capacity, payback_capacity, energy_capacity,
    borrowed_energy_interest,allowable_payback_period, λ, μ, borrow_efficiency, payback_efficiency)

end

"""
    Lines{N,L,T<:Period,P<:PowerUnit}

A struct representing individual transmission lines between regions in a power
system.

# Type Parameters
- `N`: Number of timesteps in the system model
- `L`: Length of each timestep in T units
- `T`: The time period type used for temporal representation, subtype of `Period`
- `P`: The power unit used for capacity measurements, subtype of `PowerUnit`

# Fields
 - `names`: Name of line
 - `categories`: Category of line
 - `forward_capacity`: Maximum available power transfer capacity from `region_from` to
   `region_to` along the line, for each line in each timeperiod, in `power_units` (`P`)
 - `backward_capacity`: Maximum available power transfer capacity from `region_to` to
   `region_from` along the line, for each line in each timeperiod, in `power_units` (`P`)
 - `λ` (failure probability): Probability the line transitions from operational to forced
   outage during a given simulation timestep, for each line in each timeperiod. Unitless.
 - `μ` (repair probability): Probability the line transitions from forced outage to
   operational during a given simulation timestep, for each line in each timeperiod.
   Unitless.
"""
struct Lines{N,L,T<:Period,P<:PowerUnit} <: AbstractAssets{N,L,T,P}

    names::Vector{String}
    categories::Vector{String}

    forward_capacity::Matrix{Int} # power
    backward_capacity::Matrix{Int} # power

    λ::Matrix{Float64}
    μ::Matrix{Float64}

    function Lines{N,L,T,P}(
        names::Vector{<:AbstractString}, categories::Vector{<:AbstractString},
        forward_capacity::Matrix{Int}, backward_capacity::Matrix{Int},
        λ::Matrix{Float64}, μ::Matrix{Float64}
    ) where {N,L,T,P}

        n_lines = length(names)
        @assert length(categories) == n_lines
        @assert allunique(names)

        @assert size(forward_capacity) == (n_lines, N)
        @assert size(backward_capacity) == (n_lines, N)
        @assert all(isnonnegative, forward_capacity)
        @assert all(isnonnegative, backward_capacity)

        @assert size(λ) == (n_lines, N)
        @assert size(μ) == (n_lines, N)
        @assert all(isfractional, λ)
        @assert all(isfractional, μ)

        new{N,L,T,P}(string.(names), string.(categories), forward_capacity, backward_capacity, λ, μ)

    end

end

# Empty Lines constructor
function Lines{N,L,T,P}() where {N,L,T,P}
    return Lines{N,L,T,P}(
            String[], String[], zeros(Int, 0, N), zeros(Int, 0, N),
            zeros(Float64, 0, N), zeros(Float64, 0, N))
end

Base.:(==)(x::T, y::T) where {T <: Lines} =
    x.names == y.names &&
    x.categories == y.categories &&
    x.forward_capacity == y.forward_capacity &&
    x.backward_capacity == y.backward_capacity &&
    x.λ == y.λ &&
    x.μ == y.μ

Base.getindex(lines::L, idxs::AbstractVector{Int}) where {L <: Lines} =
    L(lines.names[idxs], lines.categories[idxs],lines.forward_capacity[idxs,:],
      lines.backward_capacity[idxs, :],lines.λ[idxs, :], lines.μ[idxs, :])

function Base.vcat(lines::Lines{N,L,T,P}...) where {N, L, T, P}

    n_lines = sum(length(line) for line in lines)

    names = Vector{String}(undef, n_lines)
    categories = Vector{String}(undef, n_lines)

    forward_capacity = Matrix{Int}(undef, n_lines, N)
    backward_capacity = Matrix{Int}(undef, n_lines, N)
    
    λ = Matrix{Float64}(undef,n_lines, N)
    μ = Matrix{Float64}(undef,n_lines, N)

    last_idx = 0

    for line in lines

        n = length(line)
        rows = last_idx .+ (1:n)

        names[rows] = line.names
        categories[rows] = line.categories

        forward_capacity[rows, :] = line.forward_capacity
        backward_capacity[rows, :] = line.backward_capacity

        λ[rows, :] = line.λ
        μ[rows, :] = line.μ

        last_idx += n

    end

    return Lines{N,L,T,P}(names, categories, forward_capacity, backward_capacity, λ, μ)

end

