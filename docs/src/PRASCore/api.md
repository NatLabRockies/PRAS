# PRASCore API reference

## Systems
```@docs
PRASCore.Systems.SystemModel
PRASCore.Systems.Regions
PRASCore.Systems.Generators
PRASCore.Systems.Storages
PRASCore.Systems.GeneratorStorages
PRASCore.Systems.DemandResponses
PRASCore.Systems.Lines
PRASCore.Systems.Interfaces
```

## Simulations
```@autodocs
Modules = [PRASCore.Simulations]
Order = [:function,:type]
```

## Results
```@docs
PRASCore.Results.LOLE
PRASCore.Results.EUE
PRASCore.Results.NEUE
PRASCore.Results.Shortfall
PRASCore.Results.ShortfallSamples
PRASCore.Results.Surplus
PRASCore.Results.SurplusSamples
PRASCore.Results.Flow
PRASCore.Results.FlowSamples
PRASCore.Results.Utilization
PRASCore.Results.UtilizationSamples
PRASCore.Results.GeneratorAvailability
PRASCore.Results.GeneratorStorageAvailability
PRASCore.Results.GeneratorStorageEnergy
PRASCore.Results.GeneratorStorageEnergySamples
PRASCore.Results.StorageAvailability
PRASCore.Results.StorageEnergy
PRASCore.Results.StorageEnergySamples
PRASCore.Results.DemandResponseAvailability
PRASCore.Results.DemandResponseEnergy
PRASCore.Results.DemandResponseEnergySamples
PRASCore.Results.LineAvailability
PRASCore.Results.CVAR
PRASCore.Results.NCVAR
```
