module Buildkite

import HTTP, JSON, Dates, URIs

using Base: UUID
using Dates: Dates, DateTime
using URIs: URIs, URI

include("Internals.jl")

const BUILDKITE_API_URL = URIs.URI("https://api.buildkite.com")
const BUILDKITE_DATE_FORMAT = Dates.dateformat"yyyy-mm-dd\THH:MM:SS\Z"
const BUILDKITE_DATE_FORMAT_MS = Dates.dateformat"yyyy-mm-dd\THH:MM:SS.sss\Z"

################################
## Internal request utilities ##
################################

# Set Authorization and User-Agent
function Internals.buildkite_headers(headers = nothing; token = nothing)
    if headers === nothing
        headers = Dict{String, String}()
    else
        headers = Dict{String, String}(h for h in headers)
    end
    if !haskey(headers, "Authorization")
        if token === nothing
            token = get(ENV, "BUILDKITE_TOKEN", nothing)
        end
        if token === nothing
            throw(ArgumentError("No token provided and no BUILDKITE_TOKEN found in ENV"))
        end
        headers["Authorization"] = "Bearer $(token)"
    end
    if !haskey(headers, "User-Agent")
        headers["User-Agent"] = "Buildkite.jl" # Always overwrite this?
    end
    return headers
end

# Preprocess parameters before sending them to HTTP.jl
Internals.process_query_params(query::Union{AbstractString, Nothing}) = query
function Internals.process_query_params(query)
    query′ = Dict{String, Any}()
    # Assume it iterates pairs
    for (k, v) in query
        query′[Internals.process_key(k)] = Internals.process_val(v)
    end
    return query′
end
Internals.process_key(k) = string(k)
Internals.process_val(v) = string(v)
Internals.process_val(v::AbstractVector) = map(Internals.process_val, v)
# function Internals.process_val(zdt::TimeZones.ZonedDateTime)
#     zdt = TimeZones.astimezone(zdt, TimeZones.tz"Z")
#     str = Dates.format(zdt, Dates.dateformat"yyyy-mm-ddTHH:MM:SSZ")
#     return str
# end

############################
## Public request methods ##
############################

"""
    Buildkite.request(method, endpoint; kwargs...) -> JSONObject
    Buildkite.request(T, method, endpoint; kwargs...) -> T

General method for HTTP requests to `endpoint`.

**Keyword arguments:**

 - `query`: dictionary with request query parameters.
 - `token`: Buildkite API access token for authentication (default:
   `ENV["BUILDKITE_TOKEN"]`).

Remaining keyword arguments are passed to
[`HTTP.request`](https://juliaweb.github.io/HTTP.jl/stable/public_interface/#Requests-1).
"""
function request(method::String, endpoint::String = ""; kwargs...)
    return request(JSONObject, method, endpoint; kwargs...)
end
function request(::Type{T}, method::String, endpoint::String = ""; kwargs...) where {T}
    r = Internals.request(method, endpoint; kwargs...)
    return Internals.unmarshal(T, JSON.parse(r.body))
end
# Internal request method, returning a HTTP.Response
function Internals.request(
        method::String, endpoint::String = ""; token = nothing,
        headers = nothing, query = nothing, kwargs...
    )
    headers = Internals.buildkite_headers(headers; token = token)
    uri = joinpath(BUILDKITE_API_URL, endpoint)
    query = Internals.process_query_params(query)
    r = HTTP.request(method, uri, headers; query = query, kwargs...)
    return r
end

"""
    Buildkite.paged_request(method, endpoint; kwargs...) -> PagedRequest{JSONObject}
    Buildkite.paged_request(T, method, endpoint; kwargs...) -> PagedRequest{T}

General method for HTTP requests to a paginated `endpoint`. Returns a lazy iterator that
fetches each page from the API on demand as iteration proceeds. Use `collect` to
materialize all pages into a `Vector{T}`.
"""
function paged_request(method::String, endpoint::String = ""; kwargs...)
    return Internals.paged_request(JSONObject, method, endpoint; kwargs...)
end
function paged_request(::Type{T}, method::String, endpoint::String = ""; kwargs...) where {T}
    return Internals.paged_request(T, method, endpoint; kwargs...)
end

function Internals.link_rel_next(r)
    for link in eachsplit(HTTP.header(r, "Link"), ","; keepempty = false)
        if occursin("rel=\"next\"", link)
            next_uri = (match(r"<(.+)>", link)::RegexMatch).captures[1]::AbstractString
            return String(next_uri)
        end
    end
    return nothing
end

# Lazy paginating iterator: fetches page N on first `iterate` call, page N+1 only when
# the caller has drained page N.
struct PagedRequest{T}
    method::String
    initial_uri::URI
    headers::Dict{String, String}
    query::Union{Dict{String, Any}, Nothing}
    request_kwargs::Base.Pairs
    page_limit::Int
end

Base.eltype(::Type{PagedRequest{T}}) where {T} = T
Base.IteratorSize(::Type{<:PagedRequest}) = Base.SizeUnknown()

mutable struct PagedState{T}
    items::Vector{T}
    idx::Int
    next_uri::Union{String, Nothing}
    page_count::Int
end

function _fetch_page!(items::Vector{T}, method, uri, headers, query, kwargs) where {T}
    r = HTTP.request(method, uri, headers; query = query, kwargs...)
    raw = JSON.parse(r.body)::AbstractVector
    resize!(items, length(raw))
    for i in eachindex(raw, items)
        items[i] = Internals.unmarshal(T, raw[i])::T
    end
    return Internals.link_rel_next(r)
end

function Base.iterate(pr::PagedRequest{T}) where {T}
    state = PagedState{T}(T[], 1, nothing, 0)
    state.next_uri = _fetch_page!(
        state.items, pr.method, pr.initial_uri, pr.headers, pr.query, pr.request_kwargs,
    )
    state.page_count = 1
    return iterate(pr, state)
end

function Base.iterate(pr::PagedRequest{T}, state::PagedState{T}) where {T}
    if state.idx <= length(state.items)
        v = state.items[state.idx]
        state.idx += 1
        return (v, state)
    end
    if state.page_count >= pr.page_limit || state.next_uri === nothing
        return nothing
    end
    # Follow-up requests use the Link header URI; query is already baked in there.
    state.next_uri = _fetch_page!(
        state.items, pr.method, URI(state.next_uri), pr.headers, nothing, pr.request_kwargs,
    )
    state.idx = 1
    state.page_count += 1
    return iterate(pr, state)
end

function Internals.paged_request(
        ::Type{IT}, method::String, endpoint::String = ""; token = nothing,
        headers = nothing, page_limit = typemax(Int),
        query = nothing, kwargs...
    ) where {IT}

    headers = Internals.buildkite_headers(headers; token = token)
    uri = URIs.URI(BUILDKITE_API_URL; path = endpoint)
    query = Internals.process_query_params(query)
    return PagedRequest{IT}(method, uri, headers, query, kwargs, page_limit)
end

# Buildkite objects
include("objects.jl")

# Exposed endpoints
include("endpoints.jl")

end # module Buildkite
