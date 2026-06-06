@testset "ShortfallResult" begin

    
    N = DD.nperiods
    r, r_idx, r_bad = DD.testresource, DD.testresource_idx, DD.notaresource
    t, t_idx, t_bad = DD.testperiod, DD.testperiod_idx, DD.notaperiod
    alpha = DD.alpha

    result = PRASCore.Results.ShortfallResult{N,1,Hour,MWh,Shortfall}(
        DD.nsamples, Regions{N,MW}(DD.resourcenames, DD.resource_vals),
        DD.periods, DD.d1, DD.d2, DD.d1_resource, DD.d2_resource,
        DD.d1_period, DD.d2_period, DD.d1_resourceperiod,
        DD.d2_resourceperiod, DD.d3_resourceperiod, DD.d4,
        DD.d4_resource, DD.d4_period, DD.d4_resourceperiod,
        DD.d1_sample, DD.d1_resourcesample)

    # Overall

    @test result[] ≈ (sum(DD.d3_resourceperiod), DD.d4)

    lole = LOLE(result)
    @test val(lole) ≈ DD.d1
    @test stderror(lole) ≈ DD.d2 / sqrt(DD.nsamples)

    eue = EUE(result)
    @test val(eue) ≈ first(result[])
    @test stderror(eue) ≈ last(result[]) / sqrt(DD.nsamples)

    neue = NEUE(result)
    load = sum(DD.resource_vals)
    @test val(neue) ≈ first(result[]) / load*1e6
    @test stderror(neue) ≈ last(result[]) / sqrt(DD.nsamples) / load*1e6

    cvar = CVAR(:energy, result, alpha)
    estimate = result.shortfall_samples;
    tail_losses = estimate[estimate .> quantile(estimate, alpha)];
    @test val(cvar) ≈ mean(tail_losses)
    @test stderror(cvar) ≈ std(tail_losses) / sqrt(length(tail_losses))

    ncvar = NCVAR(result, cvar)
    @test val(ncvar) ≈ val(cvar) / load*1e6
    @test stderror(ncvar) ≈ stderror(cvar) / load*1e6

    # Region-specific

    @test result[r] ≈ (sum(DD.d3_resourceperiod[r_idx,:]), DD.d4_resource[r_idx])

    region_lole = LOLE(result, r)
    @test val(region_lole) ≈ DD.d1_resource[r_idx]
    @test stderror(region_lole) ≈ DD.d2_resource[r_idx] / sqrt(DD.nsamples)

    region_eue = EUE(result, r)
    @test val(region_eue) ≈ first(result[r])
    @test stderror(region_eue) ≈ last(result[r]) / sqrt(DD.nsamples)

    region_neue = NEUE(result, r)
    load = sum(DD.resource_vals[r_idx,:])
    @test val(region_neue) ≈ first(result[r]) / load*1e6
    @test stderror(region_neue) ≈ last(result[r]) / sqrt(DD.nsamples) / load*1e6

    region_cvar = CVAR(:energy, result, alpha, r)
    region_estimate = result.shortfall_region_samples[r_idx, :];
    region_tail_losses = region_estimate[region_estimate .>= quantile(region_estimate, alpha)];
    @test val(region_cvar) ≈ mean(region_tail_losses)
    @test stderror(region_cvar) ≈ std(region_tail_losses) / sqrt(length(region_tail_losses))

    region_ncvar = NCVAR(result, region_cvar, r)
    @test val(region_ncvar) ≈ val(region_cvar) / load*1e6
    @test stderror(region_ncvar) ≈ stderror(region_cvar) / load*1e6

    @test_throws BoundsError result[r_bad]
    @test_throws BoundsError LOLE(result, r_bad)
    @test_throws BoundsError EUE(result, r_bad)
    @test_throws BoundsError NEUE(result, r_bad)
    @test_throws BoundsError CVAR(:energy,result, alpha, r_bad)
    @test_throws BoundsError NCVAR(result, region_cvar, r_bad)
    @test_throws ArgumentError CVAR(:power, result, alpha)

    # Period-specific

    @test result[t] ≈ (sum(DD.d3_resourceperiod[:, t_idx]), DD.d4_period[t_idx])

    period_lole = LOLE(result, t)
    @test val(period_lole) ≈ DD.d1_period[t_idx]
    @test stderror(period_lole) ≈ DD.d2_period[t_idx] / sqrt(DD.nsamples)

    period_eue = EUE(result, t)
    @test val(period_eue) ≈ first(result[t])
    @test stderror(period_eue) ≈ last(result[t]) / sqrt(DD.nsamples)

    @test_throws ArgumentError CVAR(:energy, result, alpha, DD.periods)

    @test_throws BoundsError result[t_bad]
    @test_throws BoundsError LOLE(result, t_bad)
    @test_throws BoundsError EUE(result, t_bad)

    # Region + period-specific

    @test result[r, t] ≈
              (DD.d3_resourceperiod[r_idx, t_idx], DD.d4_resourceperiod[r_idx, t_idx])

    regionperiod_lole = LOLE(result, r, t)
    @test val(regionperiod_lole) ≈ DD.d1_resourceperiod[r_idx, t_idx]
    @test stderror(regionperiod_lole) ≈
        DD.d2_resourceperiod[r_idx, t_idx] / sqrt(DD.nsamples)

    regionperiod_eue = EUE(result, r, t)
    @test val(regionperiod_eue) ≈ first(result[r, t])
    @test stderror(regionperiod_eue) ≈ last(result[r, t]) / sqrt(DD.nsamples)

    @test_throws BoundsError result[r, t_bad]
    @test_throws BoundsError result[r_bad, t]
    @test_throws BoundsError result[r_bad, t_bad]

    @test_throws BoundsError LOLE(result, r, t_bad)
    @test_throws BoundsError LOLE(result, r_bad, t)
    @test_throws BoundsError LOLE(result, r_bad, t_bad)

    @test_throws BoundsError EUE(result, r, t_bad)
    @test_throws BoundsError EUE(result, r_bad, t)
    @test_throws BoundsError EUE(result, r_bad, t_bad)

