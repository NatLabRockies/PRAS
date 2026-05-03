@testset verbose = true "SystemModel" begin

    generators = Generators{10,1,Hour,MW}(
        ["Gen A", "Gen B"], ["CC", "CT"],
        rand(1:10, 2, 10), fill(0.1, 2, 10), fill(0.1, 2, 10))

    storages = Storages{10,1,Hour,MW,MWh}(
        ["S1", "S2"], ["Battery", "Pumped Hydro"],
        rand(1:10, 2, 10), rand(1:10, 2, 10), rand(1:10, 2, 10),
        fill(0.9, 2, 10), fill(1.0, 2, 10), fill(0.99, 2, 10),
        fill(0.1, 2, 10), fill(0.5, 2, 10))

    generatorstorages = GeneratorStorages{10,1,Hour,MW,MWh}(
        ["GS1"], ["CSP"],
        rand(1:10, 1, 10), rand(1:10, 1, 10), rand(1:10, 1, 10),
        fill(0.9, 1, 10), fill(1.0, 1, 10), fill(0.99, 1, 10),
        rand(1:10, 1, 10), rand(1:10, 1, 10), rand(1:10, 1, 10),
        fill(0.1, 1, 10), fill(0.5, 1, 10))

    demandresponses = DemandResponses{10,1,Hour,MW,MWh}(
        ["S1", "S2"], ["HVAC", "Industrial"],
        rand(1:10, 2, 10), rand(1:10, 2, 10), rand(1:10, 2, 10),
        fill(0.99, 2, 10),
        fill(4, 2, 10),fill(0.1, 2, 10), fill(0.5, 2, 10),
        fill(0.9, 2, 10), fill(1.0, 2, 10))

    tz = tz"UTC"
    timestamps = ZonedDateTime(2020, 1, 1, 0, tz):Hour(1):ZonedDateTime(2020,1,1,9, tz)
    attrs = Dict("type" => "Single-Region System")
    single_reg_sys_wo_attrs = SystemModel(
        generators, storages, generatorstorages, demandresponses, timestamps, rand(1:20, 10))

    single_reg_sys_with_attrs = SystemModel(
        generators, storages, generatorstorages, timestamps, rand(1:20, 10), attrs)
    # Single-region constructor
    @testset "Single-region SystemModel Constructor" begin
        @test single_reg_sys_wo_attrs isa SystemModel
        @test single_reg_sys_with_attrs isa SystemModel
    end

    @testset "Single-region SystemModel Printing" begin
        # Single-region SystemModel Printing Test
        io = IOBuffer()
        show(io, "text/plain", single_reg_sys_with_attrs)
        text = String(take!(io))
        @test occursin("PRAS system with 1 regions,", text)
        @test occursin("Region names:", text)
        @test occursin("Assets:", text)
        @test occursin("Time series:", text)
        @test occursin("Attributes:", text)
    end
    reg_load= rand(1:20, 2, 10)
    regions = Regions{10,MW}(
        ["Region A", "Region B"], reg_load)

    interfaces = Interfaces{10,MW}(
        [1], [2], fill(100, 1, 10), fill(100, 1, 10))

    lines = Lines{10,1,Hour,MW}(
        ["Line 1", "Line 2"], ["Line", "Line"],
        fill(10, 2, 10), fill(10, 2, 10), fill(0., 2, 10), fill(1.0, 2, 10))

    gen_regions = [1:1, 2:2]
    stor_regions = [1:0, 1:2]
    genstor_regions = [1:1, 2:1]
    dr_regions =  [1:0, 1:2]
    line_interfaces = [1:2]

    # Multi-region constructor
    multi_region_sys_wo_attrs = SystemModel(
        regions, interfaces,
        generators, gen_regions, storages, stor_regions,
        generatorstorages, genstor_regions,
        demandresponses, dr_regions,
        lines, line_interfaces,
        timestamps)
  

    attrs = Dict("type" => "Multi-Region System")
    multi_region_sys_with_attrs = SystemModel(
        regions, interfaces,
        generators, gen_regions, storages, stor_regions,
        generatorstorages, genstor_regions,
        lines, line_interfaces,
        timestamps, attrs)

    @testset "Multi-region SystemModel Constructor" begin
        @test multi_region_sys_wo_attrs isa SystemModel
        @test multi_region_sys_with_attrs isa SystemModel
        
        attrs = Dict("type" => "Multi-Region System", "year" => 2025)
        @test_throws MethodError multi_region_sys_with_attrs = SystemModel(
        regions, interfaces,
        generators, gen_regions, storages, stor_regions,
        generatorstorages, genstor_regions,
        lines, line_interfaces,
        timestamps, attrs)

    end
    
    @testset "Multi-region SystemModel Printing" begin
        io = IOBuffer()
        show(io, "text/plain", multi_region_sys_with_attrs)
        text = String(take!(io))
        @test occursin("PRAS system with 2 regions, and 1 interfaces between these regions.", text)
        @test occursin("Region names:", text)
        @test occursin("Generators: 2", text)
        @test occursin("Storages: 2", text)
        @test occursin("GeneratorStorages: 1", text)
        @test occursin("Lines: 2", text)
        @test occursin("Resolution: 1", text)
        @test occursin("Resolution: 1", text)
        @test occursin("Time zone: UTC", text)
        @test occursin("type: Multi-Region System", text)
    end

    @testset "Region indexing and printing" begin
        @test_throws KeyError multi_region_sys_with_attrs["Region C"]
        @test_throws BoundsError multi_region_sys_with_attrs[3]

        @test multi_region_sys_with_attrs["Region A"].peak_load == maximum(reg_load[1,:])
        @test multi_region_sys_with_attrs["Region B"].peak_load == maximum(reg_load[2,:])

        @test multi_region_sys_with_attrs["Region A"].generators.indices == gen_regions[1]
        @test multi_region_sys_with_attrs["Region B"].generators.indices == gen_regions[2]

        @test multi_region_sys_with_attrs["Region A"].storages.indices == stor_regions[1]
        @test multi_region_sys_with_attrs["Region B"].storages.indices == stor_regions[2]

        @test multi_region_sys_with_attrs["Region A"].generatorstorages.indices == genstor_regions[1]
        @test multi_region_sys_with_attrs["Region B"].generatorstorages.indices == genstor_regions[2]

        io = IOBuffer()
        show(io, "text/plain", multi_region_sys_with_attrs["Region A"])
        text = String(take!(io))
        @test occursin("Region:", text)
        @test occursin("Peak load:", text)
        @test occursin("Generators:", text)
        @test occursin("Storages:", text)
        @test occursin("GeneratorStorages:", text)

        @test_throws "Asset type Lines is not supported. Supported types are: Generators, Storages, GeneratorStorages" multi_region_sys_with_attrs["Region A", Lines]
    end
end

