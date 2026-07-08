#######################
## Buildkite Objects ##
#######################
abstract type BuildkiteObject end

# Generic JSON object from the parser. With JSON.jl this is just Dict{String, Any}.
# TODO: Make this a proper struct that can subtype BuildkiteObject?
const JSONObject = Dict{String, Any}

# General constructors from dicts and kwargs...
(::Type{B})(dict::AbstractDict) where {B <: BuildkiteObject} = Internals.unmarshal(B, dict)
(::Type{B})(; kwargs...) where {B <: BuildkiteObject} = Internals.unmarshal(B, kwargs)

function Base.show(io::IO, o::BuildkiteObject)
    return if get(io, :compact, false)
        print(io, typeof(o), "(…)")
    else
        print(io, "$(typeof(o)) (all fields are Union{T,Nothing}):")
        for field in fieldnames(typeof(o))
            val = getfield(o, field)
            if !(val === nothing)
                println(io)
                print(io, "  $field: ")
                if isa(val, Vector)
                    print(io, typeof(val))
                else
                    show(IOContext(io, :compact => true), val)
                end
            end
        end
    end
end

###############
## Unmarshal ##
###############
function Internals.unmarshal(::Type{B}, data::AbstractDict{T}) where {B <: BuildkiteObject, T}
    # Make sure the struct does not miss any fields
    for k in keys(data)
        if !(Symbol(k) ∈ fieldnames(B))
            @error "key `$(k)` missing from `$(B)` struct definition" value = data[k]
        end
    end
    function unmarshal_or_nothing(x)
        v = get(data, T(x), nothing)
        v === nothing && return nothing
        S = fieldtype(B, x)
        if S === Nothing
            msg = "error unmarshalling field for type $(B): unmarshal($x::Nothing, v::$(typeof(v)))"
            @error msg v
            error(msg)
        end
        return Internals.unmarshal(S, v)
    end
    return B((unmarshal_or_nothing(x) for x in fieldnames(B))...)
end

# All field types are Union{X, Nothing} so we can strip the Nothing.
function Internals.unmarshal(::Type{Union{T, Nothing}}, val) where {T}
    @assert @isdefined T
    return Internals.unmarshal(T, val)
end

# Native JSON types don't need to be converted.
const JSONTypes = Union{JSONObject, Int, Bool, String}
Internals.unmarshal(::Type{T}, val::T) where {T <: JSONTypes} = val

# JSON 1.x parses objects as JSON.Object{String, Any}. Coerce into the concrete
# JSONObject (Dict{String, Any}) that BuildkiteObject fields store.
Internals.unmarshal(::Type{JSONObject}, val::AbstractDict) = JSONObject(val)

# These types can be constructed directly from their string representation
Internals.unmarshal(::Type{T}, val::AbstractString) where {T <: Union{UUID, URI, VersionNumber}} = T(val)

# ...and passthrough when already parsed (e.g. when a user constructs a struct via kwargs).
Internals.unmarshal(::Type{T}, val::T) where {T <: Union{UUID, URI, VersionNumber, DateTime}} = val

# All times are in UTC with varying date format...
function Internals.unmarshal(::Type{DateTime}, val)
    return @something(
        Dates.tryparse(DateTime, val, BUILDKITE_DATE_FORMAT_MS),
        Dates.tryparse(DateTime, val, BUILDKITE_DATE_FORMAT)
    )
end

function Internals.unmarshal(::Type{B}, val) where {B <: BuildkiteObject}
    error("unreachable")
    return B(val)
end

function Internals.unmarshal(::Type{Vector{B}}, val) where {B <: BuildkiteObject}
    return map(v -> Internals.unmarshal(B, v), val)::Vector{B}
    # return map(v -> (Internals.unmarshal(B, v); error()), val)::Vector{B}
end

# TODO: Tighten the struct field type here.
function Internals.unmarshal(::Type{Vector{Any}}, val::AbstractVector)
    return collect(Any, val)
end
function Internals.unmarshal(::Type{Vector{T}}, val::AbstractVector) where {T <: JSONTypes}
    return map(x -> Internals.unmarshal(T, x)::T, val)
end


########################
## Struct definitions ##
########################

struct Organization <: BuildkiteObject
    slug::Union{String, Nothing}
end
Internals.slug(x::Organization) = x.slug::String
Internals.path(x::Organization) = "/organizations/$(Internals.slug(x))"

struct User <: BuildkiteObject
    avatar_url::Union{URI, Nothing}
    created_at::Union{DateTime, Nothing}
    email::Union{String, Nothing}
    graphql_id::Union{String, Nothing}
    id::Union{UUID, Nothing}
    name::Union{String, Nothing}
    username::Union{String, Nothing}
