# Buildkite.jl

[![CI](https://github.com/fredrikekre/Buildkite.jl/actions/workflows/CI.yml/badge.svg?event=push)](https://github.com/fredrikekre/Buildkite.jl/actions/workflows/CI.yml)
[![code style: runic](https://img.shields.io/badge/code_style-%E1%9A%B1%E1%9A%A2%E1%9A%BE%E1%9B%81%E1%9A%B2-black)](https://github.com/fredrikekre/Runic.jl)

Buildkite.jl is a Julia package for interacting with the [Buildkite REST
API](https://buildkite.com/docs/apis/rest-api).

## Authentication

All requests need a Buildkite API access token. Set it via the `BUILDKITE_TOKEN`
environment variable, or pass it explicitly with the `token` keyword argument to any
request function.

```julia
ENV["BUILDKITE_TOKEN"] = "bkua_..."
```

## Requests and pagination

Two low-level helpers back every endpoint:

- `Buildkite.request([T,] method, endpoint; kwargs...)` — single request. Returns `T`
  (or `Dict{String, Any}` when `T` is omitted). Extra `kwargs...` are forwarded to
  [`HTTP.request`](https://juliaweb.github.io/HTTP.jl/stable/api/client/#HTTP.request).
- `Buildkite.paged_request([T,] method, endpoint; kwargs...)` — paginated request.
  Returns a lazy iterator that fetches each page on demand as iteration proceeds.
  Breaking out of iteration stops further requests. `collect` materializes all pages
  into a `Vector{T}`.

Common keyword arguments across both:

- `token` — API token (defaults to `ENV["BUILDKITE_TOKEN"]`).
- `query` — dictionary of URL query parameters.
- `headers` — extra HTTP headers.
- `page_limit` (paged only) — cap on the number of pages fetched.

## API surface

Every read endpoint from the REST API is wrapped. Docstrings on each function link
back to the corresponding Buildkite docs section. Where an object returned by the API
carries a `url` field, there is a one-argument shortcut that follows that URL directly.

### Authentication and account

- `Buildkite.access_token()` — the current token, its scopes and owner.
- `Buildkite.user()` — the currently authenticated user.
- `Buildkite.rate_limits()` — current rate-limit state.

### Organizations

- `Buildkite.organizations()` — list.
- `Buildkite.organization(slug)` / `Buildkite.organization(::Organization)` — get.

### Pipelines

- `Buildkite.pipelines(org)` — list.
- `Buildkite.pipeline(org, slug)` / `Buildkite.pipeline(org, ::Pipeline)` /
  `Buildkite.pipeline(::Pipeline)` — get.

### Builds

- `Buildkite.builds()` / `Buildkite.builds(org)` /
  `Buildkite.builds(org, pipeline)` — list, at three scopes.
- `Buildkite.build(org, pipeline, number)` — get by pipeline-scoped number.

### Artifacts

- `Buildkite.artifacts(org, pipeline, build)` — list for a build (all jobs).
- `Buildkite.artifacts(org, pipeline, build, job)` / `Buildkite.artifacts(::Job)` —
  list for a specific job.
- `Buildkite.artifact(org, pipeline, build, job, ::Artifact)` /
  `Buildkite.artifact(::Artifact)` — get.

### Annotations and logs

- `Buildkite.annotations(org, pipeline, build)` — list build annotations.
- `Buildkite.job_log(::Job)` / `Buildkite.job_log(org, pipeline, build, job)` —
  fetch a job's log output as a `Buildkite.Log`.

### Clusters, queues, agents

- `Buildkite.clusters(org)` — list clusters.
- `Buildkite.cluster(org, id::UUID)` / `Buildkite.cluster(org, name::AbstractString)` /
  `Buildkite.cluster(org, ::Cluster)` / `Buildkite.cluster(::Cluster)` — get.
  Lookup by name paginates through `clusters(org)` locally.
- `Buildkite.cluster_queues(org, cluster)` / `Buildkite.cluster_queues(::Cluster)` —
  list queues.
- `Buildkite.cluster_queue(org, cluster, id::UUID)` /
  `Buildkite.cluster_queue(org, cluster, key::AbstractString)` /
  `Buildkite.cluster_queue(org, cluster, ::ClusterQueue)` /
  `Buildkite.cluster_queue(::ClusterQueue)` — get.
- `Buildkite.agents(org)` — list agents. Filter with query params like `name`,
  `hostname`, `version`, `cluster`, `queue`.
- `Buildkite.agent(org, id::UUID)` / `Buildkite.agent(org, ::Agent)` /
  `Buildkite.agent(::Agent)` — get.

## Object model

Every response is unmarshalled into a struct. All fields are `Union{T, Nothing}` so
missing/null values are represented uniformly. Types currently defined:

`Organization`, `User`, `Pipeline`, `PullRequest`, `Build`, `Job`, `Artifact`,
`Annotation`, `Log`, `Cluster`, `ClusterQueue`, `Agent`, `AccessToken`.

## Example

```julia
using Buildkite

org = Buildkite.organizations() |> first
pipeline = Buildkite.pipeline(org, "julia-master")

for build in Buildkite.builds(org, pipeline; query = Dict("per_page" => "10"), page_limit = 3)
    println("#", build.number, " ", build.state, " ", build.branch)
    for job in something(build.jobs, ())
        job.state == "failed" || continue
        log = Buildkite.job_log(job)
        @info "failed job" build = build.number label = job.label bytes = log.size
    end
end
```

## Status

Read-only endpoints only. Writes (create/update/delete builds, retry jobs, cancel,
create annotations, agent tokens, etc.) are not implemented.
