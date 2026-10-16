@testset "String input to create_pras_report" begin
    system_path = joinpath(@__DIR__, "../../PRASFiles.jl/src/Systems/rts.pras")

    string_test = @capture_out begin
        create_pras_report(system_path, samples=1000, seed=1, 
                            report_name="string_test")
    end
    string_test = strip(string_test)
    @test startswith(string_test,"Writing report to:")
    @test contains(string_test, "string_test.html")
    string_test = replace(string_test, r"Writing report to: " => "")
    @test isfile(string_test)
    rm(string_test; force=true)
end

@testset "SystemModel input to create_pras_report" begin
    string_test = @capture_out begin
        create_pras_report(system, samples=1000, seed=1, 
                            report_name="sysmodel_test")
    end
    string_test = strip(string_test)
    @test startswith(string_test,"Writing report to:")
    @test contains(string_test, "sysmodel_test.html")
    string_test = replace(string_test, r"Writing report to: " => "")
    @test isfile(string_test)
    rm(string_test, force=true)
end

@testset "ShortfallResult, FlowResult input to create_pras_report" begin
    sf,flow = assess(system,SequentialMonteCarlo(samples=1000,seed=1),
                        Shortfall(),Flow())
    
    string_test = @capture_out begin
        create_pras_report(sf,flow,  
                            report_name="sfflow_test")
    end
    string_test = strip(string_test)
    @test startswith(string_test,"Writing report to:")
    @test contains(string_test, "sfflow_test.html")
    string_test = replace(string_test, r"Writing report to: " => "")
    @test isfile(string_test)
    rm(string_test, force=true)
end
