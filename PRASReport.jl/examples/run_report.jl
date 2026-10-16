using Revise
using PRAS
using PRASReport

rts_sys = rts_gmlc();
rts_sys.regions.load .+= 375;

sf,flow = assess(rts_sys,SequentialMonteCarlo(samples=100),Shortfall(),Flow());

create_pras_report(sf,flow, report_name="rts_report", 
                    title="RTS-GMLC (load modified) RA Report", 
                    threshold=1)