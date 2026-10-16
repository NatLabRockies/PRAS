module PRASReport

import PRASCore.Systems: SystemModel, Regions, Interfaces,
                            Generators, Storages, GeneratorStorages, Lines,
                            timeunits, powerunits, energyunits, unitsymbol,
                            unitsymbol_long             
import PRASCore.Simulations: assess, SequentialMonteCarlo
import PRASCore.Results: EUE, LOLE, NEUE, 
                            Shortfall, Flow,
                            ShortfallResult, FlowResult,
                            ShortfallSamplesResult, AbstractShortfallResult, 
                            Result, MeanEstimate, findfirstunique,
                            val, stderror
import PRASFiles: SystemModel
import StatsBase: mean
import Dates: @dateformat_str, format, now, DateTime
import TimeZones: ZonedDateTime, @tz_str, TimeZone
import Base64: base64encode
import Tables: columntable
import DuckDB

export 
    Event, get_events, event_length, 
    Shortfall_timeseries, Flow_timeseries,
    get_db, create_pras_report

include("events.jl")
include("writedb.jl")
include("report.jl")

end # module PRASReport
