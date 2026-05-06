"""
    get_db(system::SystemModel; 
            conn::Union{DuckDB.Connection,Nothing}=nothing,
            samples=1000,
            seed=1)

Perform PRAS simulation on the given system and write results to database
connection if provided or to a new database in the current working directory
from which function is called.

# Arguments
- `system::SystemModel`: PRAS system
- `samples`: Number of Monte Carlo samples (default: 1000)
- `seed`: Random seed for MC simulation (default: 1)
"""
function get_db(system::SystemModel; 
                conn::Union{DuckDB.Connection,Nothing}=nothing,
                samples=1000,
                seed=1)
    
    # Run assessment with both Shortfall and Flow specifications
    sf_result, flow_result, events_result = assess(system,
        SequentialMonteCarlo(samples=samples, seed=seed),
        Shortfall(), Flow(), ShortfallEvents()
    )
    
    # Call the main get_db function with the assessment results
    return get_db(sf_result, flow_result, events_result; conn=conn)
end

"""
    get_db(system_path::AbstractString; 
            conn::Union{DuckDB.Connection,Nothing}=nothing,
            samples=1000,
            seed=1)

Load a SystemModel from file path, perform PRAS simulation on the given system.
Write results to database connection if provided or to a new database in the 
current working directory from which function is called.

# Arguments
- `system_path::AbstractString`: Path to the .pras file
"""
function get_db(system_path::AbstractString; 
                conn::Union{DuckDB.Connection,Nothing}=nothing,
                samples=1000,
                seed=1)
    
    # Load the system model from file
    system = SystemModel(system_path)
    
    # Call the SystemModel dispatch version
    return get_db(system; conn=conn, samples=samples, seed=seed)
end

function get_db(
    sf::ShortfallResult{N,L,T,E},
    flow::Union{FlowResult{N,L,T,P},Nothing},
    events::ShortfallEventsResult;
    conn::Union{DuckDB.Connection,Nothing}=nothing,
    samples=nothing,
    seed=nothing,
) where {N,L,T,P,E}

    if isnothing(conn)
        timenow = format(now(tz"UTC"), @dateformat_str"yyyy-mm-dd_HHMMSSZZZ")
        dbfile = DuckDB.open(joinpath(pwd(), "$(timenow).duckdb"))
        conn = DuckDB.connect(dbfile)
        internal_conn = true
    else
        internal_conn = false
    end

    schema_file = joinpath(dirname(@__FILE__), "event_db_schema.sql")
    schema_sql = read(schema_file, String)

    schema_sql = join(filter(line -> !startswith(strip(line), "--"), split(schema_sql, '\n')), '\n')
    statements = split(schema_sql, ';')

    for stmt in statements
        stmt_clean = strip(stmt)
        if !isempty(stmt_clean) && !startswith(stmt_clean, "--")
            try
                DuckDB.DBInterface.execute(conn, stmt_clean)
            catch e
                println("Error executing statement: $stmt_clean")
                rethrow(e)
            end
        end
    end

    _write_db!(sf, flow, conn)
    _write_db!(sf.regions.names, conn)
    _write_db!(events, conn)
    _write_db_event_metrics!(events, conn)
    _write_db_mc_regional_metrics!(sf, conn)
    _write_db_shortfall_mean_timeseries!(sf, conn)

    if !isnothing(flow)
        _write_db!(flow.interfaces, conn)
    end

    if internal_conn
        DuckDB.DBInterface.close!(conn)
        DuckDB.close_database(dbfile)
        return
    else
        return conn
    end
end

# ============================================================================
# Write functions - system, simulation global info
# ============================================================================
"""
    _write_db!(::ShortfallResult{N,L,T,E}, ::FlowResult{N,L,T,P}, conn::DuckDB.Connection)

Write system and simulation parameters to the parameters table.
"""
function _write_db!(sf::ShortfallResult{N,L,T,E}, 
                    ::FlowResult{N,L,T,P},
                    conn::DuckDB.Connection) where {N,L,T,P,E}

    try
        
        appender = DuckDB.Appender(conn, "systemsiminfo")
        
        try
            DuckDB.append(appender, N)
            DuckDB.append(appender, L)
            DuckDB.append(appender, unitsymbol_long(T))
            DuckDB.append(appender, unitsymbol(P))
            DuckDB.append(appender, unitsymbol(E))
            DuckDB.append(appender, DateTime(first(sf.timestamps)))
            DuckDB.append(appender, DateTime(last(sf.timestamps)))
            DuckDB.append(appender, string(TimeZone(last(sf.timestamps))))
            DuckDB.append(appender, sf.nsamples)
            DuckDB.append(appender, val(EUE(sf)))
            DuckDB.append(appender, stderror(EUE(sf)))
            DuckDB.append(appender, val(LOLE(sf)))
            DuckDB.append(appender, stderror(LOLE(sf)))
            DuckDB.append(appender, val(NEUE(sf)))
            DuckDB.append(appender, stderror(NEUE(sf)))
            DuckDB.end_row(appender)
            DuckDB.flush(appender)
            
        finally
                DuckDB.close(appender)
        end
    catch e 
        rethrow(e)
    end
