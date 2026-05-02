@testset verbose = true "Simulations" begin

    @testset "DispatchProblem" begin

    end

    nstderr_tol = 3

    simspec = SequentialMonteCarlo(samples=100_000, seed=1, threaded=false)
    smallsample = SequentialMonteCarlo(samples=10, seed=123, threaded=false)

    resultspecs = (Shortfall(), Surplus(), 
                   Flow(), Utilization(),
                   ShortfallSamples(), SurplusSamples(),
                   FlowSamples(), UtilizationSamples(),
                   GeneratorAvailability())

    timestamps_a = TestData.singlenode_a.timestamps
    timestamps_a5 = TestData.singlenode_a_5min.timestamps
    timestamps_b = TestData.singlenode_b.timestamps
    timestamps_3 = TestData.threenode.timestamps

    timestamprow_a = permutedims(timestamps_a)
    timestamprow_a5 = permutedims(timestamps_a5)
    timestamprow_b = permutedims(timestamps_b)
    timestamprow_3 = permutedims(timestamps_3)

    regionscol = TestData.threenode.regions.names

    assess(TestData.singlenode_a, smallsample, resultspecs...)
    shortfall_1a, _, flow_1a, util_1a,
    shortfall2_1a, _, flow2_1a, util2_1a, _ =
        assess(TestData.singlenode_a, simspec, resultspecs...)

    assess(TestData.singlenode_a_5min, smallsample, resultspecs...)
    shortfall_1a5, _, flow_1a5, util_1a5,
    shortfall2_1a5, _, flow2_1a5, util2_1a5, _ =
        assess(TestData.singlenode_a_5min, simspec, resultspecs...)

    assess(TestData.singlenode_b, smallsample, resultspecs...)
    shortfall_1b, _, flow_1b, util_1b,
    shortfall2_1b, _, flow2_1b, util2_1b, _ =
        assess(TestData.singlenode_b, simspec, resultspecs...)

    assess(TestData.threenode, smallsample, resultspecs...)
    shortfall_3, _, flow_3, util_3,
    shortfall2_3, _, flow2_3, util2_3, _ =
        assess(TestData.threenode, simspec, resultspecs...)

    assess(TestData.threenode, smallsample, DemandResponseShortfall(),
           GeneratorAvailability(), LineAvailability(),
           StorageAvailability(), GeneratorStorageAvailability(),DemandResponseAvailability(),
           StorageEnergy(), GeneratorStorageEnergy(),DemandResponseEnergy(),
           StorageEnergySamples(), GeneratorStorageEnergySamples(),DemandResponseEnergySamples())

    @testset "Shortfall Results" begin

        # Single-region system A

        @test LOLE(shortfall_1a) ≈ LOLE(shortfall2_1a)
        @test EUE(shortfall_1a) ≈ EUE(shortfall2_1a)
        @test LOLE(shortfall_1a, "Region") ≈ LOLE(shortfall2_1a, "Region")
        @test EUE(shortfall_1a, "Region") ≈ EUE(shortfall2_1a, "Region")

        @test withinrange(LOLE(shortfall_1a),
                          TestData.singlenode_a_lole, nstderr_tol)
        @test withinrange(EUE(shortfall_1a),
                          TestData.singlenode_a_eue, nstderr_tol)
        @test withinrange(LOLE(shortfall_1a, "Region"),
                          TestData.singlenode_a_lole, nstderr_tol)
        @test withinrange(EUE(shortfall_1a, "Region"),
                          TestData.singlenode_a_eue, nstderr_tol)

        @test all(LOLE.(shortfall_1a, timestamps_a) .≈
                  LOLE.(shortfall2_1a, timestamps_a))
        @test all(EUE.(shortfall_1a, timestamps_a) .≈
                  EUE.(shortfall2_1a, timestamps_a))
        @test all(LOLE(shortfall_1a, "Region", :) .≈
                  LOLE(shortfall2_1a, "Region", :))
        @test all(EUE(shortfall_1a, "Region", :) .≈
                  EUE(shortfall2_1a, "Region", :))

        @test all(withinrange.(LOLE.(shortfall_1a, timestamps_a),
                               TestData.singlenode_a_lolps, nstderr_tol))
        @test all(withinrange.(EUE.(shortfall_1a, timestamps_a),
                               TestData.singlenode_a_eues, nstderr_tol))
        @test all(withinrange.(LOLE(shortfall_1a, "Region", :),
                               TestData.singlenode_a_lolps, nstderr_tol))
        @test all(withinrange.(EUE(shortfall_1a, "Region", :),
                               TestData.singlenode_a_eues, nstderr_tol))

        # Single-region system A - 5 min version

        @test LOLE(shortfall_1a5) ≈ LOLE(shortfall2_1a5)
        @test EUE(shortfall_1a5) ≈ EUE(shortfall2_1a5)
        @test LOLE(shortfall_1a5, "Region") ≈ LOLE(shortfall2_1a5, "Region")
        @test EUE(shortfall_1a5, "Region") ≈ EUE(shortfall2_1a5, "Region")

        @test withinrange(LOLE(shortfall_1a5),
                          TestData.singlenode_a_lole, nstderr_tol)
        @test withinrange(EUE(shortfall_1a5),
                          TestData.singlenode_a_eue/12, nstderr_tol)
        @test withinrange(LOLE(shortfall_1a5, "Region"),
                          TestData.singlenode_a_lole, nstderr_tol)
        @test withinrange(EUE(shortfall_1a5, "Region"),
                          TestData.singlenode_a_eue/12, nstderr_tol)

        @test all(LOLE.(shortfall_1a5, timestamps_a5) .≈
                  LOLE.(shortfall2_1a5, timestamps_a5))
        @test all(EUE.(shortfall_1a5, timestamps_a5) .≈
                  EUE.(shortfall2_1a5, timestamps_a5))
        @test all(LOLE(shortfall_1a5, "Region", :) .≈
                  LOLE(shortfall2_1a5, "Region", :))
        @test all(EUE(shortfall_1a5, "Region", :) .≈
                  EUE(shortfall2_1a5, "Region", :))

        @test all(withinrange.(LOLE.(shortfall_1a5, timestamps_a5),
                               TestData.singlenode_a_lolps, nstderr_tol))
        @test all(withinrange.(EUE.(shortfall_1a5, timestamps_a5),
                               TestData.singlenode_a_eues ./ 12, nstderr_tol))
        @test all(withinrange.(LOLE(shortfall_1a5, "Region", :),
                               TestData.singlenode_a_lolps, nstderr_tol))
        @test all(withinrange.(EUE(shortfall_1a5, "Region", :),
                               TestData.singlenode_a_eues ./ 12, nstderr_tol))

        # Single-region system B

        @test LOLE(shortfall_1b) ≈ LOLE(shortfall2_1b)
        @test EUE(shortfall_1b) ≈ EUE(shortfall2_1b)
        @test LOLE(shortfall_1b, "Region") ≈ LOLE(shortfall2_1b, "Region")
        @test EUE(shortfall_1b, "Region") ≈ EUE(shortfall2_1b, "Region")

        @test withinrange(LOLE(shortfall_1b),
                          TestData.singlenode_b_lole, nstderr_tol)
        @test withinrange(EUE(shortfall_1b),
                          TestData.singlenode_b_eue, nstderr_tol)
        @test withinrange(LOLE(shortfall_1b, "Region"),
                          TestData.singlenode_b_lole, nstderr_tol)
        @test withinrange(EUE(shortfall_1b, "Region"),
                          TestData.singlenode_b_eue, nstderr_tol)

        @test all(LOLE.(shortfall_1b, timestamps_b) .≈
                  LOLE.(shortfall2_1b, timestamps_b))
        @test all(EUE.(shortfall_1b, timestamps_b) .≈
                  EUE.(shortfall2_1b, timestamps_b))
        @test all(LOLE(shortfall_1b, "Region", :) .≈
                  LOLE(shortfall2_1b, "Region", :))
        @test all(EUE(shortfall_1b, "Region", :) .≈
                  EUE(shortfall2_1b, "Region", :))

        @test all(withinrange.(LOLE.(shortfall_1b, timestamps_b),
                               TestData.singlenode_b_lolps, nstderr_tol))
        @test all(withinrange.(EUE.(shortfall_1b, timestamps_b),
                               TestData.singlenode_b_eues, nstderr_tol))
        @test all(withinrange.(LOLE(shortfall_1b, "Region", :),
                               TestData.singlenode_b_lolps, nstderr_tol))
        @test all(withinrange.(EUE(shortfall_1b, "Region", :),
                               TestData.singlenode_b_eues, nstderr_tol))

        # Three-region system

        @test LOLE(shortfall_3) ≈ LOLE(shortfall2_3)
        @test EUE(shortfall_3) ≈ EUE(shortfall2_3)
        @test all(LOLE.(shortfall_3, regionscol) .≈ LOLE.(shortfall2_3, regionscol))
        @test all(EUE.(shortfall_3, regionscol) .≈ EUE.(shortfall2_3, regionscol))

        @test withinrange(LOLE(shortfall_3),
                          TestData.threenode_lole, nstderr_tol)
        @test withinrange(EUE(shortfall_3),
                          TestData.threenode_eue, nstderr_tol)
        @test all(withinrange.(LOLE.(shortfall_3, timestamps_3),
                               TestData.threenode_lolps, nstderr_tol))
        @test all(withinrange.(EUE.(shortfall_3, timestamps_3),
                               TestData.threenode_eues, nstderr_tol))

        @test all(LOLE.(shortfall_3, timestamps_3) .≈
                  LOLE.(shortfall2_3, timestamps_3))
        @test all(EUE.(shortfall_3, timestamps_3) .≈
                  EUE.(shortfall2_3, timestamps_3))
        @test all(LOLE(shortfall_3, :, :) .≈ LOLE(shortfall2_3, :, :))
        @test all(EUE(shortfall_3, :, :) .≈ EUE(shortfall2_3, :, :))

        @test withinrange(
            LOLE(shortfall_3, "Region C", ZonedDateTime(2018,10,30,1,TestData.tz)),
            0.1, nstderr_tol)
        @test withinrange(
            LOLE(shortfall_3, "Region C", ZonedDateTime(2018,10,30,2,TestData.tz)),
            0.1, nstderr_tol)

        # TODO:  Test spatially-disaggregated results - may need to develop
        # test systems with unique network flow solutions

        println("SpatioTemporal LOLPs:")

        display(vcat(
            hcat("", timestamprow_3),
            hcat(regionscol, LOLE(shortfall_3, :, :))
        )); println()

        println("SpatioTemporal EUEs:")
        display(vcat(
            hcat("", timestamprow_3),
            hcat(regionscol, EUE(shortfall_3, :, :))
        )); println()

    end

    @testset "Flow and Utilization Results" begin

        # Single-region system A
        @test length(flow_1a.flow_mean) == 0
        @test length(util_1a.utilization_mean) == 0

        @test size(flow2_1a.flow, 1) == 0
        @test size(util2_1a.utilization, 1) == 0

        # Single-region system A (5 minute)
        @test length(flow_1a5.flow_mean) == 0
        @test length(util_1a5.utilization_mean) == 0

        @test size(flow2_1a5.flow, 1) == 0
        @test size(util2_1a5.utilization, 1) == 0

        # Single-region system B
        @test length(flow_1b.flow_mean) == 0
        @test length(util_1b.utilization_mean) == 0

        @test size(flow2_1b.flow, 1) == 0
        @test size(util2_1b.utilization, 1) == 0

        # Three-region system

        println("Network Flows:")
        display(vcat(
            hcat("", timestamprow_3),
            hcat(flow_3.interfaces, flow_3[:, :])
        )); println()

        @test all(flow_3[:] .≈ flow2_3[:])
        @test all(flow_3[:, :] .≈ flow2_3[:, :])

        println("Network Utilizations:")
        display(vcat(
            hcat("", timestamprow_3),
            hcat(flow_3.interfaces, util_3[:, :])
        )); println()

        @test all(util_3[:] .≈ util2_3[:])
        @test all(util_3[:, :] .≈ util2_3[:, :])

    end

    @testset "Test System 1: 2 Gens, 2 Regions" begin

        simspec = SequentialMonteCarlo(samples=1_000_000, seed=111)
        dt = first(TestData.test1.timestamps)
        regions = TestData.test1.regions.names

        shortfall, surplus, flow, utilization =
            assess(TestData.test1, simspec,
                   Shortfall(), Surplus(), Flow(), Utilization())

        # Shortfall - LOLE
        @test withinrange(LOLE(shortfall), TestData.test1_lole, nstderr_tol)
        @test withinrange(LOLE(shortfall, dt), TestData.test1_lole, nstderr_tol)
        @test all(withinrange.(LOLE.(shortfall, regions),
                               TestData.test1_loles, nstderr_tol))
        @test all(withinrange.(LOLE.(shortfall, regions, dt),
                               TestData.test1_loles, nstderr_tol))
        # Shortfall - EUE
        @test withinrange(EUE(shortfall), TestData.test1_eue, nstderr_tol)
        @test withinrange(EUE(shortfall, dt), TestData.test1_eue, nstderr_tol)
        @test all(withinrange.(EUE.(shortfall, regions),
                               TestData.test1_eues, nstderr_tol))
        @test all(withinrange.(EUE.(shortfall, regions, dt),
                               TestData.test1_eues, nstderr_tol))
        # Surplus
        @test withinrange(surplus[dt], TestData.test1_esurplus,
                          simspec.nsamples, nstderr_tol)
        @test all(withinrange.(getindex.(surplus, regions, dt),
                               TestData.test1_esurpluses,
                               simspec.nsamples, nstderr_tol))

        # Flow
        @test withinrange(flow["Region A" => "Region B"],
                          TestData.test1_i1_flow,
                          simspec.nsamples, nstderr_tol)
        @test withinrange(flow["Region A" => "Region B", dt],
                          TestData.test1_i1_flow,
                          simspec.nsamples, nstderr_tol)

        # Utilization
        @test withinrange(utilization["Region A" => "Region B"],
                          TestData.test1_i1_util,
                          simspec.nsamples, nstderr_tol)
        @test withinrange(utilization["Region A" => "Region B", dt],
                          TestData.test1_i1_util,
                          simspec.nsamples, nstderr_tol)

    end

    @testset "Test System 2: Gen + Storage, 1 Region" begin

        simspec = SequentialMonteCarlo(samples=1_000_000, seed=112)
        region = first(TestData.test2.regions.names)
        stor = first(TestData.test2.storages.names)
        dts = TestData.test2.timestamps

        shortfall, surplus, energy =
            assess(TestData.test2, simspec,
                   Shortfall(), Surplus(), StorageEnergy())

        # Shortfall - LOLE
        @test withinrange(LOLE(shortfall),
                          TestData.test2_lole, nstderr_tol)
        @test withinrange(LOLE(shortfall, region),
                          TestData.test2_lole, nstderr_tol)
        @test all(withinrange.(LOLE.(shortfall, dts),
                  TestData.test2_lolps, nstderr_tol))
        @test all(withinrange.(LOLE.(shortfall, region, dts),
                  TestData.test2_lolps, nstderr_tol))

        # Shortfall - EUE
        @test withinrange(EUE(shortfall),
                          TestData.test2_eue, nstderr_tol)
        @test withinrange(EUE(shortfall, region),
                          TestData.test2_eue, nstderr_tol)
        @test all(withinrange.(EUE.(shortfall, dts),
                               TestData.test2_eues, nstderr_tol))
        @test all(withinrange.(EUE.(shortfall, region, dts),
                               TestData.test2_eues, nstderr_tol))

        # Surplus
        @test all(withinrange.(getindex.(surplus, dts),
                               TestData.test2_esurplus,
                               simspec.nsamples, nstderr_tol))
        @test all(withinrange.(getindex.(surplus, region, dts),
                               TestData.test2_esurplus,
                               simspec.nsamples, nstderr_tol))
        # Energy
        @test all(withinrange.(getindex.(energy, dts),
                               TestData.test2_eenergy,
                               simspec.nsamples, nstderr_tol))
        @test all(withinrange.(getindex.(energy, stor, dts),
                               TestData.test2_eenergy,
                               simspec.nsamples, nstderr_tol))

    end

    @testset "Test System 3: Gen + Storage, 2 Regions" begin

        simspec = SequentialMonteCarlo(samples=1_000_000, seed=113)
        regions = TestData.test3.regions.names
        stor = first(TestData.test3.storages.names)
        dts = TestData.test3.timestamps

        shortfall, surplus, flow, utilization, energy =
            assess(TestData.test3, simspec,
                   Shortfall(), Surplus(), Flow(), Utilization(), StorageEnergy())

        # Shortfall - LOLE
        @test withinrange(LOLE(shortfall),
                          TestData.test3_lole, nstderr_tol)
        @test all(withinrange.(LOLE.(shortfall, regions),
                               TestData.test3_lole_r, nstderr_tol))
        @test all(withinrange.(LOLE.(shortfall, dts),
                               TestData.test3_lole_t, nstderr_tol))
        @test all(withinrange.(LOLE.(shortfall, regions, permutedims(dts)),
                               TestData.test3_lole_rt, nstderr_tol))

        # Shortfall - EUE
        @test withinrange(EUE(shortfall),
                          TestData.test3_eue, nstderr_tol)
        @test all(withinrange.(EUE.(shortfall, regions),
                               TestData.test3_eue_r, nstderr_tol))
        @test all(withinrange.(EUE.(shortfall, dts),
                               TestData.test3_eue_t, nstderr_tol))
        @test all(withinrange.(EUE.(shortfall, regions, permutedims(dts)),
                               TestData.test3_eue_rt, nstderr_tol))

        # Surplus
        @test all(withinrange.(getindex.(surplus, dts), # fails?
                               TestData.test3_esurplus_t,
                               simspec.nsamples, nstderr_tol))
        @test all(withinrange.(getindex.(surplus, regions, permutedims(dts)), # fails?
                               TestData.test3_esurplus_rt,
                               simspec.nsamples, nstderr_tol))

        # Flow
        @test all(withinrange.(getindex.(flow, "Region A"=>"Region B"),
                               TestData.test3_flow,
                               simspec.nsamples, nstderr_tol))
        @test all(withinrange.(getindex.(flow, "Region A"=>"Region B", dts),
                               TestData.test3_flow_t,
                               simspec.nsamples, nstderr_tol))

        # Utilization
        @test all(withinrange.(getindex.(utilization, "Region A"=>"Region B"),
                               TestData.test3_util,
                               simspec.nsamples, nstderr_tol))
        @test all(withinrange.(getindex.(utilization, "Region A"=>"Region B", dts),
                               TestData.test3_util_t,
                               simspec.nsamples, nstderr_tol))

        # Energy
        @test all(withinrange.(getindex.(energy, dts), # fails?
                               TestData.test3_eenergy,
                               simspec.nsamples, nstderr_tol))
        @test all(withinrange.(getindex.(energy, stor, dts), # fails?
                               TestData.test3_eenergy,
                               simspec.nsamples, nstderr_tol))


    end

    @testset "Test System 4: Gen + DR, 1 Region" begin

        simspec = SequentialMonteCarlo(samples=1_000_000, seed=112)
        region = first(TestData.test4.regions.names)
        dr = first(TestData.test4.demandresponses.names)
        dts = TestData.test4.timestamps

        shortfall, surplus, energy =
            assess(TestData.test4, simspec,
                   Shortfall(), Surplus(), DemandResponseEnergy())

        # Shortfall - LOLE
        @test withinrange(LOLE(shortfall),
                          TestData.test4_lole, nstderr_tol)
        @test withinrange(LOLE(shortfall, region),
                          TestData.test4_lole, nstderr_tol)
        @test all(withinrange.(LOLE.(shortfall, dts),
                  TestData.test4_lolps, nstderr_tol))
        @test all(withinrange.(LOLE.(shortfall, region, dts),
                  TestData.test4_lolps, nstderr_tol))

        # Shortfall - EUE
        @test withinrange(EUE(shortfall),
                          TestData.test4_eue, nstderr_tol)
        @test withinrange(EUE(shortfall, region),
                          TestData.test4_eue, nstderr_tol)
        @test all(withinrange.(EUE.(shortfall, dts),
                               TestData.test4_eues, nstderr_tol))
        @test all(withinrange.(EUE.(shortfall, region, dts),
                               TestData.test4_eues, nstderr_tol))

        # Surplus
        @test all(withinrange.(getindex.(surplus, dts),
                               TestData.test4_esurplus,
                               simspec.nsamples, nstderr_tol))
        @test all(withinrange.(getindex.(surplus, region, dts),
                               TestData.test4_esurplus,
                               simspec.nsamples, nstderr_tol))
        # Energy
        @test all(withinrange.(getindex.(energy, dts),
                               TestData.test4_eenergy,
                               simspec.nsamples, nstderr_tol))
        @test all(withinrange.(getindex.(energy, dr, dts),
                               TestData.test4_eenergy,
                               simspec.nsamples, nstderr_tol))

    end

    @testset "Test System 5: Gen + DR + Stor, 1 Region" begin

        simspec = SequentialMonteCarlo(samples=1_000_000, seed=112)
        region = first(TestData.test5.regions.names)
        dr = first(TestData.test5.demandresponses.names)
        dts = TestData.test5.timestamps

        shortfall, surplus, energy =
            assess(TestData.test5, simspec,
                   Shortfall(), Surplus(), DemandResponseEnergy())

        # Shortfall - LOLE
        @test withinrange(LOLE(shortfall),
                          TestData.test5_lole, nstderr_tol)
        @test withinrange(LOLE(shortfall, region),
                          TestData.test5_lole, nstderr_tol)
        @test all(withinrange.(LOLE.(shortfall, dts),
                  TestData.test5_lolps, nstderr_tol))
        @test all(withinrange.(LOLE.(shortfall, region, dts),
                  TestData.test5_lolps, nstderr_tol))

        # Shortfall - EUE
        @test withinrange(EUE(shortfall),
                          TestData.test5_eue, nstderr_tol)
        @test withinrange(EUE(shortfall, region),
                          TestData.test5_eue, nstderr_tol)
        @test all(withinrange.(EUE.(shortfall, dts),
                               TestData.test5_eues, nstderr_tol))
        @test all(withinrange.(EUE.(shortfall, region, dts),
                               TestData.test5_eues, nstderr_tol))

        # Surplus
        @test all(withinrange.(getindex.(surplus, dts),
                               TestData.test5_esurplus,
                               simspec.nsamples, nstderr_tol))
        @test all(withinrange.(getindex.(surplus, region, dts),
                               TestData.test5_esurplus,
                               simspec.nsamples, nstderr_tol))
        # Energy
        @test all(withinrange.(getindex.(energy, dts),
                               TestData.test5_eenergy,
                               simspec.nsamples, nstderr_tol))
        @test all(withinrange.(getindex.(energy, dr, dts),
                               TestData.test5_eenergy,
                               simspec.nsamples, nstderr_tol))

    end

    @testset "Test System 6: Gen + DR, 3 Regions" begin

        simspec = SequentialMonteCarlo(samples=1_000_000, seed=112)
        regions = TestData.threenode_dr.regions.names
        dr = first(TestData.threenode_dr.demandresponses.names)
        dts = TestData.threenode_dr.timestamps

        shortfall, surplus, dr_energy, dr_energy_samples, dr_shortfall, dr_shortfall_samples, flow, utilization =
            assess(TestData.threenode_dr, simspec,
                   Shortfall(), Surplus(), 
                   DemandResponseEnergy(),DemandResponseEnergySamples(),
                   DemandResponseShortfall(), DemandResponseShortfallSamples(),
                   Flow(), Utilization())


        # Shortfall - LOLE
        @test withinrange(LOLE(shortfall),
                          TestData.threenode_dr_lole, nstderr_tol)
        @test all(withinrange.(LOLE.(shortfall, regions),
                               TestData.threenode_dr_lole_r, nstderr_tol))
        @test all(withinrange.(LOLE.(shortfall, dts),
                               TestData.threenode_dr_lole_t, nstderr_tol))
        @test all(withinrange.(LOLE.(shortfall, "Region 2", dts),
                               TestData.threenode_dr_lole_rt, nstderr_tol))

        # Shortfall - EUE
        @test withinrange(EUE(shortfall),
                          TestData.threenode_dr_eue, nstderr_tol)
        @test all(withinrange.(EUE.(shortfall, regions),
                               TestData.threenode_dr_eue_r, nstderr_tol))
        @test all(withinrange.(EUE.(shortfall, dts),
                               TestData.threenode_dr_eue_t, nstderr_tol))
        @test all(withinrange.(EUE.(shortfall, "Region 1", dts),
                               TestData.threenode_dr_eue_rt, nstderr_tol))

        # Surplus
        @test all(withinrange.(getindex.(surplus, dts), 
                               TestData.threenode_dr_esurplus_t,
                               simspec.nsamples, nstderr_tol))
        @test all(withinrange.(getindex.(surplus, "Region 2", dts),
                               TestData.threenode_dr_esurplus_rt,
                               simspec.nsamples, nstderr_tol))

        # Flow
        @test withinrange(flow["Region 1" => "Region 2"],
                               TestData.threenode_dr_flow,
                               simspec.nsamples, nstderr_tol)
        @test all(withinrange.(getindex.(flow, "Region 1"=>"Region 2", dts),
                               TestData.threenode_dr_flow_t,
                               simspec.nsamples, nstderr_tol))

        # Utilization
        @test withinrange((sum(x[1] for x in getindex.(utilization, "Region 1"=>"Region 2")), sum(x[end] for x in getindex.(utilization, "Region 1"=>"Region 2"))),
                               TestData.threenode_dr_util,
                               simspec.nsamples, nstderr_tol)

        @test all(withinrange.(getindex.(utilization, "Region 1"=>"Region 2",dts),
                               TestData.threenode_dr_util_t,
                               simspec.nsamples, nstderr_tol))
        # DR Energy
        @test withinrange((sum(x[1] for x in getindex.(dr_energy, dts)), sum(x[end] for x in getindex.(dr_energy, dts))),
                               TestData.threenode_dr_energy,
                               simspec.nsamples, nstderr_tol)

        # DR Energy Samples
        @test isapprox(mean(sum(dr_energy_samples.energy[:, :, i]) for i in 1:1_000),TestData.threenode_dr_energy_samples, rtol=0.01)
        
        # DR Shortfall
        @test withinrange(EUE(dr_shortfall),
                          TestData.threenode_dr_shortfall_specific_eue, nstderr_tol)
        @test all(withinrange.(EUE.(dr_shortfall, regions),
                               TestData.threenode_dr_shortfall_specific_eue_r, nstderr_tol))
        @test all(withinrange.(EUE.(dr_shortfall, dts),
                               TestData.threenode_dr_shortfall_specific_eue_t, nstderr_tol))
        @test all(withinrange.(EUE.(dr_shortfall, "Region 1", dts),
                               TestData.threenode_dr_shortfall_specific_eue_rt, nstderr_tol))

        # DR Shortfall Samples
        @test isapprox(sum(dr_shortfall_samples["Region 1",dts[5]])/1e4,TestData.threenode_dr_shortfall_samples/1e4, rtol=0.01)
    end

    @testset "LOLD" begin
        @testset "Whole-horizon equals sum over days" begin
            for x in (shortfall2_1a, shortfall2_1a5, shortfall2_1b, shortfall2_3)
                days = unique(Date.(x.timestamps))
    
                @test isapprox(
                    val(LOLD(x)),
                    sum(val(LOLD(x, d)) for d in days)
                )
    
                for r in x.regions.names
                    @test isapprox(
                        val(LOLD(x, r)),
                        sum(val(LOLD(x, r, d)) for d in days)
                    )
                end
            end
        end
    
        @testset "Single-day query matches direct sample calculation" begin
            for x in (shortfall2_1a, shortfall2_1a5, shortfall2_1b, shortfall2_3)
                days = unique(Date.(x.timestamps))
    
                # test first, middle, and last day
                testdays = unique([first(days), days[cld(length(days), 2)], last(days)])
    
                for d in testdays
                    mask = Date.(x.timestamps) .== d
    
                    # system-wide day event by sample:
                    # did any region have any shortfall in any timestep of this day?
                    manual_system = vec(any(dropdims(sum(x.shortfall[:, mask, :], dims=1), dims=1) .> 0, dims=1))
                    expected_system = MeanEstimate(manual_system)
    
                    @test LOLD(x, d) ≈ LOLD{1}(expected_system)
    
                    for r in x.regions.names
                        i_r = findfirst(isequal(r), x.regions.names)
    
                        # region-day event by sample:
                        # did this region have any shortfall in any timestep of this day?
                        manual_region = vec(any(x.shortfall[i_r, mask, :] .> 0, dims=1))
                        expected_region = MeanEstimate(manual_region)
    
                        @test LOLD(x, r, d) ≈ LOLD{1}(expected_region)
                    end
                end
            end
        end
    
        @testset "Broadcast helpers match scalar calls" begin
            for x in (shortfall2_1a, shortfall2_1a5, shortfall2_1b, shortfall2_3)
                days = unique(Date.(x.timestamps))
    
                # region over all days
                for r in x.regions.names
                    @test all(LOLD(x, r, :) .≈ LOLD.(Ref(x), r, days))
                end
    
                # all regions for one day
                for d in (first(days), days[cld(length(days), 2)], last(days))
                    @test all(LOLD(x, :, d) .≈ LOLD.(Ref(x), x.regions.names, d))
                end
    
                # full region x day grid
                @test all(LOLD(x, :, :) .≈ LOLD.(Ref(x), x.regions.names, permutedims(days)))
            end
        end
    
        @testset "System day risk dominates regional day risk" begin
            for x in (shortfall2_1a, shortfall2_1a5, shortfall2_1b, shortfall2_3)
                for d in unique(Date.(x.timestamps))
                    system_val = val(LOLD(x, d))
                    for r in x.regions.names
                        @test system_val >= val(LOLD(x, r, d))
                    end
                end
            end
        end
    
        @testset "Invalid day throws useful error" begin
            for x in (shortfall2_1a, shortfall2_1a5, shortfall2_1b, shortfall2_3)
                bad_day = first(unique(Date.(x.timestamps))) - Day(1)
        
                err = try
                    LOLD(x, bad_day)
                    nothing
                catch e
                    e
                end
        
                @test err isa ArgumentError
                @test occursin("simulation horizon", sprint(showerror, err))
        
                err = try
                    LOLD(x, first(x.regions.names), bad_day)
                    nothing
                catch e
                    e
                end
        
                @test err isa ArgumentError
                @test occursin("simulation horizon", sprint(showerror, err))
            end
        end

        @testset "ShortfallResult error handling" begin
            for x in (shortfall_1a, shortfall_1a5, shortfall_1b, shortfall_3)
                @test_throws ArgumentError LOLD(x)
                @test_throws ArgumentError LOLD(x, first(x.regions.names))
                @test_throws ArgumentError LOLD(x, Date(first(x.timestamps)))
                @test_throws ArgumentError LOLD(x, first(x.regions.names), Date(first(x.timestamps)))
            end
        end

        @testset "Multiple shortfall periods in same day count once" begin
            for x in (shortfall2_1a, shortfall2_1a5, shortfall2_1b, shortfall2_3)
                d = first(unique(Date.(x.timestamps)))
                dayrange = findall(t -> Date(t) == d, x.timestamps)
        
                if length(dayrange) >= 2
                    i_r = 1
                    s = 1
        
                    y = deepcopy(x)
                    y.shortfall .= 0
                    y.shortfall[i_r, dayrange[1], s] = 1
                    y.shortfall[i_r, dayrange[2], s] = 1
        
                    expected = 1 / size(y.shortfall, 3)
        
                    @test val(LOLD(y)) ≈ expected
                    @test val(LOLD(y, d)) ≈ expected
                    @test val(LOLD(y, y.regions.names[i_r])) ≈ expected
                    @test val(LOLD(y, y.regions.names[i_r], d)) ≈ expected
                end
            end
        end

    end


end
