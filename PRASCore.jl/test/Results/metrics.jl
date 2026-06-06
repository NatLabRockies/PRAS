@testset verbose = true "Metrics" begin

    @testset "MeanEstimate" begin

    me1 = MeanEstimate(513.1, 26)
    @test val(me1) == 513.1
    @test stderror(me1) == 26.
    @test string(me1) == "510±30"

    me2 = MeanEstimate(0.03, 0.0001)
    me3 = MeanEstimate(0.03, 0.001, 100)
    @test me2 ≈ me2
    @test val(me2) == 0.03
    @test stderror(me2) == 0.0001
    @test string(me2) == "0.0300±0.0001"

    me4 = MeanEstimate(2.4)
    @test val(me4) == 2.4
    @test stderror(me4) == 0.
    @test string(me4) == "2.40000"

    me5 = MeanEstimate([1,2,3,4,5])
    @test val(me5) == 3.
    @test stderror(me5) ≈ sqrt(0.5)

    me6 = MeanEstimate(-503.1, 260)
    @test val(me6) == -503.1
    @test stderror(me6) == 260.
    @test string(me6) == "-500±300"

    @test_throws DomainError MeanEstimate(1.23, -0.002)

    end

    @testset "LOLE" begin

        lole1 = LOLE{4380,2,Hour}(MeanEstimate(1.2))
        @test string(lole1) == "LOLE = 1.20000 event-(2h)/8760h"

        lole2 = LOLE{8760,1,Hour}(MeanEstimate(2.4, 0.1))
        @test string(lole2) == "LOLE = 2.4±0.1 event-h/8760h"

        lole3 = LOLE{3650,1,Day}(MeanEstimate(1.0, 0.01))
        @test string(lole3) == "LOLE = 1.00±0.01 event-d/3650d"

        @test_throws DomainError LOLE{3650,1,Day}(MeanEstimate(-1.2, 0.))


    end

    @testset "EUE" begin

        eue1 = EUE{2,1,Hour,MWh}(MeanEstimate(1.2))
        @test string(eue1) == "EUE = 1.20000 MWh/2h"

        eue2 = EUE{1,2,Year,GWh}(MeanEstimate(17.2, 1.3))
        @test string(eue2) == "EUE = 17±1 GWh/2y"

        @test_throws DomainError EUE{1,1,Hour,MWh}(MeanEstimate(-1.2))

    end

    @testset "NEUE" begin

        neue = NEUE(MeanEstimate(1.2))
        @test string(neue) == "NEUE = 1.20000 ppm"

        neue2 = NEUE(MeanEstimate(17.2, 1.3))
        @test string(neue2) == "NEUE = 17±1 ppm"

        @test_throws DomainError NEUE(MeanEstimate(-1.2))

    end
  
    @testset "CVAR" begin

        cvar1 = CVAR{2,1,Hour,MWh}(:energy,MeanEstimate(1.2), 0.95, 2.0)
        @test string(cvar1) == "CVAR@0.95 = 1.20000 MWh/2h"

        cvar2 = CVAR{1,2,Year,GWh}(:energy,MeanEstimate(17.2, 1.3), 0.95, 1.2)
        @test string(cvar2) == "CVAR@0.95 = 17±1 GWh/2y"

        @test_throws DomainError CVAR{1,1,Hour,MWh}(:energy,MeanEstimate(-1.2), 0.95, 1.2)

    end    

    @testset "NCVAR" begin

        ncvar1 = NCVAR(MeanEstimate(1.2), 0.95, 1.2)
        @test string(ncvar1) == "NCVAR@0.95 = 1.20000 ppm"

        ncvar2 = NCVAR(MeanEstimate(17.2, 1.3), 0.95, 1.3)
        @test string(ncvar2) == "NCVAR@0.95 = 17±1 ppm"

        @test_throws DomainError NCVAR(MeanEstimate(-1.2), 0.95, -1.2)

    end

end
