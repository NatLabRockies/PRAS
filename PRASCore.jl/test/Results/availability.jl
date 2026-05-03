@testset "AvailabilityResult" begin

    N = DD.nperiods
    r, r_idx, r_bad = DD.testresource, DD.testresource_idx, DD.notaresource
    t, t_idx, t_bad = DD.testperiod, DD.testperiod_idx, DD.notaperiod
    available = rand(Bool, DD.nresources, N,  DD.nsamples)

    # Generators

    result = PRASCore.Results.GeneratorAvailabilityResult{N,1,Hour}(
        DD.resourcenames, DD.periods, available)

    @test length(result[r, t]) == DD.nsamples
    @test result[r, t] ≈ vec(available[r_idx, t_idx, :])

    @test_throws BoundsError result[r, t_bad]
    @test_throws BoundsError result[r_bad, t]
    @test_throws BoundsError result[r_bad, t_bad]

    # Storages

    result = PRASCore.Results.StorageAvailabilityResult{N,1,Hour}(
        DD.resourcenames, DD.periods, available)

    @test length(result[r, t]) == DD.nsamples
    @test result[r, t] ≈ vec(available[r_idx, t_idx, :])

    @test_throws BoundsError result[r, t_bad]
    @test_throws BoundsError result[r_bad, t]
    @test_throws BoundsError result[r_bad, t_bad]

    # GeneratorStorages

    result = PRASCore.Results.GeneratorStorageAvailabilityResult{N,1,Hour}(
        DD.resourcenames, DD.periods, available)

    @test length(result[r, t]) == DD.nsamples
    @test result[r, t] ≈ vec(available[r_idx, t_idx, :])

    @test_throws BoundsError result[r, t_bad]
    @test_throws BoundsError result[r_bad, t]
    @test_throws BoundsError result[r_bad, t_bad]

    # DemandResponses

    result = PRASCore.Results.DemandResponseAvailabilityResult{N,1,Hour}(
        DD.resourcenames, DD.periods, available)

    @test length(result[r, t]) == DD.nsamples
    @test result[r, t] ≈ vec(available[r_idx, t_idx, :])

    @test_throws BoundsError result[r, t_bad]
    @test_throws BoundsError result[r_bad, t]
    @test_throws BoundsError result[r_bad, t_bad]


    # Lines

    result = PRASCore.Results.LineAvailabilityResult{N,1,Hour}(
        DD.resourcenames, DD.periods, available)

    @test length(result[r, t]) == DD.nsamples
    @test result[r, t] ≈ vec(available[r_idx, t_idx, :])

    @test_throws BoundsError result[r, t_bad]
    @test_throws BoundsError result[r_bad, t]
    @test_throws BoundsError result[r_bad, t_bad]

end
