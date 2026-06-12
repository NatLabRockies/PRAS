"""
    SlicedTimestamps{T<:Period} <: AbstractVector{ZonedDateTime}

A non-contiguous time axis for a [`SystemModel`](@ref), made up of one or more
contiguous `StepRange` "slices" with gaps between them (e.g. a representative
summer week plus a representative winter week).

The slices are stored as-is in `slices`, preserving their structure for file I/O
and display. Because `SlicedTimestamps` subtypes `AbstractVector{ZonedDateTime}`,
it also behaves as a flat, length-`N` vector of timestamps (where `N` is the total
number of timesteps across all slices) — `length`, integer indexing, iteration,
`findfirst`, etc. all operate on the concatenated `1:N` sequence. This lets the
simulation engine and result objects treat the time axis exactly as they would a
single contiguous range.

All slices must share the same step (the timestep `T(L)`) and be strictly ordered
and non-overlapping.

# Fields
- `slices`: the contiguous `StepRange` slices, in order
- `offsets`: cumulative timestep counts, `offsets[k]` is the number of timesteps
  preceding slice `k`; length `length(slices)+1` with `offsets[end] == N`
"""
struct SlicedTimestamps{T<:Period} <: AbstractVector{ZonedDateTime}
    slices::Vector{StepRange{ZonedDateTime,T}}
    offsets::Vector{Int}

    function SlicedTimestamps(slices::Vector{StepRange{ZonedDateTime,T}}) where {T<:Period}

        n = length(slices)
        n > 0 || throw(ArgumentError("SlicedTimestamps requires at least one slice"))

        Δ = step(first(slices))
        for (k, slice) in enumerate(slices)
            length(slice) > 0 ||
                throw(ArgumentError("Timestamp slice $k is empty"))
            step(slice) == Δ ||
                throw(ArgumentError(
                    "All timestamp slices must share the same step; slice $k has " *
                    "step $(step(slice)) but slice 1 has step $Δ"))
        end

        # Slices must be strictly ordered and non-overlapping
        for k in 1:(n - 1)
            first(slices[k + 1]) > last(slices[k]) ||
                throw(ArgumentError(
                    "Timestamp slices must be strictly ordered and non-overlapping: " *
                    "slice $(k + 1) starts at $(first(slices[k + 1])), which is not " *
                    "after the end of slice $k at $(last(slices[k]))"))
        end

        offsets = Vector{Int}(undef, n + 1)
        offsets[1] = 0
        for k in 1:n
            offsets[k + 1] = offsets[k] + length(slices[k])
        end

        new{T}(slices, offsets)

    end

end

Base.size(ts::SlicedTimestamps) = (ts.offsets[end],)

Base.IndexStyle(::Type{<:SlicedTimestamps}) = IndexLinear()

function Base.getindex(ts::SlicedTimestamps, i::Int)
    @boundscheck checkbounds(ts, i)
    k = searchsortedlast(ts.offsets, i - 1)
    return @inbounds ts.slices[k][i - ts.offsets[k]]
end

Base.:(==)(x::SlicedTimestamps, y::SlicedTimestamps) = x.slices == y.slices

Base.show(io::IO, ts::SlicedTimestamps) = show(io, ts.slices)

function Base.show(io::IO, ::MIME"text/plain", ts::SlicedTimestamps)
    print(io, "[")
    for (k, s) in enumerate(ts.slices)
        k == 1 || print(io, ",\n ")
        show(io, s)
    end
    print(io, "]")
end

"""
    timestep(ts) -> Period

The (uniform) timestep of a time axis, i.e. `T(L)`. Works for both a contiguous
`StepRange` and a [`SlicedTimestamps`](@ref).
"""
timestep(ts::SlicedTimestamps) = step(first(ts.slices))
timestep(ts::AbstractRange{ZonedDateTime}) = step(ts)
