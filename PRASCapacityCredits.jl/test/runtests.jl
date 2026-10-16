using PRASCapacityCredits
using PRASCore
using Test

import PRASCore.Systems: TestData

@testset verbose=true "PRASCapacityCredits" begin

    empty_str = String[]
    empty_int(x) = Matrix{Int}(undef, 0, x)
    empty_float(x) = Matrix{Float64}(undef, 0, x)

    gens = Generators{4,1,Hour,MW}(
        ["Gen1", "Gen2", "Gen3", "VG"],
        ["Gens", "Gens", "Gens", "VG"],
        [fill(10, 3, 4); [5 6 7 8]],
        [fill(0.1, 3, 4); fill(0.0, 1, 4)],
        [fill(0.9, 3, 4); fill(1.0, 1, 4)]
    )

    gens_after = Generators{4,1,Hour,MW}(
        ["Gen1", "Gen2", "Gen3", "Gen4", "VG"],
        ["Gens", "Gens", "Gens", "Gens", "VG"],
        [fill(10, 4, 4); [5 6 7 8]],
        [fill(0.1, 4, 4); fill(0.0, 1, 4)],
        [fill(0.9, 4, 4); fill(1.0, 1, 4)]
    )

    emptystors = Storages{4,1,Hour,MW,MWh}((empty_str for _ in 1:2)...,
                      (empty_int(4) for _ in 1:3)...,
                      (empty_float(4) for _ in 1:5)...)

    emptygenstors = GeneratorStorages{4,1,Hour,MW,MWh}(
        (empty_str for _ in 1:2)...,
        (empty_int(4) for _ in 1:3)..., (empty_float(4) for _ in 1:3)...,
        (empty_int(4) for _ in 1:3)..., (empty_float(4) for _ in 1:2)...)

    load = [25, 28, 27, 24]

    tz = tz"UTC"
    timestamps = ZonedDateTime(2010,1,1,0,tz):Hour(1):ZonedDateTime(2010,1,1,3,tz)

    sys_before = SystemModel(
        gens, emptystors, emptygenstors, timestamps, load)

    sys_after = SystemModel(
        gens_after, emptystors, emptygenstors, timestamps, load)

    threenode2 = deepcopy(TestData.threenode)
    threenode2.generators.capacity[1, :] .+= 5

    smc = SequentialMonteCarlo(samples=100_000, threaded=false)

    @testset "EFC" begin

        cc = assess(sys_before, sys_after, EFC{EUE}(10, "Region"), smc)
        @test extrema(cc) == (8, 9)

        cc = assess(TestData.threenode, threenode2, EFC{EUE}(10, "Region A"), smc)
        @test extrema(cc) == (3, 4)

    end

    @testset "EFC_Secant" begin

        cc = assess(sys_before, sys_after, EFC_Secant{EUE}(10, "Region"), smc)
        # Bisection found [8, 9], Secant returns a point (bound_low == bound_high)
        @test 8 <= minimum(cc) <= 9

        cc = assess(TestData.threenode, threenode2, EFC_Secant{EUE}(10, "Region A"), smc)
        # Bisection found [3, 4]
        @test 3 <= minimum(cc) <= 4

    end

    @testset "ELCC" begin

        cc = assess(sys_before, sys_after, ELCC{EUE}(10, "Region"), smc)
        @test extrema(cc) == (7, 8)

        cc = assess(TestData.threenode, threenode2, ELCC{EUE}(10, "Region A"), smc)
        @test extrema(cc) == (3, 4)

    end

    @testset "ELCC_Secant" begin

        cc = assess(sys_before, sys_after, ELCC_Secant{EUE}(10, "Region"), smc)
        # Bisection found [7, 8]
        @test 7 <= minimum(cc) <= 8

        cc = assess(TestData.threenode, threenode2, ELCC_Secant{EUE}(10, "Region A"), smc)
        # Bisection found [3, 4]
        @test 3 <= minimum(cc) <= 4

    end

end
