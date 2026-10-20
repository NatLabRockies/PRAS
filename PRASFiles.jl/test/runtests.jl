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


    @testset "Read version 0.7.0 to 0.9.0 compatibility" begin

        path = dirname(@__FILE__)
        version_0_7_0 = SystemModel(path * "/versioned_toy/toymodel_v0_7_0.pras")
        version_0_9_0 = SystemModel(path * "/versioned_toy/toymodel_v0_9_0.pras")

        @test version_0_7_0 == version_0_9_0
        end

    @testset "Read version 0.8.0 to 0.9.0 compatibility" begin

        path = dirname(@__FILE__)
        version_0_8_0 = SystemModel(path * "/versioned_toy/toymodel_v0_8_0.pras")
        version_0_9_0 = SystemModel(path * "/versioned_toy/toymodel_v0_9_0.pras")

        @test version_0_8_0 == version_0_9_0
        end

    @testset "Run RTS-GMLC" begin

        assess(PRASFiles.rts_gmlc(), SequentialMonteCarlo(samples=100), Shortfall())

    end

    @testset "Test Optional Params Roundtrip" begin

        path = dirname(@__FILE__)
        rts = PRASFiles.rts_gmlc()

        #create new dr
        (timesteps,periodlen,periodunit,powerunit,energyunit) = get_params(rts);
        number_of_drs = 2;
        new_drs = DemandResponses{timesteps,periodlen,periodunit,powerunit,energyunit}(
            ["DR1","DR2"],
            ["DR_TYPE1","DR_TYPE2"],
            fill(50, number_of_drs, timesteps),   # borrow power capacity
            fill(50, number_of_drs, timesteps),   # payback power capacity
            fill(200, number_of_drs, timesteps),  # load energy capacity
            fill(0.0, number_of_drs, timesteps),  # 0% borrowed energy interest
            fill(6, number_of_drs, timesteps),    # 6 hour allowable payback time periods
            fill(0.1, number_of_drs, timesteps),  # 10% outage probability
            fill(0.9, number_of_drs, timesteps);  # 90% recovery probability
            initial_borrowed_load = fill(0.6, number_of_drs),
            borrow_efficiency = fill(0.95, number_of_drs, timesteps),
            payback_efficiency = fill(0.99, number_of_drs, timesteps),
            energy_budget = [100.5, Inf],
            );

        dr_region_indices = [1:0,1:1,2:2];

        rts.storages.initial_soc[:] .= 0.4;
        rts.generatorstorages.initial_soc[:] .= 0.5;

        new_rts  = SystemModel(
            rts.regions, rts.interfaces,
            rts.generators, rts.region_gen_idxs,
            rts.storages, rts.region_stor_idxs,
            rts.generatorstorages, rts.region_genstor_idxs,
            new_drs, dr_region_indices,
            rts.lines, rts.interface_line_idxs,
            rts.timestamps);

        savemodel(new_rts,path * "/opt_param_test.pras")

        rt_rts = SystemModel(path * "/opt_param_test.pras")
        @test all(rt_rts.storages.initial_soc .== 0.4)
        @test all(rt_rts.generatorstorages.initial_soc .== 0.5)
        @test all(rt_rts.demandresponses.initial_borrowed_load .== 0.6)
        @test all(rt_rts.demandresponses.borrow_efficiency .== 0.95)
        @test all(rt_rts.demandresponses.payback_efficiency .== 0.99)
        @test rt_rts.demandresponses.energy_budget == [100.5, Inf]

        @test rt_rts == new_rts
    end

    @testset "Save Aggregate Results" begin
        rts_sys = PRASFiles.rts_gmlc()
        # Make load in all regions in rts_sys 10 times the original load for meaningful results
        for i in 1:length(rts_sys.regions.names)
            rts_sys.regions.load[i, :] = 10 * rts_sys.regions.load[i, :]
        end
        results = assess(rts_sys, SequentialMonteCarlo(samples=10, threaded = false, seed = 1), Shortfall(), ShortfallSamples(), Surplus());
        shortfall = results[1];
        lold_message = r"LOLD is not implemented for ShortfallResult"
        @test_logs (:info, lold_message) PRASFiles.generate_systemresult(shortfall, rts_sys)
        @test_logs (:info, lold_message) PRASFiles.generate_systemresult(shortfall, rts_sys)
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
