window.loadSimulationInfo = async function(conn) {
    const result = await conn.query(`
        SELECT n_samples, step_size, time_unit, energy_unit, timesteps,
               start_timestamp, end_timestamp, timezone,
               lole_mean, lole_stderr, neue_mean, neue_stderr,
               eue_mean, eue_stderr
        FROM report_db.systemsiminfo
        LIMIT 1
    `);
    return result.toArray()[0];
};

window.loadSystemEventMetrics = async function(conn) {
    const result = await conn.query(`
        SELECT
            n_events,
            lolev_mean,
            lolev_stderr,
            mean_duration,
            mean_duration_stderr,
            max_duration,
            max_duration_stderr,
            mean_energy,
            mean_energy_stderr,
            max_energy,
            max_energy_stderr
        FROM report_db.event_metrics
        WHERE scope = 'system'
        LIMIT 1
    `);

    return result.toArray()[0];
};

window.loadSystemShortfallEvents = async function(conn) {
    const result = await conn.query(`
        SELECT
            e.id,
            e.sample_id,
            e.scope,
            e.region_id,
            NULL AS region_name,
            e.start_timestamp,
            e.end_timestamp,
            e.duration_periods,
            e.energy
        FROM report_db.shortfall_events e
        WHERE e.scope = 'system'
        ORDER BY e.start_timestamp
    `);
    return result.toArray();
};

window.loadRegionalShortfallEvents = async function(conn) {
    const result = await conn.query(`
        SELECT
            e.id,
            e.sample_id,
            e.scope,
            e.region_id,
            r.name AS region_name,
            e.start_timestamp,
            e.end_timestamp,
            e.duration_periods,
            e.energy
        FROM report_db.shortfall_events e
        LEFT JOIN report_db.regions r ON e.region_id = r.id
        WHERE e.scope = 'region'
        ORDER BY r.name, e.start_timestamp
    `);
    return result.toArray();
};

window.loadSystemPlotEvents = async function(conn) {
    const result = await conn.query(`
        SELECT
            e.sample_id,
            e.duration_periods * s.step_size AS duration,
            CAST(e.energy AS DOUBLE) AS energy
        FROM report_db.shortfall_events e
        CROSS JOIN (SELECT step_size FROM report_db.systemsiminfo LIMIT 1) s
        WHERE e.scope = 'system'
        ORDER BY e.start_timestamp
    `);

    const rows = result.toArray();

    return {
        duration: rows.map(r => r.duration),
        energy: rows.map(r => r.energy),
        sample_id: rows.map(r => r.sample_id)
    };
};

window.loadRegionalPlotEvents = async function(conn) {
    const result = await conn.query(`
        SELECT
            r.name AS region_name,
            e.sample_id,
            e.duration_periods * s.step_size AS duration,
            CAST(e.energy AS DOUBLE) AS energy
        FROM report_db.shortfall_events e
        CROSS JOIN (SELECT step_size FROM report_db.systemsiminfo LIMIT 1) s
        LEFT JOIN report_db.regions r ON e.region_id = r.id
        WHERE e.scope = 'region'
        ORDER BY r.name, e.start_timestamp
    `);

    const rows = result.toArray();
    const byRegion = new Map();

    rows.forEach(r => {
        const region = r.region_name || "Unknown";

        if (!byRegion.has(region)) {
            byRegion.set(region, {
                duration: [],
                energy: [],
                sample_id: []
            });
        }

        const group = byRegion.get(region);
        group.duration.push(r.duration);
        group.energy.push(r.energy);
        group.sample_id.push(r.sample_id);
    });

    return byRegion;
};

window.loadSystemTableEvents = async function(conn, limitRows) {
    const result = await conn.query(`
        SELECT
            e.id,
            e.sample_id,
            e.scope,
            e.region_id,
            NULL AS region_name,
            e.start_timestamp,
            e.end_timestamp,
            e.duration_periods,
            e.energy
        FROM report_db.shortfall_events e
        WHERE e.scope = 'system'
        ORDER BY e.start_timestamp
        LIMIT ${Number(limitRows)}
    `);
    return result.toArray();
};

window.loadRegionalTableEvents = async function(conn, limitRows) {
    const result = await conn.query(`
        SELECT
            e.id,
            e.sample_id,
            e.scope,
            e.region_id,
            r.name AS region_name,
            e.start_timestamp,
            e.end_timestamp,
            e.duration_periods,
            e.energy
        FROM report_db.shortfall_events e
        LEFT JOIN report_db.regions r ON e.region_id = r.id
        WHERE e.scope = 'region'
        ORDER BY r.name, e.start_timestamp
        LIMIT ${Number(limitRows)}
    `);
    return result.toArray();
};

window.loadRegionalEventMetricsTable = async function(conn) {
    const result = await conn.query(`
        SELECT
            r.name AS region_name,
            m.n_events,
            m.lolev_mean,
            m.lolev_stderr,
            m.mean_duration,
            m.mean_duration_stderr,
            m.max_duration,
            m.max_duration_stderr,
            m.mean_energy,
            m.mean_energy_stderr,
            m.max_energy,
            m.max_energy_stderr
        FROM report_db.event_metrics m
        LEFT JOIN report_db.regions r ON m.region_id = r.id
        WHERE m.scope = 'region'
        ORDER BY r.name
    `);
    return result.toArray();
};

window.loadRegionalMCMetrics = async function(conn) {
    const result = await conn.query(`
        SELECT
            r.name AS region_name,
            m.eue_mean,
            m.eue_stderr,
            m.lole_mean,
            m.lole_stderr,
            m.neue_mean,
            m.neue_stderr
        FROM report_db.mc_regional_metrics m
        LEFT JOIN report_db.regions r ON m.region_id = r.id
        ORDER BY r.name
    `);
    return result.toArray();
};

window.loadSystemShortfallHeatmap = async function(conn) {
    const result = await conn.query(`
        SELECT
            month(timestamp) AS month,
            hour(timestamp) AS hour,
            SUM(mean_shortfall) AS mean_shortfall
        FROM report_db.shortfall_mean_timeseries
        GROUP BY month, hour
        ORDER BY month, hour
    `);
    return result.toArray();
};

window.loadRegionalShortfallHeatmaps = async function(conn) {
    const result = await conn.query(`
        SELECT
            r.name AS region_name,
            month(s.timestamp) AS month,
            hour(s.timestamp) AS hour,
            AVG(s.mean_shortfall) AS mean_shortfall
        FROM report_db.shortfall_mean_timeseries s
        LEFT JOIN report_db.regions r ON s.region_id = r.id
        GROUP BY r.name, month, hour
        ORDER BY r.name, month, hour
    `);
    return result.toArray();
};

window.hasFullYearShortfallHeatmapData = async function(conn) {
    const result = await conn.query(`
        SELECT COUNT(DISTINCT month(timestamp)) AS n_months
        FROM report_db.shortfall_mean_timeseries
    `);

    return Number(result.toArray()[0].n_months) === 12;
};