end


@testset "ShortfallSamplesResult" begin

    N = DD.nperiods
    r, r_idx, r_bad = DD.testresource, DD.testresource_idx, DD.notaresource
    t, t_idx, t_bad, badperiods = DD.testperiod, DD.testperiod_idx, DD.notaperiod, DD.badperiods
    alpha = 0.95

    result = PRASCore.Results.ShortfallSamplesResult{N,1,Hour,MW,MWh,ShortfallSamples}(
        Regions{N,MW}(DD.resourcenames, DD.resource_vals), DD.periods, DD.d)

    # Overall

    @test length(result[]) == DD.nsamples
    @test result[] ≈ vec(sum(DD.d, dims=1:2))

    lole = LOLE(result)
    eventperiods = sum(sum(DD.d, dims=1) .> 0, dims=2)
    @test val(lole) ≈ mean(eventperiods)
    @test stderror(lole) ≈ std(eventperiods) / sqrt(DD.nsamples)

    eue = EUE(result)
    @test val(eue) ≈ mean(result[])
    @test stderror(eue) ≈ std(result[]) / sqrt(DD.nsamples)

    neue = NEUE(result)
    load = sum(DD.resource_vals)
    @test val(neue) ≈ mean(result[]) / load*1e6
    @test stderror(neue) ≈ std(result[]) / sqrt(DD.nsamples) / load*1e6

    ue_cvar = CVAR(:energy, result, alpha)
    estimate = result[];
    tail_losses = estimate[estimate .>= quantile(estimate, alpha)];
    @test val(ue_cvar) ≈ mean(tail_losses)
    @test stderror(ue_cvar) ≈ std(tail_losses) / sqrt(length(tail_losses))

    ncvar = NCVAR(result, ue_cvar)
    @test val(ncvar) ≈ val(ue_cvar) / load*1e6
    @test stderror(ncvar) ≈ stderror(ue_cvar) / load*1e6

    # Region-specific

    @test length(result[r]) == DD.nsamples
    @test result[r] ≈ vec(sum(view(DD.d, r_idx, :, :), dims=1))

    region_lole = LOLE(result, r)
    region_eventperiods = sum(view(DD.d, r_idx, :, :) .> 0, dims=1)
    @test val(region_lole) ≈ mean(region_eventperiods)
    @test stderror(region_lole) ≈ std(region_eventperiods) / sqrt(DD.nsamples)

    region_eue = EUE(result, r)
    @test val(region_eue) ≈ mean(result[r])
    @test stderror(region_eue) ≈ std(result[r]) / sqrt(DD.nsamples)

    region_neue = NEUE(result, r)
    load = sum(DD.resource_vals[r_idx,:])
    @test val(region_neue) ≈ mean(result[r]) / load*1e6
    @test stderror(region_neue) ≈ std(result[r]) / sqrt(DD.nsamples) / load*1e6

    region_ue_cvar = CVAR(:energy, result, alpha, r)
    region_estimate = result[r];
    region_tail_losses = region_estimate[region_estimate .>= quantile(region_estimate, alpha)];
    @test val(region_ue_cvar) ≈ mean(region_tail_losses)
    @test stderror(region_ue_cvar) ≈ std(region_tail_losses) / sqrt(length(region_tail_losses))

    region_ncvar = NCVAR(result, region_ue_cvar, r)
    @test val(region_ncvar) ≈ val(region_ue_cvar) / load*1e6
    @test stderror(region_ncvar) ≈ stderror(region_ue_cvar) / load*1e6

    @test_throws BoundsError result[r_bad]
    @test_throws BoundsError LOLE(result, r_bad)
    @test_throws BoundsError EUE(result, r_bad)
    @test_throws BoundsError NEUE(result, r_bad)
    @test_throws BoundsError CVAR(:energy, result, alpha, r_bad)
    @test_throws BoundsError NCVAR(result, region_ue_cvar, r_bad)

    # Period-specific

    @test length(result[t]) == DD.nsamples
    @test result[t] ≈ vec(sum(view(DD.d, :, t_idx, :), dims=1))

    period_lole = LOLE(result, t)
    period_eventperiods = result[t] .> 0
    @test val(period_lole) ≈ mean(period_eventperiods)
    @test stderror(period_lole) ≈ std(period_eventperiods) / sqrt(DD.nsamples)

    period_eue = EUE(result, t)
    @test val(period_eue) ≈ mean(result[t])
    @test stderror(period_eue) ≈ std(result[t]) / sqrt(DD.nsamples)

    period_cvar = CVAR(:energy, result, alpha, DD.periods)
    period_estimate = result[DD.periods];
    period_tail_losses = period_estimate[period_estimate .> quantile(period_estimate, alpha)];
    @test val(period_cvar) ≈ mean(period_tail_losses)
    @test stderror(period_cvar) ≈ std(period_tail_losses) / sqrt(length(period_tail_losses))

    @test_throws BoundsError result[t_bad]
    @test_throws BoundsError LOLE(result, t_bad)
    @test_throws BoundsError EUE(result, t_bad)
    @test_throws BoundsError CVAR(:energy, result, alpha, badperiods)

    # Region + period-specific

    @test length(result[r, t]) == DD.nsamples
    @test result[r, t] ≈ vec(DD.d[r_idx, t_idx, :])

    regionperiod_lole = LOLE(result, r, t)
    regionperiod_eventperiods = result[r, t] .>  0
    @test val(regionperiod_lole) ≈ mean(regionperiod_eventperiods)
    @test stderror(regionperiod_lole) ≈
        std(regionperiod_eventperiods) / sqrt(DD.nsamples)

    regionperiod_eue = EUE(result, r, t)
    @test val(regionperiod_eue) ≈ mean(result[r, t])
    @test stderror(regionperiod_eue) ≈ std(result[r, t]) / sqrt(DD.nsamples)

    regionperiod_cvar = CVAR(:energy, result, alpha, r, t)
    regionperiod_estimate = result[r, t];
    regionperiod_tail_losses = regionperiod_estimate[regionperiod_estimate .>= quantile(regionperiod_estimate, alpha)];
    @test val(regionperiod_cvar) ≈ mean(regionperiod_tail_losses)
    @test stderror(regionperiod_cvar) ≈ std(regionperiod_tail_losses) / sqrt(length(regionperiod_tail_losses))

    @test_throws BoundsError result[r, t_bad]
    @test_throws BoundsError result[r_bad, t]
    @test_throws BoundsError result[r_bad, t_bad]

    @test_throws BoundsError LOLE(result, r, t_bad)
    @test_throws BoundsError LOLE(result, r_bad, t)
    @test_throws BoundsError LOLE(result, r_bad, t_bad)

    @test_throws BoundsError EUE(result, r, t_bad)
    @test_throws BoundsError EUE(result, r_bad, t)
    @test_throws BoundsError EUE(result, r_bad, t_bad)

    @test_throws BoundsError CVAR(:energy, result, alpha, r, t_bad)
    @test_throws BoundsError CVAR(:energy, result, alpha, r_bad, t)
    @test_throws BoundsError CVAR(:energy, result, alpha, r_bad, t_bad)

end
