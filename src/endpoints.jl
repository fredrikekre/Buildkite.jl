# SPDX-License-Identifier: MIT

"""
    builds() -> PagedRequest{Build}
    builds(org::Organization) -> PagedRequest{Build}
    builds(org::Organization, pipeline::Pipeline) -> PagedRequest{Build}

List builds — globally, for an organization, or for a specific pipeline.

API docs: <https://buildkite.com/docs/apis/rest-api/builds#list-all-builds>
"""
function builds(; kwargs...)
    return paged_request(Build, "GET", "/v2/builds"; kwargs...)
end
function builds(organization::Organization; kwargs...)
    return paged_request(
        Build, "GET", "/v2$(Internals.path(organization))/builds";
        kwargs...
    )
end
function builds(organization::Organization, pipeline::Pipeline; kwargs...)
    return paged_request(
        Build, "GET",
        "/v2$(Internals.path(organization))$(Internals.path(pipeline))/builds";
        kwargs...
    )
end

"""
    build(org::Organization, pipeline::Pipeline, number::Integer) -> Build

Get a single build by its pipeline-scoped number.

API docs: <https://buildkite.com/docs/apis/rest-api/builds#get-a-build>
"""
function build(organization::Organization, pipeline::Pipeline, number::Integer; kwargs...)
    return request(
        Build, "GET",
        "/v2$(Internals.path(organization))$(Internals.path(pipeline))/builds/$(number)";
        kwargs...
    )
end

"""
    pipelines(org::Organization) -> PagedRequest{Pipeline}

List pipelines for an organization.

API docs: <https://buildkite.com/docs/apis/rest-api/pipelines#list-pipelines>
"""
function pipelines(organization::Organization; kwargs...)
    return paged_request(
        Pipeline, "GET", "/v2$(Internals.path(organization))/pipelines";
        kwargs...
    )
end

"""
    pipeline(org::Organization, pipeline::Pipeline) -> Pipeline
    pipeline(org::Organization, slug::AbstractString) -> Pipeline
    pipeline(pipeline::Pipeline) -> Pipeline

Get a pipeline. The one-arg form follows `pipeline.url` and requires a `Pipeline`
returned from the API (not one constructed manually from a slug alone).

API docs: <https://buildkite.com/docs/apis/rest-api/pipelines#get-a-pipeline>
"""
function pipeline(organization::Organization, pipeline::Pipeline; kwargs...)
    return request(
        Pipeline, "GET",
        "/v2$(Internals.path(organization))$(Internals.path(pipeline))";
        kwargs...
    )
end
pipeline(organization::Organization, slug::AbstractString; kwargs...) =
    pipeline(organization, Pipeline(slug = slug); kwargs...)
pipeline(pipeline::Pipeline; kwargs...) =
    request(Pipeline, "GET", String((pipeline.url::URI).path); kwargs...)

"""
    access_token() -> AccessToken

Get the token used for authentication, including its scopes and owning user.

API docs: <https://buildkite.com/docs/apis/rest-api/access-token#get-the-current-token>
"""
function access_token(; kwargs...)
    return request(AccessToken, "GET", "/v2/access-token"; kwargs...)
end

"""
    user() -> User

Get the currently authenticated user.

API docs: <https://buildkite.com/docs/apis/rest-api/user#get-the-current-user>
"""
function user(; kwargs...)
    return request(User, "GET", "/v2/user"; kwargs...)
end

"""
    organizations() -> PagedRequest{Organization}

List all organizations visible to the token.

API docs: <https://buildkite.com/docs/apis/rest-api/organizations#list-organizations>
"""
function organizations(; kwargs...)
    return paged_request(Organization, "GET", "/v2/organizations"; kwargs...)
end

"""
    organization(org::Organization) -> Organization
    organization(slug::AbstractString) -> Organization

Get an organization by slug.

API docs: <https://buildkite.com/docs/apis/rest-api/organizations#get-an-organization>
"""
function organization(organization::Organization; kwargs...)
    return request(Organization, "GET", "/v2$(Internals.path(organization))"; kwargs...)
end
organization(slug::AbstractString; kwargs...) =
    organization(Organization(slug = slug); kwargs...)

