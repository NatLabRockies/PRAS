const MeanVariance = Series{
    Number, Tuple{Mean{Float64, EqualWeight},
                  Variance{Float64, Float64, EqualWeight}}}

meanvariance() = Series(Mean(), Variance())

function mean_std(x::MeanVariance)
    m, v = value(x)
    return m, sqrt(v)
end

function mean_std(x::AbstractArray{<:MeanVariance})

    means = similar(x, Float64)
    vars = similar(means)

    for i in eachindex(x)
        m, v = mean_std(x[i])
        means[i] = m
        vars[i] = v
    end

    return means, vars

end

function findfirstunique_directional(a::AbstractVector{<:Pair}, i::Pair)
    i_idx = findfirst(isequal(i), a)
    if isnothing(i_idx)
        i_idx = findfirstunique(a, last(i) => first(i))
        reverse = true
    else
        reverse = false
    end
    return i_idx, reverse
end

function findfirstunique(a::AbstractVector{T}, i::T) where T
    i_idx = findfirst(isequal(i), a)
    i_idx === nothing && throw(BoundsError(a))
    return i_idx
end

function findlastunique(a::AbstractVector{T}, i::T) where T
    i_idx = findlast(isequal(i), a)
    i_idx === nothing && throw(BoundsError(a))
    return i_idx
end

function _cvar(estimate::AbstractVector{<:Real}, alpha::Float64)
    var = quantile(estimate, alpha)
    tail = estimate[estimate .> var]   
    cvar = isempty(tail) ? MeanEstimate(0.) : MeanEstimate(tail)
    return cvar, var
end

function _ncvar(cvar::CVAR, demand::Real)
    if demand > 0
        scale = demand / 1e6
        ncvar = div(cvar.cvar, scale)
        var = cvar.var / scale
    else
        ncvar = MeanEstimate(0.)
        var = 0.0
    end
    return ncvar, var
end