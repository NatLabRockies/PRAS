using Revise
using PRAS
using PRASReport

rts_sys = rts_gmlc()
rts_sys.regions.load .+= 375

sf, flow, events = assess(
    rts_sys,
    SequentialMonteCarlo(samples=100),
    Shortfall(),
    Flow(),
    ShortfallEvents(),
)

create_pras_report(
    sf,
    flow,
    events;
    report_name="example_rts_report",
    title="RTS-GMLC (load modified) RA Report",
)