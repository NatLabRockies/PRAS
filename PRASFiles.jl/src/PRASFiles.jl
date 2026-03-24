module PRASFiles

import PRASCore.Systems: SystemModel, Regions, Interfaces,
                         Generators, Storages, GeneratorStorages, DemandResponses, Lines,
                         timeunits, powerunits, energyunits, unitsymbol

import PRASCore.Results: EUE, LOLE, NEUE, LOLD, ShortfallResult, ShortfallSamplesResult, AbstractShortfallResult, Result
import StatsBase: mean
import Dates: @dateformat_str, format, now
import TimeZones: ZonedDateTime
import HDF5: HDF5, attributes, File, Group, Dataset, Datatype, dataspace,
             h5open, create_group, create_dataset, hdf5_type_id
import HDF5.API: h5t_create, h5t_copy, h5t_insert, h5t_set_size,
                 H5T_COMPOUND, h5d_write, H5S_ALL, H5P_DEFAULT

import StructTypes: StructType, Struct, OrderedStruct
import JSON3: pretty

export savemodel
export saveshortfall
export read_attrs

include("Systems/read.jl")
include("Systems/write.jl")
include("Systems/utils.jl")
include("Results/utils.jl")
include("Results/write.jl")

function toymodel()
    path = dirname(@__FILE__)
    return SystemModel(joinpath(path, "Systems","toymodel.pras")) 
end

function rts_gmlc()
    path = dirname(@__FILE__)
    return SystemModel(joinpath(path, "Systems","rts.pras")) 
end

export toymodel,rts_gmlc

end
