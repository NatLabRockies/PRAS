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
    neue_stderr REAL NOT NULL
    
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

CREATE TABLE shortfall_events (
    id INTEGER PRIMARY KEY,
    sample_id INTEGER NOT NULL,
    scope TEXT NOT NULL,
    region_id INTEGER,
    start_timestamp TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    end_timestamp TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    duration_periods INTEGER NOT NULL,
    energy REAL NOT NULL
);

CREATE TABLE event_metrics (
    scope TEXT NOT NULL,
    region_id INTEGER REFERENCES regions(id),
    n_events INTEGER NOT NULL,

    lolev_mean REAL NOT NULL,
    lolev_stderr REAL NOT NULL,

    mean_duration REAL NOT NULL,
    mean_duration_stderr REAL NOT NULL,

    max_duration REAL NOT NULL,
    max_duration_stderr REAL NOT NULL,

    mean_energy REAL NOT NULL,
    mean_energy_stderr REAL NOT NULL,

    max_energy REAL NOT NULL,
    max_energy_stderr REAL NOT NULL
);

CREATE TABLE mc_regional_metrics (
    region_id INTEGER REFERENCES regions(id),
    eue_mean REAL NOT NULL,
    eue_stderr REAL NOT NULL,
    lole_mean REAL NOT NULL,
    lole_stderr REAL NOT NULL,
    neue_mean REAL NOT NULL,
    neue_stderr REAL NOT NULL
);

CREATE TABLE shortfall_mean_timeseries (
    timestamp TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    region_id INTEGER REFERENCES regions(id),
    mean_shortfall REAL NOT NULL
);