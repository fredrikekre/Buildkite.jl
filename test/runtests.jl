using Buildkite
using Test
using Dates: DateTime
using Base: UUID

if !haskey(ENV, "BUILDKITE_TOKEN")
    error("BUILDKITE_TOKEN must be set in the environment to run the test suite")
end

# Tests walk the API starting from the token: user → organizations → pipelines/clusters/
# agents → builds → artifacts/annotations. Nothing about the accessible org, pipeline
# names, cluster names, etc. is hardcoded; if a resource is unavailable the sub-testset
# is skipped rather than failing.

const SMALL_PAGE = Dict("per_page" => "3")

@testset "Buildkite.jl" begin
    @testset "Object constructors and paths" begin
        org = Buildkite.Organization(slug = "example-org")
        @test org.slug == "example-org"
        @test Buildkite.Internals.path(org) == "/organizations/example-org"

        pipeline = Buildkite.Pipeline(slug = "example")
        @test Buildkite.Internals.path(pipeline) == "/pipelines/example"

        build = Buildkite.Build(number = 42)
        @test Buildkite.Internals.path(build) == "/builds/42"

        uuid = UUID("00000000-0000-0000-0000-000000000001")
        @test Buildkite.Internals.path(Buildkite.Cluster(id = uuid)) == "/clusters/$(uuid)"
        @test Buildkite.Internals.path(Buildkite.ClusterQueue(id = uuid)) == "/queues/$(uuid)"
        @test Buildkite.Internals.path(Buildkite.Agent(id = uuid)) == "/agents/$(uuid)"
        @test Buildkite.Internals.path(Buildkite.Job(id = uuid)) == "/jobs/$(uuid)"
        @test Buildkite.Internals.path(Buildkite.Artifact(id = uuid)) == "/artifacts/$(uuid)"
    end

    @testset "rate_limits" begin
        rl = Buildkite.rate_limits()
        @test rl isa Buildkite.RateLimit
        @test rl.limit > 0
        @test 0 <= rl.remaining <= rl.limit
        @test rl.reset >= 0
        @test rl.request_time isa DateTime
    end

    @testset "access_token" begin
        tok = Buildkite.access_token()
        @test tok isa Buildkite.AccessToken
        @test tok.uuid isa UUID
        @test tok.scopes isa Vector{String}
        @test !isempty(tok.scopes)
    end

    @testset "user" begin
        u = Buildkite.user()
        @test u isa Buildkite.User
        @test u.id isa UUID
        @test u.name isa String
    end

    orgs = collect(Buildkite.organizations())
    @testset "organizations" begin
        @test !isempty(orgs)
        @test all(o -> o isa Buildkite.Organization, orgs)
        @test all(o -> o.slug isa String, orgs)

        # Round-trip: fetch first org by slug.
        first_org = orgs[1]
        got = Buildkite.organization(first_org.slug)
        @test got.id == first_org.id
        @test got.slug == first_org.slug
    end

    if !isempty(orgs)
        org = orgs[1]

        # Walk one pipeline deep and one build deep.
        pipeline = nothing
        build = nothing
        @testset "pipelines" begin
            pipes = collect(Buildkite.pipelines(org; query = SMALL_PAGE, page_limit = 1))
            @test all(p -> p isa Buildkite.Pipeline, pipes)
            if !isempty(pipes)
                pipeline = pipes[1]
                @test pipeline.slug isa String
                got = Buildkite.pipeline(org, pipeline.slug)
                @test got.id == pipeline.id
            end
        end

        if pipeline !== nothing
            @testset "pipeline url shortcut" begin
                got = Buildkite.pipeline(pipeline)
                @test got.id == pipeline.id
            end
            @testset "builds" begin
                bs = collect(
                    Buildkite.builds(org, pipeline; query = SMALL_PAGE, page_limit = 1),
                )
                @test all(b -> b isa Buildkite.Build, bs)
                if !isempty(bs)
                    build = bs[1]
                    @test build.number isa Int
                    got = Buildkite.build(org, pipeline, build.number)
                    @test got.id == build.id
                end
            end
        end

        if build !== nothing
            @testset "artifacts (build)" begin
                arts = collect(Buildkite.artifacts(org, pipeline, build))
                @test arts isa Vector{Buildkite.Artifact}
                if !isempty(arts)
                    a = arts[1]
                    @test a.id isa UUID
                    job = Buildkite.Job(id = a.job_id)
                    got = Buildkite.artifact(org, pipeline, build, job, a)
                    @test got.id == a.id
                    @test Buildkite.artifact(a).id == a.id  # url-based shortcut
                end
            end

            @testset "artifacts (job)" begin
                idx = build.jobs === nothing ? nothing :
                    findfirst(j -> j.id !== nothing, build.jobs)
                if idx !== nothing
                    job = build.jobs[idx]
                    arts_chain = collect(Buildkite.artifacts(org, pipeline, build, job))
                    arts_url = collect(Buildkite.artifacts(job))  # url-based shortcut
                    @test length(arts_chain) == length(arts_url)
                end
            end

            @testset "job_log" begin
                # Pick the first completed job so the log endpoint has something to return.
                idx = build.jobs === nothing ? nothing :
                    findfirst(
                        j -> j.id !== nothing && j.state in ("passed", "failed"),
                        build.jobs,
                    )
                if idx !== nothing
                    job = build.jobs[idx]
                    log = Buildkite.job_log(job)
                    @test log isa Buildkite.Log
                    @test log.size isa Int
                    @test log.content isa String
                    @test sizeof(log.content) == log.size
                    # Chain form returns the same log
                    log2 = Buildkite.job_log(org, pipeline, build, job)
                    @test log2.size == log.size
                end
            end

            @testset "annotations" begin
                anns = collect(Buildkite.annotations(org, pipeline, build))
                @test anns isa Vector{Buildkite.Annotation}
            end
        end

        @testset "clusters and queues" begin
            cs = collect(Buildkite.clusters(org))
            @test all(c -> c isa Buildkite.Cluster, cs)
            if !isempty(cs)
                c = cs[1]
                @test c.id isa UUID
                @test c.name isa String
                @test Buildkite.cluster(org, c.id).id == c.id
                @test Buildkite.cluster(org, c.name).id == c.id
                @test Buildkite.cluster(c).id == c.id  # url-based shortcut
                @test Buildkite.cluster(org, "__does-not-exist__") === nothing

                queues_chain = collect(Buildkite.cluster_queues(org, c))
                queues_url = collect(Buildkite.cluster_queues(c))  # url-based shortcut
                @test length(queues_chain) == length(queues_url)
                @test all(q -> q isa Buildkite.ClusterQueue, queues_chain)
                if !isempty(queues_chain)
                    q = queues_chain[1]
                    @test Buildkite.cluster_queue(org, c, q.id).id == q.id
                    @test Buildkite.cluster_queue(org, c, q.key).id == q.id
                    @test Buildkite.cluster_queue(q).id == q.id  # url-based shortcut
                end
            end
        end

        @testset "agents" begin
            for a in Buildkite.agents(org; query = SMALL_PAGE, page_limit = 1)
                @test a isa Buildkite.Agent
                @test a.id isa UUID
                @test Buildkite.agent(org, a.id).id == a.id
                @test Buildkite.agent(a).id == a.id  # url-based shortcut
                break
            end
        end
    end
end
