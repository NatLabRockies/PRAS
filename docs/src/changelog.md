# Changelog

## [0.8.0], 2025 - October

- Add a demand response component which can model shift and shed type DR devices
- Add SystemModel attributes
- Enable pretty printing of different PRAS component information
- Enable auto-generated documentation website with detailed tutorials and walk-throughs


## [0.7], 2024 - December
- PRAS codebase refactored as a monorepo, and subpackages `PRAS.jl`, `PRASCore.jl`, `PRASFiles.jl`, and `PRASCapacityCredits.jl` available through the Julia General registries.
- Removed `Convolution` and `NonSequentialMonteCarlo` simulation capabilities to simplify codebase.
- Bump Julia version required to `v1.10` 
- Add results serialization capability for `ShortfallResults`

## [0.6], 2021 - May
- Major updates to the results interface, including for capacity credit and SequentialMonteCarlo.
- Refactored and simplified metric types.
- Added and tested new modular result specifications.
- Updated capacity credit calculations and de-duplicated specification keyword defaults.
- Added tests for savemodel and support for exporting .pras files.
- Replaced Travis CI with GitHub Actions for continuous integration.
- Improved compatibility with HDF5.jl and ensured non-negative storage state of charge.
- Enforced interface-level limits and forced outages for storage and generator-storage.
- Removed unused test files and updated the README with a code coverage badge.

This version is availabe at the NatLabRockies Julia registries or through source code available 
in the [`master`](https://github.com/NatLabRockies/PRAS/tree/master) branch of the PRAS github 
repository. Documentation for this version is available [here]
(https://docs.nlr.gov/docs/fy21osti/79698.pdf).


## [0.5], 2020 - November
- Major refactor of simulation specs and result types.
- Added support for sequential and nonsequential simulation methods.
- Improved modularity of result specifications and metrics.
- Added support for capacity credit and spatiotemporal result specs.
- Improved documentation and test coverage.

## [0.4], 2019 - July
- Added support for storage and generator-storage modeling.
- Improved network flow and copperplate simulation methods.
- Added new result types and improved performance.
- Refactored codebase for better modularity and maintainability.

## [0.3], 2019 - April
- Added support for network result types and transmission modeling.
- Improved simulation performance and result extraction.
- Added new tests and documentation.

## [0.2], 2019 - August
- Added tests and improved SystemModel constructor.
- Improved compatibility with Julia 1.0+.
- Added Travis CI integration and coverage reporting.

## [0.1], 2018 - March
- Initial public release of PRAS.
- Basic resource adequacy simulation and result extraction.
- Initial documentation and test coverage.
