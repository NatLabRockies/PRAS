@testset "EnergyResult" begin

    N = DD.nperiods
    r, r_idx, r_bad = DD.testresource, DD.testresource_idx, DD.notaresource
    t, t_idx, t_bad = DD.testperiod, DD.testperiod_idx, DD.notaperiod

    # Storages

    result = PRASCore.Results.StorageEnergyResult{N,1,Hour,MWh}(
        DD.nsamples, DD.resourcenames, DD.periods,
        DD.d1_resourceperiod, DD.d2_period, DD.d2_resourceperiod)

    @test result[t] ≈ (sum(DD.d1_resourceperiod[:, t_idx]), DD.d2_period[t_idx])
    @test result[r, t] ≈
              (DD.d1_resourceperiod[r_idx, t_idx], DD.d2_resourceperiod[r_idx, t_idx])

    @test_throws BoundsError result[t_bad]
    @test_throws BoundsError result[r, t_bad]
    @test_throws BoundsError result[r_bad, t]
    @test_throws BoundsError result[r_bad, t_bad]

    # GeneratorStorages

    result = PRASCore.Results.GeneratorStorageEnergyResult{N,1,Hour,MWh}(
        DD.nsamples, DD.resourcenames, DD.periods,
        DD.d1_resourceperiod, DD.d2_period, DD.d2_resourceperiod)

    @test result[t] ≈ (sum(DD.d1_resourceperiod[:, t_idx]), DD.d2_period[t_idx])
    @test result[r, t] ≈
              (DD.d1_resourceperiod[r_idx, t_idx], DD.d2_resourceperiod[r_idx, t_idx])

    @test_throws BoundsError result[t_bad]
    @test_throws BoundsError result[r, t_bad]
    @test_throws BoundsError result[r_bad, t]
    @test_throws BoundsError result[r_bad, t_bad]

    # DemandResponses

    result = PRASCore.Results.DemandResponseEnergyResult{N,1,Hour,MWh}(
        DD.nsamples, DD.resourcenames, DD.periods,
        DD.d1_resourceperiod, DD.d2_period, DD.d2_resourceperiod)

    @test result[t] ≈ (sum(DD.d1_resourceperiod[:, t_idx]), DD.d2_period[t_idx])
    @test result[r, t] ≈
              (DD.d1_resourceperiod[r_idx, t_idx], DD.d2_resourceperiod[r_idx, t_idx])

    @test_throws BoundsError result[t_bad]
    @test_throws BoundsError result[r, t_bad]
    @test_throws BoundsError result[r_bad, t]
    @test_throws BoundsError result[r_bad, t_bad]


end

@testset "EnergySamplesResult" begin

    N = DD.nperiods
    r, r_idx, r_bad = DD.testresource, DD.testresource_idx, DD.notaresource
    t, t_idx, t_bad = DD.testperiod, DD.testperiod_idx, DD.notaperiod

    # Storages

    result = PRASCore.Results.StorageEnergySamplesResult{N,1,Hour,MWh}(
        DD.resourcenames, DD.periods, DD.d)

    @test length(result[t]) == DD.nsamples
    @test result[t] ≈ vec(sum(view(DD.d, :, t_idx, :), dims=1))

    @test length(result[r, t]) == DD.nsamples
    @test result[r, t] ≈ vec(DD.d[r_idx, t_idx, :])

    @test_throws BoundsError result[t_bad]
    @test_throws BoundsError result[r, t_bad]
    @test_throws BoundsError result[r_bad, t]
    @test_throws BoundsError result[r_bad, t_bad]

    # GeneratorStorages

    result = PRASCore.Results.GeneratorStorageEnergySamplesResult{N,1,Hour,MWh}(
        DD.resourcenames, DD.periods, DD.d)

    @test length(result[t]) == DD.nsamples
    @test result[t] ≈ vec(sum(view(DD.d, :, t_idx, :), dims=1))

    @test length(result[r, t]) == DD.nsamples
    @test result[r, t] ≈ vec(DD.d[r_idx, t_idx, :])

    @test_throws BoundsError result[t_bad]
    @test_throws BoundsError result[r, t_bad]
    @test_throws BoundsError result[r_bad, t]
    @test_throws BoundsError result[r_bad, t_bad]

    # DemandResponses

    result = PRASCore.Results.DemandResponseEnergySamplesResult{N,1,Hour,MWh}(
        DD.resourcenames, DD.periods, DD.d)

    @test length(result[t]) == DD.nsamples
    @test result[t] ≈ vec(sum(view(DD.d, :, t_idx, :), dims=1))

    @test length(result[r, t]) == DD.nsamples
    @test result[r, t] ≈ vec(DD.d[r_idx, t_idx, :])

    @test_throws BoundsError result[t_bad]
    @test_throws BoundsError result[r, t_bad]
    @test_throws BoundsError result[r_bad, t]
    @test_throws BoundsError result[r_bad, t_bad]

end
