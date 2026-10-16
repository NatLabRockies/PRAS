"""
    get_db(sf::ShortfallResult{N,L,T,E},
            flow::FlowResult{N,L,T,P}=nothing;
            conn::DuckDB.Connection=nothing,
            threshold=0)

Extract events from PRAS results and write them to database.
Returns the database connection if provided.
If connection is not provided, it creates and writes to a .duckdb
database in the working directory of REPL or the julia call.

# Arguments
- `system::SystemModel`: PRAS system
- `conn::Union{DuckDB.Connection,Nothing}`: DuckDB database connection (default: nothing)
- `threshold`: Event threshold (default: 0)
"""
function get_db(sf::ShortfallResult{N,L,T,E},
                flow::Union{FlowResult{N,L,T,P},Nothing}=nothing;
                conn::Union{DuckDB.Connection,Nothing}=nothing,
                threshold=0, 
                samples=nothing, seed=nothing) where {N,L,T,P,E}
    
    if isnothing(conn)
        timenow = format(now(tz"UTC"), @dateformat_str"yyyy-mm-dd_HHMMSSZZZ")
        dbfile = DuckDB.open(joinpath(pwd(), "$(timenow).duckdb"))
        conn = DuckDB.connect(dbfile)
        internal_conn = true
    else
        internal_conn = false  
    end
    

    # Load in DB schema
    schema_file = joinpath(dirname(@__FILE__), "event_db_schema.sql")
    schema_sql = read(schema_file, String)

    # Split schema into individual statements and execute each one
    # Remove SQL comments (lines starting with --)
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

    # Write system & simulation parameters to database
    _write_db!(sf, flow, threshold, conn)
    
    # Write region names to database
    _write_db!(sf.regions.names, conn)

    # Extract events from shortfall results
    events = get_events(sf,threshold)
    
    # Write events to database (events, system metrics, regional metrics)
    foreach(event -> _write_db!(event,conn), events)
    
    # Write time-series shortfall data for each event
    sf_timeseries_allevents = Shortfall_timeseries.(events, sf)
    foreach(sf_ts -> _write_db!(sf_ts,conn), sf_timeseries_allevents)
    
    # Write flow data if provided
    if !isnothing(flow)
        _write_db!(flow.interfaces, conn) 
        flow_timeseries_allevents = Flow_timeseries.(events, flow)
        foreach(flow_ts -> _write_db!(flow_ts,conn), flow_timeseries_allevents)
    end

    if internal_conn
        DuckDB.DBInterface.close!(conn)
        DuckDB.close_database(dbfile)
        return
    else
        return conn
    end

end

"""
    get_db(system::SystemModel; 
            conn::Union{DuckDB.Connection,Nothing}=nothing,
            threshold=0,
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
                threshold=0,
                samples=1000,
                seed=1)
    
    # Run assessment with both Shortfall and Flow specifications
    sf_result,flow_result = assess(system,
                    SequentialMonteCarlo(samples=samples,seed=seed),
                    Shortfall(),Flow()
                    ); 
    
    # Call the main get_db function with the assessment results
    return get_db(sf_result, flow_result; conn=conn, threshold=threshold)
end

"""
    get_db(system_path::AbstractString; 
            conn::Union{DuckDB.Connection,Nothing}=nothing,
            threshold=0,
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
                threshold=0,
                samples=1000,
                seed=1)
    
    # Load the system model from file
    system = SystemModel(system_path)
    
    # Call the SystemModel dispatch version
    return get_db(system; conn=conn, threshold=threshold, samples=samples, seed=seed)
end

