abstract type ReliabilityMetric end

struct MeanEstimate

    estimate::Float64
    standarderror::Float64

    function MeanEstimate(est::Real, stderr::Real)

        stderr >= 0 || throw(DomainError(stderr,
            "Standard error of the estimate should be non-negative"))

        new(convert(Float64, est), convert(Float64, stderr))

    end

end

MeanEstimate(x::Real) = MeanEstimate(x, 0)
MeanEstimate(x::Real, ::Real, ::Nothing) = MeanEstimate(x, 0)
MeanEstimate(mu::Real, sigma::Real, n::Int) = MeanEstimate(mu, sigma / sqrt(n))

function MeanEstimate(xs::AbstractArray{<:Real})
    est = mean(xs)
    return MeanEstimate(est, std(xs, mean=est), length(xs))
end

val(est::MeanEstimate) = est.estimate
stderror(est::MeanEstimate) = est.standarderror

Base.isapprox(x::MeanEstimate, y::MeanEstimate) =
        isapprox(x.estimate, y.estimate) &&
        isapprox(x.standarderror, y.standarderror)

Base.div(x::MeanEstimate, y::Float64) = 
    MeanEstimate(x.estimate/y, x.standarderror/y)

function Base.show(io::IO, x::MeanEstimate)
    v, s = stringprecision(x)
    print(io, v, x.standarderror > 0 ? "±"*s : "")
end

function stringprecision(x::MeanEstimate)

    if iszero(x.standarderror)

        v_rounded = @sprintf "%0.5f" x.estimate
        s_rounded = "0"

    else

        stderr_round = round(x.standarderror, sigdigits=1)
        digits = -floor(Int, log(10, stderr_round))

        if digits > 0
            v_rounded = @sprintf "%0.*f" digits x.estimate
            s_rounded = @sprintf "%0.*f" digits x.standarderror
        else
            v_rounded = @sprintf "%0.0f" round(x.estimate, digits=digits)
            s_rounded = @sprintf "%0.0f" round(x.standarderror, digits=digits)
        end

    end

    return v_rounded, s_rounded

end

Base.isapprox(x::ReliabilityMetric, y::ReliabilityMetric) =
        isapprox(val(x), val(y)) && isapprox(stderror(x), stderror(y))

"""
    LOLE

`LOLE` reports loss of load expectation over a particular time period
and regional extent. When the reporting period is a single simulation
timestep, the metric is equivalent to loss of load probability (LOLP).

Contains both the estimated value itself as well as the standard error
of that estimate, which can be extracted with `val` and `stderror`,
respectively.
"""
struct LOLE{N, L, T <: Period} <: ReliabilityMetric
    lole::MeanEstimate

    function LOLE{N,L,T}(lole::MeanEstimate) where {N,L,T<:Period}
        val(lole) >= 0 || throw(DomainError(val,
            "$val is not a valid expected count of event-periods"))
        new{N,L,T}(lole)
    end

end

val(x::LOLE) = val(x.lole)
stderror(x::LOLE) = stderror(x.lole)

function Base.show(io::IO, x::LOLE{N,L,T}) where {N,L,T}

    t_symbol = unitsymbol(T)
    print(io, "LOLE = ", x.lole, " event-",
          L == 1 ? t_symbol : "(" * string(L) * t_symbol * ")", "/",
          N*L == 1 ? "" : N*L, t_symbol)

end

"""
    EUE

`EUE` reports expected unserved energy over a particular time period and
regional extent.

Contains both the estimated value itself as well as the standard error
of that estimate, which can be extracted with `val` and `stderror`,
respectively.
"""
struct EUE{N,L,T<:Period,E<:EnergyUnit} <: ReliabilityMetric

    eue::MeanEstimate

    function EUE{N,L,T,E}(eue::MeanEstimate) where {N,L,T<:Period,E<:EnergyUnit}
        val(eue) >= 0 || throw(DomainError(
            "$val is not a valid unserved energy expectation"))
        new{N,L,T,E}(eue)
    end

end

val(x::EUE) = val(x.eue)
stderror(x::EUE) = stderror(x.eue)

function Base.show(io::IO, x::EUE{N,L,T,E}) where {N,L,T,E}

    print(io, "EUE = ", x.eue, " ",
          unitsymbol(E), "/", N*L == 1 ? "" : N*L, unitsymbol(T))

end

"""
    NEUE

`NEUE` reports normalized expected unserved energy over a regional extent.

Contains both the estimated value itself as well as the standard error
of that estimate, which can be extracted with `val` and `stderror`,
respectively.
"""
struct NEUE <: ReliabilityMetric

    neue::MeanEstimate

    function NEUE(neue::MeanEstimate)
        val(neue) >= 0 || throw(DomainError(
            "$val is not a valid unserved energy expectation"))
        new(neue)
    end

end

val(x::NEUE) = val(x.neue)
stderror(x::NEUE) = stderror(x.neue)

function Base.show(io::IO, x::NEUE)

    print(io, "NEUE = ", x.neue, " ppm")

end

"""
    CVAR

`CVAR` reports conditional value at risk of shortfalls.

Contains both the estimated value itself as well as the standard error
of that estimate, which can be extracted with `val` and `stderror`,
respectively.
"""
struct CVAR{N,L,T<:Period,E<:EnergyUnit} <: ReliabilityMetric

    cvar::MeanEstimate
    alpha::Float64
    
    function CVAR{N,L,T,E}(cvar::MeanEstimate, alpha::Float64) where {N,L,T<:Period,E<:EnergyUnit}
        val(cvar) >= 0 || throw(DomainError(
            "$val is not a valid CVAR"))
        new{N,L,T,E}(cvar, alpha)
    end

end

val(x::CVAR) = val(x.cvar)
stderror(x::CVAR) = stderror(x.cvar)

function Base.show(io::IO, x::CVAR{N,L,T,E}) where {N,L,T,E}

    print(io, "CVAR@$(x.alpha) = ", x.cvar, " ",
          unitsymbol(E), "/", N*L == 1 ? "" : N*L, unitsymbol(T))

end