end

struct Cluster <: BuildkiteObject
    color::Union{String, Nothing}
    created_at::Union{DateTime, Nothing}
    created_by::Union{User, Nothing}
    default_queue_id::Union{UUID, Nothing}
    default_queue_url::Union{URI, Nothing}
    description::Union{String, Nothing}
    emoji::Union{String, Nothing}
    graphql_id::Union{String, Nothing}
    id::Union{UUID, Nothing}
    maintainers::Union{JSONObject, Nothing}
    maintainers_url::Union{URI, Nothing}
    name::Union{String, Nothing}
    queues_url::Union{URI, Nothing}
    url::Union{URI, Nothing}
    web_url::Union{URI, Nothing}
end
Internals.path(x::Cluster) = "/clusters/$(x.id::UUID)"

struct ClusterQueue <: BuildkiteObject
    cluster_url::Union{URI, Nothing}
    created_at::Union{DateTime, Nothing}
    created_by::Union{User, Nothing}
    description::Union{String, Nothing}
    dispatch_paused::Union{Bool, Nothing}
    dispatch_paused_at::Union{DateTime, Nothing}
    dispatch_paused_by::Union{User, Nothing}
    dispatch_paused_note::Union{String, Nothing}
    graphql_id::Union{String, Nothing}
    hosted::Union{Bool, Nothing}
    hosted_agents::Union{JSONObject, Nothing}
    id::Union{UUID, Nothing}
    key::Union{String, Nothing}
    retry_agent_affinity::Union{String, Nothing}
    url::Union{URI, Nothing}
    web_url::Union{URI, Nothing}
end
Internals.path(x::ClusterQueue) = "/queues/$(x.id::UUID)"

struct Pipeline <: BuildkiteObject
    allow_rebuilds::Union{Bool, Nothing}
    archived_at::Union{DateTime, Nothing}
    badge_url::Union{URI, Nothing}
    branch_configuration::Union{String, Nothing}
    builds_url::Union{URI, Nothing}
    cancel_running_branch_builds::Union{Bool, Nothing}
    cancel_running_branch_builds_filter::Union{String, Nothing}
    cluster_id::Union{UUID, Nothing}
    cluster_url::Union{URI, Nothing}
    color::Union{String, Nothing}
    configuration::Union{String, Nothing}
    created_at::Union{DateTime, Nothing}
    created_by::Union{User, Nothing}
    default_branch::Union{String, Nothing}
    description::Union{String, Nothing}
    emoji::Union{String, Nothing}
    env::Union{JSONObject, Nothing}
    graphql_id::Union{String, Nothing}
    id::Union{UUID, Nothing}
    name::Union{String, Nothing}
    pipeline_template_uuid::Union{UUID, Nothing}
    provider::Union{JSONObject, Nothing} # TODO: JSONObject -> Provider
    repository::Union{URI, Nothing}
    running_builds_count::Union{Int, Nothing}
    running_jobs_count::Union{Int, Nothing}
    scheduled_builds_count::Union{Int, Nothing}
    scheduled_jobs_count::Union{Int, Nothing}
    skip_queued_branch_builds::Union{Bool, Nothing}
    skip_queued_branch_builds_filter::Union{String, Nothing}
    slug::Union{String, Nothing}
    steps::Union{Vector{Any}, Nothing}
    tags::Union{Vector{String}, Nothing}
    url::Union{URI, Nothing}
    visibility::Union{String, Nothing}
    waiting_jobs_count::Union{Int, Nothing}
    web_url::Union{URI, Nothing}
end
Internals.slug(x::Pipeline) = x.slug::String
Internals.path(x::Pipeline) = "/pipelines/$(Internals.slug(x))"

struct PullRequest <: BuildkiteObject
    base::Union{String, Nothing}
    id::Union{String, Nothing}
    labels::Union{Vector{String}, Nothing}
    repository::Union{URI, Nothing}
end

struct Agent <: BuildkiteObject
    arch::Union{String, Nothing}
    cluster_queue_url::Union{URI, Nothing}
    cluster_url::Union{URI, Nothing}
    connected_at::Union{DateTime, Nothing}
    connection_state::Union{String, Nothing}
    created_at::Union{DateTime, Nothing}
    creator::Union{User, Nothing}
    disconnected_at::Union{DateTime, Nothing}
    hostname::Union{String, Nothing}
    id::Union{UUID, Nothing}
    ip_address::Union{String, Nothing}
    job::Union{JSONObject, Nothing}
    last_job_finished_at::Union{DateTime, Nothing}
    lost_at::Union{DateTime, Nothing}
    meta_data::Union{Vector{String}, Nothing}
    name::Union{String, Nothing}
    os_id::Union{String, Nothing}
    paused::Union{Bool, Nothing}
    paused_at::Union{DateTime, Nothing}
    paused_by::Union{User, Nothing}
    paused_note::Union{String, Nothing}
    paused_timeout_in_minutes::Union{Int, Nothing}
    priority::Union{Int, Nothing}
    queue::Union{String, Nothing}
    stopped_at::Union{DateTime, Nothing}
    url::Union{URI, Nothing}
    user_agent::Union{String, Nothing}
    version::Union{VersionNumber, Nothing}
    web_url::Union{URI, Nothing}