# ============================================================================
# Write functions - system, simulation global info
# ============================================================================
"""
    _write_db!(::ShortfallResult{N,L,T,E}, ::FlowResult{N,L,T,P}, 
    threshold::Int, conn::DuckDB.Connection)

Write system and simulation parameters to the parameters table.
"""
function _write_db!(sf::ShortfallResult{N,L,T,E}, 
                    ::FlowResult{N,L,T,P},
                    threshold::Int64, 
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
            DuckDB.append(appender, threshold)
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

# ============================================================================
# Write functions - events, event metrics, event time-series
# ============================================================================
"""
    _write_db!(events::Vector{Event}, conn::DuckDB.Connection)

Write a vector of Event objects to the database using DuckDB Appender API for efficient bulk inserts.
Writes to: events, event_system_shortfall, event_regional_shortfall tables.
"""
function _write_db!(events::Vector{Event}, conn::DuckDB.Connection)
    # Write each event individually to avoid memory issues with large datasets
    for event in events
        _write_db!(event, conn)
    end
end

"""
    _write_db!(event::Event, conn::DuckDB.Connection)

Write a single Event object to the database.
"""
function _write_db!(event::Event{N,L,T,E}, conn::DuckDB.Connection) where {N,L,T,E}
    # Get region IDs in the same order as event.regions array
    region_ids = get_region_ids_ordered(event.regions, conn)
        
    # Extract start and end timestamps
    start_ts = DateTime(first(event.timestamps))
    end_ts = DateTime(last(event.timestamps))
    time_period_count = length(event.timestamps)
    
    result = DuckDB.execute(conn, 
                    "INSERT INTO events (name, start_timestamp, end_timestamp, 
                    time_period_count) VALUES (?, ?, ?, ?)
                    RETURNING id",
                    [event.name, start_ts, end_ts, time_period_count]
                    ) |> columntable

    event_id = first(result.id)
    
    # Insert system-level metrics using Appender API
    appender_system = DuckDB.Appender(conn, "event_system_shortfall")
    try
        DuckDB.append(appender_system, event_id)
        DuckDB.append(appender_system, val(event.system_lole))
        DuckDB.append(appender_system, val(event.system_eue))
        DuckDB.append(appender_system, val(event.system_neue))
        DuckDB.end_row(appender_system)
        DuckDB.flush(appender_system)
    finally
        DuckDB.close(appender_system)
    end

    # Insert regional metrics using Appender API

    appender_regions = DuckDB.Appender(conn, "event_regional_shortfall")    
    try
        for (i, region_id) in enumerate(region_ids)
            # Append row: event_id, region_id, lole, eue, neue
            # Note: skipping the 'id' column since it's auto-generated
            DuckDB.append(appender_regions, event_id)
            DuckDB.append(appender_regions, region_id)
            DuckDB.append(appender_regions, val(event.lole[i]))
            DuckDB.append(appender_regions, val(event.eue[i]))
            DuckDB.append(appender_regions, val(event.neue[i]))
            DuckDB.end_row(appender_regions)
        end
        
        DuckDB.flush(appender_regions)
        
    finally
        DuckDB.close(appender_regions)
    end

    return 
end

"""
    _write_db!(sf_ts::Shortfall_timeseries, conn::DuckDB.Connection)

Write event shortfall time-series data to event_timeseries_shortfall table.
Gets the event_id from the database using the event name for consistency.
"""
function _write_db!(sf_ts::Shortfall_timeseries, conn::DuckDB.Connection)
    # Get event_id from database using event name
    event_result = DuckDB.execute(conn, "SELECT id FROM events WHERE name = ?", 
                        [sf_ts.name]) |> columntable
    isempty(event_result) &&
        error("Event '$(sf_ts.name)' not found in database. Write the event first.")
    event_id = first(event_result.id)

    # Get region IDs in the same order as sf_ts.regions array
    region_ids = get_region_ids_ordered(sf_ts.regions, conn)
    
    # Use Appender for efficient bulk insert
    appender = DuckDB.Appender(conn, "event_timeseries_shortfall")
    try
        # Iterate through timestamps and regions
        for (t_idx, timestamp) in enumerate(sf_ts.timestamps)
            for (r_idx, region_id) in enumerate(region_ids)
                # Append row: event_id, region_id, timestamp_value, lole, eue, neue
                DuckDB.append(appender, event_id)
                DuckDB.append(appender, region_id)
                DuckDB.append(appender, DateTime(timestamp))
                DuckDB.append(appender, sf_ts.lole[t_idx][r_idx])
                DuckDB.append(appender, sf_ts.eue[t_idx][r_idx])
                DuckDB.append(appender, sf_ts.neue[t_idx][r_idx])
                DuckDB.end_row(appender)
            end
        end
        
        DuckDB.flush(appender)
        
    finally
        DuckDB.close(appender)
    end
end

"""
    _write_db!(flow_ts::flow_ts, conn::DuckDB.Connection)

Write event flow time-series data to event_timeseries_flows table.
"""
function _write_db!(flow_ts::Flow_timeseries, conn::DuckDB.Connection)

    # Get event_id from database using event name
    event_result = DuckDB.execute(conn, "SELECT id FROM events WHERE name = ?", 
                        [flow_ts.name]) |> columntable
    isempty(event_result) &&
        error("Event '$(flow_ts.name)' not found in database. Write the event first.")
    event_id = first(event_result.id)

    # Get interface IDs in the same order as flow_ts.interfaces array
    interface_ids = get_interface_ids_ordered(flow_ts.interfaces, conn)
    
    # Use Appender for efficient bulk insert
    appender = DuckDB.Appender(conn, "event_timeseries_flows")
    try
        # Iterate through timestamps and interfaces
        for (t_idx, timestamp) in enumerate(flow_ts.timestamps)
            for (i_idx, interface_id) in enumerate(interface_ids)
                # Append row: event_id, interface_id, timestamp_value, flow
                DuckDB.append(appender, event_id)
                DuckDB.append(appender, interface_id)
                DuckDB.append(appender, DateTime(timestamp))
                DuckDB.append(appender, flow_ts.flow[t_idx][i_idx]) # Extract value from NEUE
                DuckDB.end_row(appender)
            end
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

