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

function _day_ids(timestamps)
    n = length(timestamps)
    ids = Vector{Int}(undef, n)

    n == 0 && return ids

    current_day = Date(first(timestamps))
    current_id = 1
    ids[1] = current_id

    for i in 2:n
        d = Date(timestamps[i])
        if d != current_day
            current_day = d
            current_id += 1
        end
        ids[i] = current_id
    end

    return ids
end

function _ndays(timestamps)
    if isempty(timestamps)
        return 0
    else
        return last(_day_ids(timestamps))
    end
end

function _unique_days(timestamps)
    return unique(Date.(timestamps))
end

function _day_range(timestamps, d::Date)
    n = length(timestamps)
    n == 0 && throw(ArgumentError("date $(d) is not in the simulation horizon (empty horizon)"))

    first_i = findfirst(t -> Date(t) == d, timestamps)
    first_i === nothing && throw(ArgumentError(
        "date $(d) is not in the simulation horizon ($(Date(first(timestamps))) to $(Date(last(timestamps))))"
    ))

    last_i = first_i
    while last_i < n && Date(timestamps[last_i + 1]) == d
        last_i += 1
    end

    return first_i:last_i
end