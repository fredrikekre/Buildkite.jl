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
    Buildkite.paged_request(method, endpoint; kwargs...) -> Channel{JSONObject}
    Buildkite.paged_request(T, method, endpoint; kwargs...) -> Channel{T}

General method for HTTP requests to `endpoint`. Return a `Channel` which iterates the paged
items.
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
            return next_uri
        end
    end
    return nothing
end

function Internals.paged_request(
        ::Type{IT}, method::String, endpoint::String = ""; token = nothing,
        headers = nothing, page_limit = typemax(Int),
        query = nothing, kwargs...
    ) where {IT}

    headers = Internals.buildkite_headers(headers; token = token)
    uri = URIs.URI(BUILDKITE_API_URL; path = endpoint)
    query = Internals.process_query_params(query)
    # Issue the initial request to the API uri and put the items in a channel.
    r = HTTP.request(method, uri, headers; query = query, kwargs...)
    items = JSON.parse(r.body)::AbstractVector
    ch = Channel{IT}(length(items))
    for item in items
        put!(ch, Internals.unmarshal(IT, item)::IT)
    end
    # Create a task which will fill up the channel with more pages lazily
    tsk = @async begin
        page_count = 1
        while page_count < page_limit && (next_uri = Internals.link_rel_next(r); next_uri !== nothing)
            # The follow up requests use the Link header for the next uri but we pass the
            # same method, headers and kwargs.
            r = HTTP.request(method, next_uri, headers; kwargs...)
            items = JSON.parse(r.body)
            for item in items
                put!(ch, Internals.unmarshal(IT, item)::IT)
            end
            page_count += 1
        end
    end
    bind(ch, tsk)
    return ch
end

# Buildkite objects
include("objects.jl")

# Exposed endpoints
include("endpoints.jl")

end # module Buildkite
