@testset "SystemModel input to create_pras_report" begin
    sys = deepcopy(system)
    sys.regions.load .+= 375

    report_dir = mktempdir()

    output = @capture_out begin
        create_pras_report(
            sys;
            samples=100,
            seed=1,
            report_name="sysmodel_test",
            report_path=report_dir,
            title="Test Report",
        )
    end

    report_path = joinpath(report_dir, "sysmodel_test.html")

    @test contains(output, "Writing report to:")
    @test isfile(report_path)

    html = read(report_path, String)
    @test contains(html, "Test Report")
    @test contains(html, "Monte Carlo Average Results")
    @test contains(html, "System-Level Results")
    @test contains(html, "Region-Level Results")
    @test contains(html, "Adequacy Events")
    @test contains(html, "System-Level Events")
    @test contains(html, "Region-Level Events")
end

@testset "Result input to create_pras_report" begin
    sys = deepcopy(system)
    sys.regions.load .+= 375

    sf, flow, events = assess(
        sys,
        SequentialMonteCarlo(samples=100, seed=1),
        Shortfall(),
        Flow(),
        ShortfallEvents(),
    )

    report_dir = mktempdir()

    output = @capture_out begin
        create_pras_report(
            sf,
            flow,
            events;
            report_name="results_test",
            report_path=report_dir,
            title="Results Test Report",
        )
    end

    report_path = joinpath(report_dir, "results_test.html")

    @test contains(output, "Writing report to:")
    @test isfile(report_path)

    html = read(report_path, String)
    @test contains(html, "Results Test Report")
    @test contains(html, "Monte Carlo Average Results")
    @test contains(html, "Regional Mean Shortfall by Month and Hour")
end