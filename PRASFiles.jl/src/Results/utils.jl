struct TypeParams
    N::Int64
    L::Int64
    T::String
    P::String
    E::String
end

function TypeParams(pras_sys::SystemModel{N,L,T,P,E}) where {N,L,T,P,E}
    return TypeParams(
        N,
        L,
        unitsymbol(T),
        unitsymbol(P),
        unitsymbol(E),
    )
end

struct EUEResult
    mean::Float64
    stderror::Float64
end

function EUEResult(shortfall::AbstractShortfallResult; region::Union{Nothing, String} = nothing)

    eue = (region === nothing) ? EUE(shortfall) :  EUE(shortfall, region)
    return EUEResult(
        eue.eue.estimate,
        eue.eue.standarderror,
    )
end

struct LOLEResult
    mean::Float64
    stderror::Float64
end

function LOLEResult(shortfall::AbstractShortfallResult; region::Union{Nothing, String} = nothing) 

    lole = (region === nothing) ?  LOLE(shortfall) : LOLE(shortfall, region)
    return LOLEResult(
        lole.lole.estimate,
        lole.lole.standarderror,
    )
end

struct NEUEResult
    mean::Float64
    stderror::Float64
end

function NEUEResult(shortfall::AbstractShortfallResult; region::Union{Nothing, String} = nothing)

    neue = (region === nothing) ? NEUE(shortfall) :  NEUE(shortfall, region)
    return NEUEResult(
        neue.neue.estimate,
        neue.neue.standarderror,
    )
end

struct LOLDResult
    mean::Float64
    stderror::Float64
end

function LOLDResult(shortfall::ShortfallSamplesResult; region::Union{Nothing,String}=nothing)
    lold = (region === nothing) ? LOLD(shortfall) : LOLD(shortfall, region)
    return LOLDResult(
        lold.lold.estimate,
        lold.lold.standarderror,
    )
end

struct RegionResult
    name::String
    eue::EUEResult
    lole::LOLEResult
    neue::NEUEResult
    lold::Union{Nothing,LOLDResult}
    load::Vector{Int64}
    peak_load::Float64
    capacity::Dict{String,Vector{Int64}}
    shortfall_mean::Vector{Float64}
    shortfall_timestamps::Vector{ZonedDateTime}
end

struct SystemResult
    num_samples::Int64
    type_params::TypeParams
    sys_attributes::Dict{String, String}
    timestamps::Vector{ZonedDateTime}
    eue::EUEResult
    lole::LOLEResult
    neue::NEUEResult
    lold::Union{Nothing,LOLDResult}
    region_results::Vector{RegionResult}
end

function get_shortfall_mean(shortfall::ShortfallResult)
    return shortfall.shortfall_mean
end

function get_shortfall_mean(shortfall::ShortfallSamplesResult)
    return mean(shortfall.shortfall, dims = 3)
end

function get_nsamples(shortfall::ShortfallResult)
    return shortfall.nsamples
end

function get_nsamples(shortfall::ShortfallSamplesResult)
    return size(shortfall.shortfall,3)
end

const _lold_warned = Ref(false)
function get_lold_result(shortfall::ShortfallResult; region::Union{Nothing,String}=nothing)
    if !_lold_warned[]
        @info "LOLD is not implemented for ShortfallResult and will not be included in the JSON export. Use ShortfallSamplesResult to compute LOLD."
        _lold_warned[] = true
    end
    return nothing
end

function get_lold_result(shortfall::ShortfallSamplesResult; region::Union{Nothing,String}=nothing)
    return LOLDResult(shortfall; region=region)
end

# Define structtypes for different structs defined above
StructType(::Type{TypeParams}) = Struct()
StructType(::Type{EUEResult}) = Struct()
StructType(::Type{NEUEResult}) = Struct()
StructType(::Type{LOLEResult}) = Struct()
StructType(::Type{LOLDResult}) = Struct()
StructType(::Type{RegionResult}) = OrderedStruct()
StructType(::Type{SystemResult}) = OrderedStruct()