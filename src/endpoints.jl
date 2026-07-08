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

# https://buildkite.com/docs/apis/rest-api/builds#get-a-build
function build(organization::Organization, pipeline::Pipeline, number::Integer; kwargs...)
    return request(
        Build, "GET",
        "/v2$(Internals.path(organization))$(Internals.path(pipeline))/builds/$(number)";
        kwargs...
    )
end

# https://buildkite.com/docs/apis/rest-api/pipelines#list-pipelines
function pipelines(organization::Organization; kwargs...)
    return paged_request(
        Pipeline, "GET", "/v2$(Internals.path(organization))/pipelines";
        kwargs...
    )
end

# https://buildkite.com/docs/apis/rest-api/pipelines#get-a-pipeline
function pipeline(organization::Organization, pipeline::Pipeline; kwargs...)
    return request(
        Pipeline, "GET",
        "/v2$(Internals.path(organization))$(Internals.path(pipeline))";
        kwargs...
    )
end
pipeline(organization::Organization, slug::AbstractString; kwargs...) =
    pipeline(organization, Pipeline(slug = slug); kwargs...)

# https://buildkite.com/docs/apis/rest-api/access-token#get-the-current-token
function access_token(; kwargs...)
    return request(AccessToken, "GET", "/v2/access-token"; kwargs...)
end

# https://buildkite.com/docs/apis/rest-api/clusters#clusters-list-clusters
function clusters(organization::Organization; kwargs...)
    return paged_request(
        Cluster, "GET", "/v2$(Internals.path(organization))/clusters";
        kwargs...
    )
end

# https://buildkite.com/docs/apis/rest-api/clusters#clusters-get-a-cluster
function cluster(organization::Organization, cluster::Cluster; kwargs...)
    return request(
        Cluster, "GET",
        "/v2$(Internals.path(organization))$(Internals.path(cluster))";
        kwargs...
    )
end
cluster(organization::Organization, id::UUID; kwargs...) =
    cluster(organization, Cluster(id = id); kwargs...)

# Resolve a cluster by `name` by paginating through `clusters(organization)`. Note that
# this triggers a full list request; prefer looking up by `id` when known.
function cluster(organization::Organization, name::AbstractString; kwargs...)
    for c in clusters(organization; kwargs...)
        c.name == name && return c
    end
    return nothing
end

# https://buildkite.com/docs/apis/rest-api/clusters/queues#list-queues
function cluster_queues(organization::Organization, cluster::Cluster; kwargs...)
    return paged_request(
        ClusterQueue, "GET",
        "/v2$(Internals.path(organization))$(Internals.path(cluster))/queues";
        kwargs...
    )
end

# https://buildkite.com/docs/apis/rest-api/agents#list-agents
function agents(organization::Organization; kwargs...)
    return paged_request(
        Agent, "GET", "/v2$(Internals.path(organization))/agents";
        kwargs...
    )
end

# https://buildkite.com/docs/apis/rest-api/agents#get-an-agent
function agent(organization::Organization, agent::Agent; kwargs...)
    return request(
        Agent, "GET",
        "/v2$(Internals.path(organization))$(Internals.path(agent))";
        kwargs...
    )
end
agent(organization::Organization, id::UUID; kwargs...) =
    agent(organization, Agent(id = id); kwargs...)

# https://buildkite.com/docs/apis/rest-api/clusters/queues#get-a-queue
function cluster_queue(
        organization::Organization, cluster::Cluster, queue::ClusterQueue; kwargs...
    )
    return request(
        ClusterQueue, "GET",
        "/v2$(Internals.path(organization))$(Internals.path(cluster))$(Internals.path(queue))";
        kwargs...
    )
end
cluster_queue(organization::Organization, cluster::Cluster, id::UUID; kwargs...) =
    cluster_queue(organization, cluster, ClusterQueue(id = id); kwargs...)

# Resolve a queue by `key` by paginating through `cluster_queues(organization, cluster)`.
function cluster_queue(
        organization::Organization, cluster::Cluster, key::AbstractString; kwargs...
    )
    for q in cluster_queues(organization, cluster; kwargs...)
        q.key == key && return q
    end
    return nothing
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