end

"""
    _write_db!(region_names::Vector{String}, conn::DuckDB.Connection)

Write regions to the regions table. Call this once to populate the regions table.
"""
function _write_db!(region_names::Vector{String}, conn::DuckDB.Connection)
    appender = DuckDB.Appender(conn, "regions")
    
    try
        for (idx, region_name) in enumerate(region_names)
            DuckDB.append(appender, idx)
            DuckDB.append(appender, region_name)
            DuckDB.end_row(appender)
        end
        
        DuckDB.flush(appender)
        
    finally
        DuckDB.close(appender)
    end
end

"""
    _write_db!(interfaces::Vector{Pair{String,String}}, conn::DuckDB.Connection)

Write interfaces from region pairs to the interfaces table. 
Each tuple should be (region_from, region_to).
Assumes all regions already exist in the regions table.
Call this once to populate the interfaces table.
"""
function _write_db!(interfaces::Vector{Pair{String,String}}, conn::DuckDB.Connection)
    # Get all region IDs and names once at the beginning
    regions_result = DuckDB.execute(conn, "SELECT id, name FROM regions") |> columntable
    region_name_to_id = Dict(zip(regions_result.name, regions_result.id))

    appender = DuckDB.Appender(conn, "interfaces")
    
    try
        for (idx, interface_pair) in enumerate(interfaces)
            region_from, region_to = interface_pair.first, interface_pair.second
            
            from_id = get(region_name_to_id, region_from, nothing)
            to_id = get(region_name_to_id, region_to, nothing)
            
            # Error if regions don't exist
            isnothing(from_id) && error("Region '$region_from' not found in database")
            isnothing(to_id) && error("Region '$region_to' not found in database")
            
            interface_name = "$region_from->$region_to"
    
            # Append row: id, region_from_id, region_to_id, name
            DuckDB.append(appender, idx)
            DuckDB.append(appender, from_id)
            DuckDB.append(appender, to_id)
            DuckDB.append(appender, interface_name)
            DuckDB.end_row(appender)
        end
        
        DuckDB.flush(appender)
        
    finally
        DuckDB.close(appender)
    end
end

function _write_db_mc_regional_metrics!(
    sf::ShortfallResult,
    conn::DuckDB.Connection
)
    region_ids = get_region_ids_ordered(sf.regions.names, conn)
    appender = DuckDB.Appender(conn, "mc_regional_metrics")

    try
        for (region_name, region_id) in zip(sf.regions.names, region_ids)
            eue = EUE(sf, region_name)
            lole = LOLE(sf, region_name)
            neue = NEUE(sf, region_name)

            DuckDB.append(appender, region_id)

            DuckDB.append(appender, val(eue))
            DuckDB.append(appender, stderror(eue))

            DuckDB.append(appender, val(lole))
            DuckDB.append(appender, stderror(lole))

            DuckDB.append(appender, val(neue))
            DuckDB.append(appender, stderror(neue))

            DuckDB.end_row(appender)
        end

        DuckDB.flush(appender)
    finally
        DuckDB.close(appender)
    end
end

function _write_db_shortfall_mean_timeseries!(
    sf::ShortfallResult{N,L,T,E},
    conn::DuckDB.Connection
) where {N,L,T,E}
    region_ids = get_region_ids_ordered(sf.regions.names, conn)

    appender = DuckDB.Appender(conn, "shortfall_mean_timeseries")

    try
        for (r, region_id) in enumerate(region_ids)
            for t in eachindex(sf.timestamps)
                DuckDB.append(appender, DateTime(sf.timestamps[t]))
                DuckDB.append(appender, region_id)
                DuckDB.append(appender, sf.shortfall_mean[r, t])
                DuckDB.end_row(appender)
            end
        end

        DuckDB.flush(appender)
    finally
        DuckDB.close(appender)
    end
end

