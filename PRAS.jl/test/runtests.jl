using PRAS
using Test

@testset "ShortfallResult" begin
    sys = PRAS.rts_gmlc()

    sf, = assess(sys, SequentialMonteCarlo(samples=100), Shortfall())

    eue = EUE(sf)
    lole = LOLE(sf)
    neue = NEUE(sf)

    alpha = 0.95
    cvar = CVAR(:energy, sf, alpha)
    ncvar = NCVAR(sf, cvar)

    @test val(eue) isa Float64
    @test stderror(eue) isa Float64
    @test val(neue) isa Float64
    @test stderror(neue) isa Float64
    @test val(cvar) isa Float64
    @test stderror(cvar) isa Float64
    @test val(ncvar) isa Float64
    @test stderror(ncvar) isa Float64

end

@testset "ShortfallSamplesResult" begin
    sys = PRAS.rts_gmlc()

    sf, = assess(sys, SequentialMonteCarlo(samples=100), ShortfallSamples())

    eue = EUE(sf)
    lole = LOLE(sf)
    neue = NEUE(sf)

    alpha = 0.95
    cvar = CVAR(:energy, sf, alpha)
    ncvar = NCVAR(sf, cvar)

    @test val(eue) isa Float64
    @test stderror(eue) isa Float64
    @test val(neue) isa Float64
    @test stderror(neue) isa Float64
    @test val(cvar) isa Float64
    @test stderror(cvar) isa Float64
    @test val(ncvar) isa Float64
    @test stderror(ncvar) isa Float64
end