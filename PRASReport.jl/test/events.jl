@testset "ShortfallEvents are written to database" begin
    sys = deepcopy(system)
    sys.regions.load .+= 375

    conn = DuckDB.connect(DuckDB.open(":memory:"))

    PRASReport.get_db(sys; conn=conn, samples=100, seed=1)

    count_result = Tables.columntable(
        DuckDB.execute(conn, "SELECT COUNT(*) AS n FROM shortfall_events")
    )

    @test first(count_result.n) > 0

    scope_result = Tables.columntable(
        DuckDB.execute(conn, "SELECT scope, COUNT(*) AS n FROM shortfall_events GROUP BY scope")
    )

    @test "system" in scope_result.scope
    @test "region" in scope_result.scope

    sanity_result = Tables.columntable(
        DuckDB.execute(conn, """
            SELECT
                MIN(duration_periods) AS min_duration,
                MIN(energy) AS min_energy
            FROM shortfall_events
        """)
    )

    @test first(sanity_result.min_duration) >= 1
    @test first(sanity_result.min_energy) >= 0

    DuckDB.DBInterface.close!(conn)
end