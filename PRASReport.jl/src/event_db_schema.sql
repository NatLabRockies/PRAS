-- System and Simulation parameters 
CREATE TABLE systemsiminfo (
    timesteps INTEGER,
    step_size INTEGER NOT NULL,
    time_unit TEXT NOT NULL,
    power_unit TEXT NOT NULL,
    energy_unit TEXT NOT NULL,
    start_timestamp TIMESTAMP WITHOUT TIME ZONE,
    end_timestamp TIMESTAMP WITHOUT TIME ZONE,
    timezone TEXT,
    n_samples INTEGER,
    eue_mean REAL NOT NULL,
    eue_stderr REAL NOT NULL,
    lole_mean REAL NOT NULL,
    lole_stderr REAL NOT NULL,
    neue_mean REAL NOT NULL,
    neue_stderr REAL NOT NULL,
    eventthreshold INTEGER NOT NULL,
    
    -- Constraint to ensure valid ISO 8601 duration units
    CONSTRAINT valid_time_unit CHECK (
        time_unit IN ('Year', 'Day', 'Hour', 'Minute', 'Second')
    )
);

-- Regions lookup table
CREATE TABLE regions (
    id INTEGER PRIMARY KEY,
    name TEXT UNIQUE NOT NULL
);

-- Interfaces lookup table (region to region connections)
CREATE TABLE interfaces (
    id INTEGER PRIMARY KEY,
    region_from_id INTEGER REFERENCES regions(id),
    region_to_id INTEGER REFERENCES regions(id),
    name TEXT, -- name like "Region1->Region2"
    UNIQUE(region_from_id, region_to_id)
);

-- Main events table (clean, no parameters)
CREATE SEQUENCE eventid_sequence START 1;
CREATE TABLE events (
    id INTEGER PRIMARY KEY DEFAULT nextval('eventid_sequence'),
    name TEXT NOT NULL,
    start_timestamp TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    end_timestamp TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    time_period_count INTEGER NOT NULL   -- N parameter
);

-- System-level metrics for each event (aggregated)
CREATE TABLE event_system_shortfall (
    event_id INTEGER REFERENCES events(id),
    lole REAL NOT NULL,
    eue REAL NOT NULL,
    neue REAL NOT NULL,
    PRIMARY KEY (event_id)
);

-- Regional metrics for each event (aggregated)
CREATE TABLE event_regional_shortfall (
    id INTEGER PRIMARY KEY,
    event_id INTEGER REFERENCES events(id),
    region_id INTEGER REFERENCES regions(id),
    lole REAL NOT NULL,
    eue REAL NOT NULL,
    neue REAL NOT NULL,
    UNIQUE(event_id, region_id)
);

-- Time-series metrics for each timestamp within an event (from sf_ts struct)
-- Optimized with better data types and ordering for columnar storage
CREATE TABLE event_timeseries_shortfall (
    event_id INTEGER NOT NULL,
    region_id INTEGER NOT NULL,
    timestamp_value TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    lole REAL NOT NULL,
    eue REAL NOT NULL,
    neue REAL NOT NULL,
    FOREIGN KEY (event_id) REFERENCES events(id),
    FOREIGN KEY (region_id) REFERENCES regions(id),
    PRIMARY KEY (event_id, region_id, timestamp_value)
);

-- Flow data for each timestamp within an event (from flow_ts struct)
-- Optimized with better data types and ordering for columnar storage
CREATE TABLE event_timeseries_flows (
    event_id INTEGER NOT NULL,
    interface_id INTEGER NOT NULL,
    timestamp_value TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    flow REAL NOT NULL, -- Flow value (NEUE units)
    FOREIGN KEY (event_id) REFERENCES events(id),
    FOREIGN KEY (interface_id) REFERENCES interfaces(id),
    PRIMARY KEY (event_id, interface_id, timestamp_value)
);