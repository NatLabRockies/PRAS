module PRASCapacityCredits

import PRASCore.Systems: Generators, PowerUnit, Regions, SystemModel, unitsymbol
import PRASCore.Simulations: assess, SequentialMonteCarlo
import PRASCore.Results: ReliabilityMetric, Result, Shortfall, stderror, val

import Base: minimum, maximum, extrema
import Distributions: ccdf, Normal

export EFC, EFC_Secant, ELCC, ELCC_Secant

abstract type CapacityValuationMethod{M<:ReliabilityMetric} end

include("utils.jl")
include("CapacityCreditResult.jl")
include("EFC.jl")
include("EFC_Secant.jl")
include("ELCC.jl")
include("ELCC_Secant.jl")

end
