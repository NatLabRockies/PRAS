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

        @test rt_rts == new_rts
    end

    @testset "Save Aggregate Results" begin
        rts_sys = PRASFiles.rts_gmlc()
        # Make load in all regions in rts_sys 10 times the original load for meaningful results
        for i in 1:length(rts_sys.regions.names)
            rts_sys.regions.load[i, :] = 10 * rts_sys.regions.load[i, :]
        end
        export_cases = (
            ("Hourly", rts_sys, 10),
            ("Subhourly", PRASCore.Systems.TestData.singlenode_a_5min, 100),
        )

        for (name, system, nsamples) in export_cases
            @testset "$name" begin
                results = assess(system, SequentialMonteCarlo(samples=nsamples, threaded = false, seed = 1), Shortfall(), ShortfallSamples(), Surplus());
                shortfall = results[1];
                lold_message = r"LOLD is not implemented for ShortfallResult"
                @test_logs (:info, lold_message) PRASFiles.generate_systemresult(shortfall, system)
                @test_logs (:info, lold_message) PRASFiles.generate_systemresult(shortfall, system)
                path = joinpath(dirname(@__FILE__), "PRAS_Results_Export", name);
                exp_location_1 = PRASFiles.saveshortfall(shortfall, system, joinpath(path, "shortfall"));
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
                exp_location_2 = PRASFiles.saveshortfall(shortfall_samples, system, joinpath(path, "samples"));
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

                @test any(>(0), exp_results_1.region_results[1].shortfall_mean)
                @test exp_results_1.num_samples == exp_results_2.num_samples
                @test exp_results_1.type_params.N == exp_results_2.type_params.N
                @test exp_results_1.type_params.L == exp_results_2.type_params.L
                @test exp_results_1.type_params.T == exp_results_2.type_params.T
                @test exp_results_1.type_params.P == exp_results_2.type_params.P
                @test exp_results_1.type_params.E == exp_results_2.type_params.E
                @test exp_results_1.sys_attributes == exp_results_2.sys_attributes
                @test exp_results_1.timestamps == exp_results_2.timestamps
                @test exp_results_1.lole.mean ≈ exp_results_2.lole.mean
                @test exp_results_1.lole.stderror ≈ exp_results_2.lole.stderror
                @test exp_results_1.eue.mean ≈ exp_results_2.eue.mean
                @test exp_results_1.eue.stderror ≈ exp_results_2.eue.stderror
                @test exp_results_1.neue.mean ≈ exp_results_2.neue.mean
                @test exp_results_1.neue.stderror ≈ exp_results_2.neue.stderror

                @test length(exp_results_1.region_results) == length(exp_results_2.region_results)
                for (region_1, region_2) in zip(exp_results_1.region_results, exp_results_2.region_results)
                    @test region_1.name == region_2.name
                    @test region_1.load == region_2.load
                    @test region_1.peak_load == region_2.peak_load
                    @test region_1.capacity == region_2.capacity
                    @test region_1.shortfall_timestamps == region_2.shortfall_timestamps
                    @test region_1.shortfall_mean ≈ region_2.shortfall_mean
                    @test region_1.lole.mean ≈ region_2.lole.mean
                    @test region_1.lole.stderror ≈ region_2.lole.stderror
                    @test region_1.eue.mean ≈ region_2.eue.mean
                    @test region_1.eue.stderror ≈ region_2.eue.stderror
                    @test region_1.neue.mean ≈ region_2.neue.mean
                    @test region_1.neue.stderror ≈ region_2.neue.stderror
                    @test region_1.lold === nothing
                    @test region_2.lold !== nothing
                end

                @test exp_results_1.lold === nothing
                @test exp_results_2.lold !== nothing

                surplus = results[3]
                @test_throws "saveshortfall is not implemented for" PRASFiles.saveshortfall(surplus, system, path)
            end
        end
    end

    @testset "Save Event Results" begin
        rts_sys = PRASFiles.rts_gmlc()
        # Make load in all regions 10 times the original load for meaningful results
        for i in 1:length(rts_sys.regions.names)
            rts_sys.regions.load[i, :] = 10 * rts_sys.regions.load[i, :]
        end

        events, = assess(
            rts_sys,
            SequentialMonteCarlo(samples = 10, threaded = false, seed = 1),
            ShortfallEvents(),
        )

        summary_result = PRASFiles.generate_eventresult(events, rts_sys)
        event_result = PRASFiles.generate_eventresult(
            events,
            rts_sys;
            include_events = true,
        )

        @test summary_result.total_events == event_result.total_events
        @test isempty(summary_result.system_events)
        @test all(isempty(region.events) for region in summary_result.region_results)
        @test length(event_result.system_events) == event_result.total_events
        @test all(
            length(region.events) == region.total_events
            for region in event_result.region_results
        )
        @test event_result.lolev.mean == PRASCore.LOLEv(events).lolev.estimate
        @test event_result.mean_event_duration.mean ==
            PRASCore.MeanEventDuration(events).duration.estimate
        @test event_result.mean_event_energy.mean ==
            PRASCore.MeanEventEnergy(events).energy.estimate

        @test !isempty(event_result.system_events)
        first_record = first(event_result.system_events)
        first_event = first(events.system_events[first_record.sample_id])
        @test first_record.start_timestamp == events.timestamps[first_event.start_idx]
        @test first_record.end_timestamp == events.timestamps[first_event.end_idx]
        @test first_record.duration_periods ==
            PRASCore.Results.duration_periods(first_event)
        (_, period_length, period_unit, power_unit, energy_unit) = get_params(rts_sys)
        @test first_record.energy ==
            conversionfactor(period_length, period_unit, power_unit, energy_unit) *
            PRASCore.Results.event_energy(first_event)

        path = joinpath(dirname(@__FILE__), "PRAS_Results_Export")
        exp_location = PRASFiles.saveevents(
            events,
            rts_sys,
            path;
            include_events = true,
        )
        result_path = joinpath(exp_location, "pras_event_results.json")
        @test isfile(result_path)
        exp_result = JSON3.read(result_path, PRASFiles.SystemEventResult)
        @test exp_result.total_events == event_result.total_events
        @test length(exp_result.system_events) == event_result.total_events

        empty_sys = PRASFiles.rts_gmlc()
        fill!(empty_sys.regions.load, 0)
        empty_events, = assess(
            empty_sys,
            SequentialMonteCarlo(samples = 2, threaded = false, seed = 1),
            ShortfallEvents(),
        )
        empty_result = PRASFiles.generate_eventresult(
            empty_events,
            empty_sys;
            include_events = true,
        )
        @test isempty(empty_result.system_events)
        @test all(isempty(region.events) for region in empty_result.region_results)
    end

end
