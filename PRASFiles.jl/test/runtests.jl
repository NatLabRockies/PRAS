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

    @testset "Non-contiguous time slices" begin

        path = dirname(@__FILE__)

        # Rebuild the toy model with a non-contiguous time axis: split its N
        # timesteps into two slices separated by a large gap. Asset data is
        # unchanged; only the timestamps are relabeled.
        toy = PRASFiles.toymodel()
        N = length(toy.timestamps)
        Δ = step(toy.timestamps)
        n1 = N ÷ 2
        t0 = first(toy.timestamps)
        slice1 = t0:Δ:(t0 + (n1 - 1) * Δ)
        s2 = t0 + (N + 50) * Δ
        slice2 = s2:Δ:(s2 + (N - n1 - 1) * Δ)

        noncontig = SystemModel(
            toy.regions, toy.interfaces,
            toy.generators, toy.region_gen_idxs,
            toy.storages, toy.region_stor_idxs,
            toy.generatorstorages, toy.region_genstor_idxs,
            toy.demandresponses, toy.region_dr_idxs,
            toy.lines, toy.interface_line_idxs,
            [slice1, slice2], toy.attrs)

        @test noncontig.timestamps isa SlicedTimestamps
        @test length(noncontig.timestamps) == N

        # Round-trip through a .pras file preserves the slices
        savemodel(noncontig, path * "/toy_noncontig.pras")
        rt = SystemModel(path * "/toy_noncontig.pras")
        @test rt.timestamps isa SlicedTimestamps
        @test noncontig == rt
        # Slice metadata must not leak into user attributes
        @test !haskey(PRASFiles.read_attrs(path * "/toy_noncontig.pras"), "n_slices")

        # assess runs over the concatenated timesteps and results index across the gap
        sf = assess(noncontig,
                    SequentialMonteCarlo(samples=10, threaded=false, seed=1),
                    Shortfall())[1]
        @test length(sf.timestamps) == N
        @test sf[first(slice2)] !== nothing

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

        @test exp_results_1.lole.mean ≈ exp_results_2.lole.mean
        @test exp_results_1.eue.mean ≈ exp_results_2.eue.mean
        @test exp_results_1.neue.mean ≈ exp_results_2.neue.mean
        @test exp_results_1.region_results[1].lole.mean ≈ exp_results_2.region_results[1].lole.mean
        @test exp_results_1.region_results[1].eue.mean ≈ exp_results_2.region_results[1].eue.mean
        @test exp_results_1.region_results[1].neue.mean ≈ exp_results_2.region_results[1].neue.mean

        surplus = results[3]
        @test_throws "saveshortfall is not implemented for" PRASFiles.saveshortfall(surplus, rts_sys, path)
    end

end