# ============================================================================
# Write functions - events, event metrics, event time-series
# ============================================================================
function _write_db!(events::ShortfallEventsResult{N,L,T,P,E}, conn::DuckDB.Connection) where {N,L,T,P,E}
    region_ids = get_region_ids_ordered(events.regions.names, conn)
    p2e = conversionfactor(L, T, P, E)

    appender = DuckDB.Appender(conn, "shortfall_events")
    try
        id = 1

        for sample_id in eachindex(events.system_events)
            for ev in events.system_events[sample_id]
                DuckDB.append(appender, id)
                DuckDB.append(appender, sample_id)
                DuckDB.append(appender, "system")
                DuckDB.append(appender, missing)
                DuckDB.append(appender, DateTime(events.timestamps[ev.start_idx]))
                DuckDB.append(appender, DateTime(events.timestamps[ev.end_idx]))
                DuckDB.append(appender, ev.end_idx - ev.start_idx + 1)
                DuckDB.append(appender, p2e * ev.energy)
                DuckDB.end_row(appender)
                id += 1
            end
        end

        for (r, region_id) in enumerate(region_ids)
            for sample_id in axes(events.region_events, 2)
                for ev in events.region_events[r, sample_id]
                    DuckDB.append(appender, id)
                    DuckDB.append(appender, sample_id)
                    DuckDB.append(appender, "region")
                    DuckDB.append(appender, region_id)
                    DuckDB.append(appender, DateTime(events.timestamps[ev.start_idx]))
                    DuckDB.append(appender, DateTime(events.timestamps[ev.end_idx]))
                    DuckDB.append(appender, ev.end_idx - ev.start_idx + 1)
                    DuckDB.append(appender, p2e * ev.energy)
                    DuckDB.end_row(appender)
                    id += 1
                end
            end
        end

        DuckDB.flush(appender)
    finally
        DuckDB.close(appender)
    end
end

function _write_db_event_metrics!(
    events::ShortfallEventsResult,
    conn::DuckDB.Connection
)
    region_ids = get_region_ids_ordered(events.regions.names, conn)

    appender = DuckDB.Appender(conn, "event_metrics")

    try
        # System-level metrics
        lolev = LOLEv(events)
        mean_duration = MeanEventDuration(events)
        max_duration = MaxEventDuration(events)
        mean_energy = MeanEventEnergy(events)
        max_energy = MaxEventEnergy(events)

        DuckDB.append(appender, "system")
        DuckDB.append(appender, missing)
        DuckDB.append(appender, totalevents(events))

        DuckDB.append(appender, val(lolev))
        DuckDB.append(appender, stderror(lolev))

        DuckDB.append(appender, val(mean_duration))
        DuckDB.append(appender, stderror(mean_duration))

        DuckDB.append(appender, val(max_duration))
        DuckDB.append(appender, stderror(max_duration))

        DuckDB.append(appender, val(mean_energy))
        DuckDB.append(appender, stderror(mean_energy))

        DuckDB.append(appender, val(max_energy))
        DuckDB.append(appender, stderror(max_energy))

        DuckDB.end_row(appender)

        # Regional metrics
        for (region_name, region_id) in zip(events.regions.names, region_ids)
            lolev = LOLEv(events, region_name)
            mean_duration = MeanEventDuration(events, region_name)
            max_duration = MaxEventDuration(events, region_name)
            mean_energy = MeanEventEnergy(events, region_name)
            max_energy = MaxEventEnergy(events, region_name)

            DuckDB.append(appender, "region")
            DuckDB.append(appender, region_id)
            DuckDB.append(appender, totalevents(events, region_name))

            DuckDB.append(appender, val(lolev))
            DuckDB.append(appender, stderror(lolev))

            DuckDB.append(appender, val(mean_duration))
            DuckDB.append(appender, stderror(mean_duration))

            DuckDB.append(appender, val(max_duration))
            DuckDB.append(appender, stderror(max_duration))

            DuckDB.append(appender, val(mean_energy))
            DuckDB.append(appender, stderror(mean_energy))

            DuckDB.append(appender, val(max_energy))
            DuckDB.append(appender, stderror(max_energy))

            DuckDB.end_row(appender)
        end

        DuckDB.flush(appender)
    finally
        DuckDB.close(appender)
    end
end

# ============================================================================
# Helper Functions
# ============================================================================

"""
    get_region_ids_ordered(region_names::Vector{String}, conn::DuckDB.Connection) -> Vector{Int}

Get region IDs in the same order as the region_names array.
Assumes all regions exist in the database.
"""
function get_region_ids_ordered(region_names::Vector{String}, conn::DuckDB.Connection)
    region_ids = Vector{Int}()
    
    for region_name in region_names
        result = DuckDB.execute(conn, "SELECT id FROM regions WHERE name = ?", [region_name]) |> columntable  
        isempty(result) && error("Region '$region_name' not found in database")
        push!(region_ids, first(result.id))
    end

    return region_ids
end

"""
    get_interface_ids_ordered(interface_names::Vector{String}, conn::DuckDB.Connection) -> Vector{Int}

Get interface IDs in the same order as the interface_names array.
Assumes all interfaces exist in the database.
"""
function get_interface_ids_ordered(interface_names::Vector{Pair{String,String}}, conn::DuckDB.Connection)
    interface_ids = Vector{Int}()
    
    for interface_name in interface_names
        iname_db = "$(interface_name.first)->$(interface_name.second)"
        result = DuckDB.execute(conn, "SELECT id FROM interfaces WHERE name = ?", [iname_db]) |> columntable
        isempty(result) &&
            error("Interface '$interface_name' not found in database")
    
        push!(interface_ids, first(result.id))
    end
    
    return interface_ids
end

