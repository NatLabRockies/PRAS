module PRASReport

import PRASCore.Systems: SystemModel, Regions, Interfaces,
                            Generators, Storages, GeneratorStorages, Lines,
                            timeunits, powerunits, energyunits, unitsymbol,
                            unitsymbol_long, conversionfactor
import PRASCore.Simulations: assess, SequentialMonteCarlo
import PRASCore.Results: EUE, LOLE, NEUE,
                            Shortfall, Flow,
                            ShortfallResult, FlowResult,
                            ShortfallSamplesResult, AbstractShortfallResult, 
                            Result, MeanEstimate, findfirstunique,
                            val, stderror, totalevents,
                            ShortfallEvents, ShortfallEventsResult,
                            ShortfallEvent, LOLEv,
                            MeanEventDuration, MaxEventDuration,
                            MeanEventEnergy, MaxEventEnergy
import PRASFiles: SystemModel
import StatsBase: mean
import Dates: @dateformat_str, format, now, DateTime
import TimeZones: ZonedDateTime, @tz_str, TimeZone
import Base64: base64encode
import Tables: columntable
import DuckDB

export 
    get_db, create_pras_report

include("writedb.jl")
include("report.jl")

end