"""
    artifacts(org, pipeline, build::Build) -> PagedRequest{Artifact}
    artifacts(org, pipeline, build::Build, job::Job) -> PagedRequest{Artifact}
    artifacts(job::Job) -> PagedRequest{Artifact}

List artifacts scoped to a build (all jobs) or a specific job. The one-arg form
follows `job.artifacts_url`.

API docs: <https://buildkite.com/docs/apis/rest-api/artifacts#list-artifacts-for-a-build>
"""
function artifacts(
        organization::Organization, pipeline::Pipeline, build::Build; kwargs...
    )
    return paged_request(
        Artifact, "GET",
        "/v2$(Internals.path(organization))$(Internals.path(pipeline))$(Internals.path(build))/artifacts";
        kwargs...
    )
end
function artifacts(
        organization::Organization, pipeline::Pipeline, build::Build, job::Job; kwargs...
    )
    return paged_request(
        Artifact, "GET",
        "/v2$(Internals.path(organization))$(Internals.path(pipeline))$(Internals.path(build))$(Internals.path(job))/artifacts";
        kwargs...
    )
end
artifacts(job::Job; kwargs...) =
    paged_request(Artifact, "GET", String((job.artifacts_url::URI).path); kwargs...)

"""
    artifact(org, pipeline, build, job, artifact::Artifact) -> Artifact
    artifact(artifact::Artifact) -> Artifact

Get a single artifact's metadata. The one-arg form follows `artifact.url`.

API docs: <https://buildkite.com/docs/apis/rest-api/artifacts#get-an-artifact>
"""
function artifact(
        organization::Organization, pipeline::Pipeline, build::Build,
        job::Job, artifact::Artifact; kwargs...
    )
    return request(
        Artifact, "GET",
        "/v2$(Internals.path(organization))$(Internals.path(pipeline))$(Internals.path(build))$(Internals.path(job))$(Internals.path(artifact))";
        kwargs...
    )
end
artifact(artifact::Artifact; kwargs...) =
    request(Artifact, "GET", String((artifact.url::URI).path); kwargs...)

"""
    annotations(org, pipeline, build::Build) -> PagedRequest{Annotation}

List annotations attached to a build.

API docs: <https://buildkite.com/docs/apis/rest-api/annotations#list-annotations-for-a-build>
"""
function annotations(
        organization::Organization, pipeline::Pipeline, build::Build; kwargs...
    )
    return paged_request(
        Annotation, "GET",
        "/v2$(Internals.path(organization))$(Internals.path(pipeline))$(Internals.path(build))/annotations";
        kwargs...
    )
end

"""
    job_log(job::Job) -> Log
    job_log(org, pipeline, build, job::Job) -> Log

Get a job's log output. Sets `Accept: application/json` to receive the structured
`Log` response (default `/log` returns HTML). The one-arg form follows `job.log_url`.

API docs: <https://buildkite.com/docs/apis/rest-api/jobs#get-a-jobs-log-output>
"""
function job_log(job::Job; kwargs...)
    # TODO: `Log.content` is the raw Buildkite log — per-line `\e_bk;t=<ms>\a` timestamp
    # prefixes, ANSI color escapes, `\r\n` line endings, and arbitrary Unicode (emoji)
    # passed through verbatim. Consumers likely want helpers (strip ANSI, split into
    # `(timestamp, text)` lines, etc.); none provided yet.
    log_url = job.log_url::URI
    headers = HTTP.Headers(["Accept" => "application/json"])
    return request(Log, "GET", String(log_url.path); headers = headers, kwargs...)
end
function job_log(
        organization::Organization, pipeline::Pipeline, build::Build, job::Job; kwargs...
    )
    headers = HTTP.Headers(["Accept" => "application/json"])
    return request(
        Log, "GET",
        "/v2$(Internals.path(organization))$(Internals.path(pipeline))$(Internals.path(build))$(Internals.path(job))/log";
        headers = headers, kwargs...,
    )
end

"""
    clusters(org::Organization) -> PagedRequest{Cluster}

List clusters for an organization.

API docs: <https://buildkite.com/docs/apis/rest-api/clusters#clusters-list-clusters>
"""
function clusters(organization::Organization; kwargs...)
    return paged_request(
        Cluster, "GET", "/v2$(Internals.path(organization))/clusters";
        kwargs...
    )
