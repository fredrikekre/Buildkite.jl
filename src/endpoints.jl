# SPDX-License-Identifier: MIT

# https://buildkite.com/docs/apis/rest-api/builds#list-all-builds
function builds(; kwargs...)
    return paged_request(Build, "GET", "/v2/builds"; kwargs...)
end

# https://buildkite.com/docs/apis/rest-api/builds#list-builds-for-an-organization
function builds(organization::Organization; kwargs...)
    return paged_request(
        Build, "GET", "/v2$(Internals.path(organization))/builds";
        kwargs...
    )
end

# https://buildkite.com/docs/apis/rest-api/builds#list-builds-for-a-pipeline
function builds(organization::Organization, pipeline::Pipeline; kwargs...)
    return paged_request(
        Build, "GET",
        "/v2$(Internals.path(organization))$(Internals.path(pipeline))/builds";
        kwargs...
    )
end

# https://buildkite.com/docs/apis/rest-api/access-token#get-the-current-token
function access_token(; kwargs...)
    return request(AccessToken, "GET", "/v2/access-token"; kwargs...)
end

# https://buildkite.com/docs/apis/rest-api/limits
struct RateLimit
    remaining::Int
    limit::Int
    reset::Int
    request_time::DateTime
end

function rate_limits(; kwargs...)
    # Hit a rate-limited endpoint so that we can read the limits from the header
    r = Internals.request("HEAD", "/v2/access-token"; kwargs...)
    rate_limit = RateLimit(
        parse(Int, HTTP.header(r, "RateLimit-Remaining")),
        parse(Int, HTTP.header(r, "RateLimit-Limit")),
        parse(Int, HTTP.header(r, "RateLimit-Reset")),
        Dates.now()
    )
    return rate_limit
end

# function wait_for_rate_limit_reset(r::RateLimit, n::Int = 10)
#     if r.remaining >= n
#         return
#     end
#     reset_time = r.request_time + Dates.Second(r.reset)
#     if Dates.now() > reset_time
#         return
#     else
#         sleeptime = Dates.value((reset_time - Dates.now())::Dates.Millisecond)
#         sleep(ceil(sleeptime / 10) / 100) # Round up to 10ms
#     end
# end
