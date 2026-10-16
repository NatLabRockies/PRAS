@testset "Test get_stepranges" begin
    timestamps = ZonedDateTime.(DateTime(2023,1,1,1):Hour(1):DateTime(2023,1,1,11), tz"UTC")
    selected_times = [timestamps[2], timestamps[3], timestamps[5], timestamps[6], timestamps[7], timestamps[9]]
    step_ranges = PRASReport.get_stepranges(selected_times, 1, Hour)

    @test length(step_ranges) == 3
    @test step_ranges[1] == (timestamps[2]:Hour(1):timestamps[3])
    @test step_ranges[2] == (timestamps[5]:Hour(1):timestamps[7])
    @test step_ranges[3] == (timestamps[9]:Hour(1):timestamps[9])
end

@testset "Test get_events" begin
    sf,flow = assess(system,SequentialMonteCarlo(samples=100),Shortfall(),Flow());

    @test_throws "No shortfall events in this simulation" get_events(sf)

end