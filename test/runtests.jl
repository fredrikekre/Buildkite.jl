using Buildkite
using Test
using Dates: DateTime
using Base: UUID

if !haskey(ENV, "BUILDKITE_TOKEN")
    error("BUILDKITE_TOKEN must be set in the environment to run the test suite")
end

@testset "Buildkite.jl" begin
    @testset "Object constructors" begin
        org = Buildkite.Organization(slug = "julialang")
        @test org.slug == "julialang"
        @test Buildkite.Internals.path(org) == "/organizations/julialang"

        pipeline = Buildkite.Pipeline(slug = "julia-master")
        @test pipeline.slug == "julia-master"
        @test Buildkite.Internals.path(pipeline) == "/pipelines/julia-master"
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
end