end

struct Job <: BuildkiteObject
    agent::Union{Agent, Nothing}
    agent_query_rules::Union{Vector{String}, Nothing}
    artifact_paths::Union{String, Nothing}
    artifacts_url::Union{URI, Nothing}
    build_url::Union{URI, Nothing}
    cluster_id::Union{UUID, Nothing}
    cluster_queue_id::Union{UUID, Nothing}
    cluster_queue_url::Union{URI, Nothing}
    cluster_url::Union{URI, Nothing}
    command::Union{String, Nothing}
    created_at::Union{DateTime, Nothing}
    exit_status::Union{Int, Nothing}
    expired_at::Union{DateTime, Nothing}
    finished_at::Union{DateTime, Nothing}
    graphql_id::Union{String, Nothing}
    group_key::Union{String, Nothing}
    id::Union{UUID, Nothing}
    label::Union{String, Nothing}
    log_url::Union{URI, Nothing}
    matrix::Union{JSONObject, Nothing}
    name::Union{String, Nothing}
    parallel_group_index::Union{Int, Nothing}
    parallel_group_total::Union{Int, Nothing}
    priority::Union{JSONObject, Nothing} # TODO: Proper Priority type
    raw_log_url::Union{URI, Nothing}
    retried::Union{Bool, Nothing}
    retried_by::Union{User, Nothing}
    retried_in_job_id::Union{UUID, Nothing}
    retries_count::Union{Int, Nothing}
    retry_source::Union{JSONObject, Nothing}
    retry_type::Union{String, Nothing}
    runnable_at::Union{DateTime, Nothing}
    scheduled_at::Union{DateTime, Nothing}
    signal::Union{String, Nothing}
    signal_reason::Union{String, Nothing}
    soft_failed::Union{Bool, Nothing}
    started_at::Union{DateTime, Nothing}
    state::Union{String, Nothing}
    step::Union{JSONObject, Nothing} # TODO: Proper Step type
    step_key::Union{String, Nothing}
    type::Union{String, Nothing}
    unblock_url::Union{URI, Nothing}
    unblockable::Union{Bool, Nothing}
    unblocked_at::Union{DateTime, Nothing}
    unblocked_by::Union{User, Nothing}
    web_url::Union{URI, Nothing}
end

struct Build <: BuildkiteObject
    author::Union{User, Nothing}
    blocked::Union{Bool, Nothing}
    blocked_state::Union{String, Nothing}
    branch::Union{String, Nothing}
    cancel_reason::Union{String, Nothing}
    cluster_id::Union{UUID, Nothing}
    cluster_url::Union{URI, Nothing}
    commit::Union{String, Nothing}
    created_at::Union{DateTime, Nothing}
    creator::Union{User, Nothing}
    env::Union{JSONObject, Nothing} # TODO: Proper type
    failing_at::Union{DateTime, Nothing}
    finished_at::Union{DateTime, Nothing}
    graphql_id::Union{String, Nothing}
    id::Union{UUID, Nothing}
    jobs::Union{Vector{Job}, Nothing}
    message::Union{String, Nothing}
    meta_data::Union{JSONObject, Nothing} # TODO: Proper type?
    number::Union{Int, Nothing}
    pipeline::Union{Pipeline, Nothing}
    pull_request::Union{PullRequest, Nothing}
    rebuilt_from::Union{JSONObject, Nothing} # TODO: Proper type?
    scheduled_at::Union{DateTime, Nothing}
    source::Union{String, Nothing}
    started_at::Union{DateTime, Nothing}
    state::Union{String, Nothing}
    tag::Union{VersionNumber, Nothing}
    url::Union{URI, Nothing}
    web_url::Union{URI, Nothing}
end

struct AccessToken <: BuildkiteObject
    created_at::Union{DateTime, Nothing}
    description::Union{String, Nothing}
    expires_at::Union{DateTime, Nothing}
    scopes::Union{Vector{String}, Nothing}
    user::Union{User, Nothing}
    uuid::Union{UUID, Nothing}
end
