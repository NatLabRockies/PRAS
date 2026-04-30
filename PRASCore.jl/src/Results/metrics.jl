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
    if length(xs) > 1
        return MeanEstimate(est, std(xs, mean=est), length(xs))
    else
        return MeanEstimate(est)
    end
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
    LOLD

`LOLD` reports loss of load days over a particular time period
and regional extent.

Contains both the estimated value itself as well as the standard error
of that estimate, which can be extracted with `val` and `stderror`,
respectively.
"""
struct LOLD{D} <: ReliabilityMetric
    lold::MeanEstimate

    function LOLD{D}(lold::MeanEstimate) where {D}
        val(lold) >= 0 || throw(DomainError(val(lold),
            "$(val(lold)) is not a valid expected count of event-days"))
        new{D}(lold)
    end
end

val(x::LOLD) = val(x.lold)
stderror(x::LOLD) = stderror(x.lold)

function Base.show(io::IO, x::LOLD{D}) where {D}
    print(io, "LOLD = ", x.lold, " event-day/",
          D == 1 ? "day" : string(D) * "days")
end

"""
    LOLEv

`LOLEv` reports loss of load events over a particular time period
and regional extent.

Contains both the estimated value itself as well as the standard error
of that estimate, which can be extracted with `val` and `stderror`,
respectively.
"""
struct LOLEv{N, L, T <: Period} <: ReliabilityMetric
    lolev::MeanEstimate

    function LOLEv{N,L,T}(lolev::MeanEstimate) where {N,L,T<:Period}
        val(lolev) >= 0 || throw(DomainError(val(lolev),
            "$(val(lolev)) is not a valid expected count of events"))
        new{N,L,T}(lolev)
    end
end

val(x::LOLEv) = val(x.lolev)
stderror(x::LOLEv) = stderror(x.lolev)

function Base.show(io::IO, x::LOLEv{N,L,T}) where {N,L,T}
    print(io, "LOLEv = ", x.lolev, " events")
end


"""
    MeanEventDuration

`MeanEventDuration` reports the expected average duration of shortfall
events over a particular time period and regional extent.

For each sample, the mean duration of all events in that sample
is computed. Samples with no events are assigned a duration of 0. The final
reported metric is the mean estimate across samples.

Contains both the estimated value itself as well as the standard error
of that estimate, which can be extracted with `val` and `stderror`,
respectively.
"""
struct MeanEventDuration{N, L, T <: Period} <: ReliabilityMetric
    duration::MeanEstimate

    function MeanEventDuration{N,L,T}(duration::MeanEstimate) where {N,L,T<:Period}
        val(duration) >= 0 || throw(DomainError(val(duration),
            "$(val(duration)) is not a valid expected event duration"))
        new{N,L,T}(duration)
    end
end

val(x::MeanEventDuration) = val(x.duration)
stderror(x::MeanEventDuration) = stderror(x.duration)

function Base.show(io::IO, x::MeanEventDuration{N,L,T}) where {N,L,T}
    t_symbol = unitsymbol(T)
    print(io, "MeanEventDuration = ", x.duration, " ",
          L == 1 ? t_symbol : "(" * string(L) * t_symbol * ")")
end


"""
    MaxEventDuration

`MaxEventDuration` reports the expected maximum duration of shortfall
events over a particular time period and regional extent.

For each sample, the maximum duration of all events in that sample
is computed. Samples with no events are assigned a duration of 0. The final
reported metric is the mean estimate across samples.

Contains both the estimated value itself as well as the standard error
of that estimate, which can be extracted with `val` and `stderror`,
respectively.
"""
struct MaxEventDuration{N, L, T <: Period} <: ReliabilityMetric
    duration::MeanEstimate

    function MaxEventDuration{N,L,T}(duration::MeanEstimate) where {N,L,T<:Period}
        val(duration) >= 0 || throw(DomainError(val(duration),
            "$(val(duration)) is not a valid expected maximum event duration"))
        new{N,L,T}(duration)
    end
end

val(x::MaxEventDuration) = val(x.duration)
stderror(x::MaxEventDuration) = stderror(x.duration)

function Base.show(io::IO, x::MaxEventDuration{N,L,T}) where {N,L,T}
    t_symbol = unitsymbol(T)
    print(io, "MaxEventDuration = ", x.duration, " ",
          L == 1 ? t_symbol : "(" * string(L) * t_symbol * ")")
end


"""
    MeanEventEnergy

`MeanEventEnergy` reports the expected average unserved energy of shortfall
events over a particular time period and regional extent.

For each sample, the mean energy of all events in that sample
is computed. Samples with no events are assigned an energy of 0. The final
reported metric is the mean estimate across samples.

Contains both the estimated value itself as well as the standard error
of that estimate, which can be extracted with `val` and `stderror`,
respectively.
"""
struct MeanEventEnergy{N,L,T<:Period,E<:EnergyUnit} <: ReliabilityMetric
    energy::MeanEstimate

    function MeanEventEnergy{N,L,T,E}(energy::MeanEstimate) where {N,L,T<:Period,E<:EnergyUnit}
        val(energy) >= 0 || throw(DomainError(val(energy),
            "$(val(energy)) is not a valid expected event energy"))
        new{N,L,T,E}(energy)
    end
end

val(x::MeanEventEnergy) = val(x.energy)
stderror(x::MeanEventEnergy) = stderror(x.energy)

function Base.show(io::IO, x::MeanEventEnergy{N,L,T,E}) where {N,L,T,E}
    print(io, "MeanEventEnergy = ", x.energy, " ", unitsymbol(E))
end


"""
    MaxEventEnergy

`MaxEventEnergy` reports the expected maximum unserved energy of shortfall
events over a particular time period and regional extent.

For each sample, the maximum event energy in that sample
is computed. Samples with no events are assigned an energy of 0. The final
reported metric is the mean estimate across samples.

Contains both the estimated value itself as well as the standard error
of that estimate, which can be extracted with `val` and `stderror`,
respectively.
"""
struct MaxEventEnergy{N,L,T<:Period,E<:EnergyUnit} <: ReliabilityMetric
    energy::MeanEstimate

    function MaxEventEnergy{N,L,T,E}(energy::MeanEstimate) where {N,L,T<:Period,E<:EnergyUnit}
        val(energy) >= 0 || throw(DomainError(val(energy),
            "$(val(energy)) is not a valid expected maximum event energy"))
        new{N,L,T,E}(energy)
    end
end

val(x::MaxEventEnergy) = val(x.energy)
stderror(x::MaxEventEnergy) = stderror(x.energy)

function Base.show(io::IO, x::MaxEventEnergy{N,L,T,E}) where {N,L,T,E}
    print(io, "MaxEventEnergy = ", x.energy, " ", unitsymbol(E))
end