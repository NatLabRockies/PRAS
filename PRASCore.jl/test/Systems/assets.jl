@testset verbose = true "Assets" begin

    names = ["A1", "A2", "B1"]
    categories = ["A", "A", "B"]

    vals_int   = rand(1:100, 3, 10)
    vals_float = rand(3, 10)

    @testset "Generators" begin

        gens = Generators{10,1,Hour,MW}(
            names, categories, vals_int, vals_float, vals_float)
        @test gens isa Generators
        @test_throws AssertionError Generators{5,1,Hour,MW}(
            names, categories, vals_int, vals_float, vals_float)

        @test_throws AssertionError Generators{10,1,Hour,MW}(
            names[1:2], categories, vals_int, vals_float, vals_float)

        @test_throws AssertionError Generators{10,1,Hour,MW}(
            names[1:2], categories[1:2], vals_int, vals_float, vals_float)

        @test_throws AssertionError Generators{10,1,Hour,MW}(
            names, categories, -vals_int, vals_float, vals_float)

        @testset "Printing" begin
            io = IOBuffer()
            show(io, "text/plain", gens)
            text = String(take!(io))
            @test occursin("$(length(names)) Generators:", text)
            @test occursin("Category", text)
            @test occursin("Count", text)
        end

        @testset "Indexing" begin
            @test_throws "Names must be unique." gens[["A1","A1"]]
            @test_throws "'A3' not found." gens["A3"]
            @test_throws "One or more names not found." gens[["A3"]]
            @test_throws "One or more names not found." gens[["A1","A2","A3"]]
            @test all(gens["A1"].capacity[1,:] .== vals_int[1,:])
        end

    end

    @testset "Storages" begin

        stors = Storages{10,1,Hour,MW,MWh}(
            names, categories, vals_int, vals_int, vals_int,
            vals_float, vals_float, vals_float, vals_float, vals_float)
        @test stors isa Storages

        @test_throws AssertionError Storages{5,1,Hour,MW,MWh}(
            names, categories, vals_int, vals_int, vals_int,
            vals_float, vals_float, vals_float, vals_float, vals_float)

        @test_throws AssertionError Storages{10,1,Hour,MW,MWh}(
            names, categories[1:2], vals_int, vals_int, vals_int,
            vals_float, vals_float, vals_float, vals_float, vals_float)

        @test_throws AssertionError Storages{10,1,Hour,MW,MWh}(
            names[1:2], categories[1:2], vals_int, vals_int, vals_int,
            vals_float, vals_float, vals_float, vals_float, vals_float)

        @test_throws AssertionError Storages{10,1,Hour,MW,MWh}(
            names, categories, vals_int, vals_int, vals_int,
            vals_float, vals_float, -vals_float, vals_float, vals_float)

        @testset "Printing" begin
            io = IOBuffer()
            show(io, "text/plain", stors)
            text = String(take!(io))
            @test occursin("$(length(names)) Storages:", text)
            @test occursin("Category", text)
            @test occursin("Count", text)
        end

        @testset "Indexing" begin
            @test_throws "Names must be unique." stors[["A1","A1"]]
            @test_throws "'A3' not found." stors["A3"]
            @test_throws "One or more names not found." stors[["A3"]]
            @test_throws "One or more names not found." stors[["A1","A2","A3"]]
            @test all(stors["A1"].charge_capacity[1,:] .== vals_int[1,:])
        end

    end

    @testset "GeneratorStorages" begin

        gen_stors = GeneratorStorages{10,1,Hour,MW,MWh}(
            names, categories,
            vals_int, vals_int, vals_int, vals_float, vals_float, vals_float,
            vals_int, vals_int, vals_int, vals_float, vals_float)
        @test gen_stors isa GeneratorStorages

        @test_throws AssertionError GeneratorStorages{5,1,Hour,MW,MWh}(
            names, categories,
            vals_int, vals_int, vals_int, vals_float, vals_float, vals_float,
            vals_int, vals_int, vals_int, vals_float, vals_float)


        @test_throws AssertionError GeneratorStorages{10,1,Hour,MW,MWh}(
            names, categories[1:2],
            vals_int, vals_int, vals_int, vals_float, vals_float, vals_float,
            vals_int, vals_int, vals_int, vals_float, vals_float)

        @test_throws AssertionError GeneratorStorages{10,1,Hour,MW,MWh}(
            names[1:2], categories[1:2],
            vals_int, vals_int, vals_int, vals_float, vals_float, vals_float,
            vals_int, vals_int, vals_int, vals_float, vals_float)

        @test_throws AssertionError GeneratorStorages{10,1,Hour,MW,MWh}(
            names, categories,
            vals_int, vals_int, vals_int, vals_float, vals_float, -vals_float,
            vals_int, vals_int, vals_int, vals_float, vals_float)

        @testset "Printing" begin
            io = IOBuffer()
            show(io, "text/plain", gen_stors)
            text = String(take!(io))
            @test occursin("$(length(names)) GeneratorStorages:", text)
            @test occursin("Category", text)
            @test occursin("Count", text)
        end

        @testset "Indexing" begin
            @test_throws "Names must be unique." gen_stors[["A1","A1"]]
            @test_throws "'A3' not found." gen_stors["A3"]
            @test_throws "One or more names not found." gen_stors[["A3"]]
            @test_throws "One or more names not found." gen_stors[["A1","A2","A3"]]
            @test all(gen_stors["A1"].charge_capacity[1,:] .== vals_int[1,:])
        end
    end

    @testset "DemandResponses" begin

        DemandResponses{10,1,Hour,MW,MWh}(
            names, categories, vals_int, vals_int, vals_int,
            vals_float, vals_int, vals_float, vals_float, vals_float, vals_float)

        @test_throws AssertionError DemandResponses{5,1,Hour,MW,MWh}(
            names, categories, vals_int, vals_int, vals_int,
            vals_float, vals_int, vals_float, vals_float, vals_float, vals_float,)

        @test_throws AssertionError DemandResponses{10,1,Hour,MW,MWh}(
            names, categories[1:2], vals_int, vals_int, vals_int,
            vals_float, vals_int, vals_float, vals_float,vals_float, vals_float)

        @test_throws AssertionError DemandResponses{10,1,Hour,MW,MWh}(
            names[1:2], categories[1:2], vals_int, vals_int, vals_int,
            vals_float, vals_int, vals_float, vals_float,vals_float, vals_float)
    end

    @testset "Lines" begin

        lines = Lines{10,1,Hour,MW}(
            names, categories, vals_int, vals_int, vals_float, vals_float)
        @test lines isa Lines

        @test_throws AssertionError Lines{5,1,Hour,MW}(
            names, categories, vals_int, vals_int, vals_float, vals_float)

        @test_throws AssertionError Lines{10,1,Hour,MW}(
            names[1:2], categories, vals_int, vals_int, vals_float, vals_float)

        @test_throws AssertionError Lines{10,1,Hour,MW}(
            names[1:2], categories[1:2], vals_int, vals_int, vals_float, vals_float)

        @test_throws AssertionError Lines{10,1,Hour,MW}(
            names, categories, -vals_int, vals_int, vals_float, vals_float)

        @testset "Printing" begin
            io = IOBuffer()
            show(io, "text/plain", lines)
            text = String(take!(io))
            @test occursin("$(length(names)) Lines:", text)
            @test occursin("Category", text)
            @test occursin("Count", text)
        end
        
        @testset "Indexing" begin
            @test_throws "Names must be unique." lines[["A1","A1"]]
            @test_throws "'A3' not found." lines["A3"]
            @test_throws "One or more names not found." lines[["A3"]]
            @test_throws "One or more names not found." lines[["A1","A2","A3"]]
            @test all(lines["A1"].forward_capacity[1,:] .== vals_int[1,:])
        end
    end

end
