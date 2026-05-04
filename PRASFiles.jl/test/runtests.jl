using PRASCore
using PRASFiles
using Test
using JSON3

@testset verbose=true "PRASFiles" begin

    @testset "Roundtrip .pras files to/from disk" begin

        # TODO: Verify systems accurately depicted?
        path = dirname(@__FILE__)

        toy = PRASFiles.toymodel()
        savemodel(toy, path * "/toymodel2.pras")
        toy2 = SystemModel(path * "/toymodel2.pras")
        @test toy == toy2

        rts = PRASFiles.rts_gmlc()
        savemodel(rts, path * "/rts2.pras")
        rts2 = SystemModel(path * "/rts2.pras")
        @test rts == rts2

        # Test saving of system attributes
        push!(rts.attrs,"about" => "this is a representation of the RTS GMLC system")
        savemodel(rts,path * "/rts_userattrs.pras")

        rts_userattrs = SystemModel(path * "/rts_userattrs.pras")
        @test rts == rts_userattrs
        @test PRASFiles.read_attrs(path * "/rts_userattrs.pras") == Dict("about" => "this is a representation of the RTS GMLC system")

    end

    @testset "Run RTS-GMLC" begin

        assess(PRASFiles.rts_gmlc(), SequentialMonteCarlo(samples=100), Shortfall())

    end

    @testset "Save Aggregate Results" begin
        rts_sys = PRASFiles.rts_gmlc()
        # Make load in all regions in rts_sys 10 times the original load for meaningful results
        for i in 1:length(rts_sys.regions.names)
            rts_sys.regions.load[i, :] = 10 * rts_sys.regions.load[i, :]
        end
        results = assess(rts_sys, SequentialMonteCarlo(samples=10, threaded = false, seed = 1), Shortfall(), ShortfallSamples(), Surplus());
        shortfall = results[1];
        path = joinpath(dirname(@__FILE__),"PRAS_Results_Export");
        exp_location_1 = PRASFiles.saveshortfall(shortfall, rts_sys, path);
        @test isfile(joinpath(exp_location_1, "pras_results.json"))
        exp_results_1 = JSON3.read(joinpath(exp_location_1, "pras_results.json"), PRASFiles.SystemResult)
        @test exp_results_1.lole.mean == PRASCore.LOLE(shortfall).lole.estimate
        @test exp_results_1.eue.mean == PRASCore.EUE(shortfall).eue.estimate
        @test exp_results_1.neue.mean == PRASCore.NEUE(shortfall).neue.estimate
        @test exp_results_1.region_results[1].lole.mean == PRASCore.LOLE(shortfall, exp_results_1.region_results[1].name).lole.estimate
        @test exp_results_1.region_results[1].eue.mean == PRASCore.EUE(shortfall, exp_results_1.region_results[1].name).eue.estimate
        @test exp_results_1.region_results[1].neue.mean == PRASCore.NEUE(shortfall, exp_results_1.region_results[1].name).neue.estimate
        @test exp_results_1.lold === nothing
        @test exp_results_1.region_results[1].lold === nothing

        shortfall_samples = results[2];
        exp_location_2 = PRASFiles.saveshortfall(shortfall_samples, rts_sys, path);
        @test isfile(joinpath(exp_location_2, "pras_results.json"))
        exp_results_2 = JSON3.read(joinpath(exp_location_2, "pras_results.json"), PRASFiles.SystemResult)
        @test exp_results_2.lole.mean == PRASCore.LOLE(shortfall_samples).lole.estimate
        @test exp_results_2.eue.mean == PRASCore.EUE(shortfall_samples).eue.estimate
        @test exp_results_2.neue.mean == PRASCore.NEUE(shortfall_samples).neue.estimate
        @test exp_results_2.region_results[1].lole.mean == PRASCore.LOLE(shortfall_samples, exp_results_2.region_results[1].name).lole.estimate
        @test exp_results_2.region_results[1].eue.mean == PRASCore.EUE(shortfall_samples, exp_results_2.region_results[1].name).eue.estimate
        @test exp_results_2.region_results[1].neue.mean == PRASCore.NEUE(shortfall_samples, exp_results_2.region_results[1].name).neue.estimate
        @test exp_results_2.lold.mean == PRASCore.LOLD(shortfall_samples).lold.estimate
        @test exp_results_2.lold.stderror == PRASCore.LOLD(shortfall_samples).lold.standarderror
        region_name = exp_results_2.region_results[1].name
        @test exp_results_2.region_results[1].lold.mean == PRASCore.LOLD(shortfall_samples, region_name).lold.estimate
        @test exp_results_2.region_results[1].lold.stderror == PRASCore.LOLD(shortfall_samples, region_name).lold.standarderror

        @test exp_results_1.lole.mean ≈ exp_results_2.lole.mean
        @test exp_results_1.eue.mean ≈ exp_results_2.eue.mean
        @test exp_results_1.neue.mean ≈ exp_results_2.neue.mean
        @test exp_results_1.region_results[1].lole.mean ≈ exp_results_2.region_results[1].lole.mean
        @test exp_results_1.region_results[1].eue.mean ≈ exp_results_2.region_results[1].eue.mean
        @test exp_results_1.region_results[1].neue.mean ≈ exp_results_2.region_results[1].neue.mean

        @test exp_results_1.lold === nothing
        @test exp_results_2.lold !== nothing
        @test exp_results_2.region_results[1].lold !== nothing

        surplus = results[3]
        @test_throws "saveshortfall is not implemented for" PRASFiles.saveshortfall(surplus, rts_sys, path)
    end

end