end

"""
    cluster(org::Organization, cluster::Cluster) -> Cluster
    cluster(org::Organization, id::UUID) -> Cluster
    cluster(org::Organization, name::AbstractString) -> Union{Cluster, Nothing}
    cluster(cluster::Cluster) -> Cluster

Get a cluster. Lookup by `name` paginates `clusters(org)` and returns `nothing` if
no match is found — prefer id when known. The one-arg form follows `cluster.url`.

API docs: <https://buildkite.com/docs/apis/rest-api/clusters#clusters-get-a-cluster>
"""
function cluster(organization::Organization, cluster::Cluster; kwargs...)
    return request(
        Cluster, "GET",
        "/v2$(Internals.path(organization))$(Internals.path(cluster))";
        kwargs...
    )
end
cluster(organization::Organization, id::UUID; kwargs...) =
    cluster(organization, Cluster(id = id); kwargs...)
cluster(cluster::Cluster; kwargs...) =
    request(Cluster, "GET", String((cluster.url::URI).path); kwargs...)
function cluster(organization::Organization, name::AbstractString; kwargs...)
    for c in clusters(organization; kwargs...)
        c.name == name && return c
    end
    return nothing
end

"""
    cluster_queues(org::Organization, cluster::Cluster) -> PagedRequest{ClusterQueue}
    cluster_queues(cluster::Cluster) -> PagedRequest{ClusterQueue}

List a cluster's queues. The one-arg form follows `cluster.queues_url`.

API docs: <https://buildkite.com/docs/apis/rest-api/clusters/queues#list-queues>
"""
function cluster_queues(organization::Organization, cluster::Cluster; kwargs...)
    return paged_request(
        ClusterQueue, "GET",
        "/v2$(Internals.path(organization))$(Internals.path(cluster))/queues";
        kwargs...
    )
end
cluster_queues(cluster::Cluster; kwargs...) =
    paged_request(ClusterQueue, "GET", String((cluster.queues_url::URI).path); kwargs...)

"""
    agents(org::Organization) -> PagedRequest{Agent}

List agents for an organization. Filter with query params like `name`, `hostname`,
`version`, `cluster`, `queue`.

API docs: <https://buildkite.com/docs/apis/rest-api/agents#list-agents>
"""
function agents(organization::Organization; kwargs...)
    return paged_request(
        Agent, "GET", "/v2$(Internals.path(organization))/agents";
        kwargs...
    )
end

"""
    agent(org::Organization, agent::Agent) -> Agent
    agent(org::Organization, id::UUID) -> Agent
    agent(agent::Agent) -> Agent

Get a single agent by id. The one-arg form follows `agent.url`.

API docs: <https://buildkite.com/docs/apis/rest-api/agents#get-an-agent>
"""
function agent(organization::Organization, agent::Agent; kwargs...)
    return request(
        Agent, "GET",
        "/v2$(Internals.path(organization))$(Internals.path(agent))";
        kwargs...
    )
end
agent(organization::Organization, id::UUID; kwargs...) =
    agent(organization, Agent(id = id); kwargs...)
agent(agent::Agent; kwargs...) =
    request(Agent, "GET", String((agent.url::URI).path); kwargs...)

"""
    cluster_queue(org, cluster, queue::ClusterQueue) -> ClusterQueue
    cluster_queue(org, cluster, id::UUID) -> ClusterQueue
    cluster_queue(org, cluster, key::AbstractString) -> Union{ClusterQueue, Nothing}
    cluster_queue(queue::ClusterQueue) -> ClusterQueue

Get a cluster queue. Lookup by `key` paginates `cluster_queues(org, cluster)`; prefer
id when known. The one-arg form follows `queue.url`.

API docs: <https://buildkite.com/docs/apis/rest-api/clusters/queues#get-a-queue>
"""
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
cluster_queue(queue::ClusterQueue; kwargs...) =
    request(ClusterQueue, "GET", String((queue.url::URI).path); kwargs...)
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

"""
    rate_limits() -> RateLimit

Return the current rate-limit state (remaining, limit, seconds-until-reset). Issued
via a `HEAD` against `/v2/access-token`; costs one rate-limited request.

API docs: <https://buildkite.com/docs/apis/rest-api/limits>
"""
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
