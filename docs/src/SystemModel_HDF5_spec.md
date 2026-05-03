# [`SystemModel` HDF5 representation specification](@id prasfile)

This document specifies a representation of the PRAS `SystemModel` data
structure in terms of objects like 
[groups](https://support.hdfgroup.org/documentation/hdf5/latest/_h5_g__u_g.html#subsec_group_descr), 
[datatypes](https://support.hdfgroup.org/documentation/hdf5/latest/_h5_t__u_g.html#sec_datatype), and 
[datasets](https://support.hdfgroup.org/documentation/hdf5/latest/_h5_d__u_g.html#sec_dataset)
in an [HDF5 file](https://support.hdfgroup.org/documentation/hdf5/latest/_l_b_file_org.html). This specification is version-controlled in the same
repository as the `SystemModel` source code: any time the `SystemModel`
definition is changed, those updates are expected to be reconciled with this
document as appropriate. The version of this specification should therefore be
taken as the version of the package containing this file.

_Note: A useful reference for HDF5 file structure concepts is the
[HDF5 Glossary](https://support.hdfgroup.org/documentation/hdf5/latest/_g_l_s.html).
This document contains links to documentation entries to explain HDF5 terms when used
for the first time._

## Filename extension

By convention, HDF5 file representations of a PRAS `SystemModel` struct are
often given ".pras" filename extensions. This is merely a convenience to more
readily distinguish such files from other HDF5 files on the filesystem (which
will likely have ".h5" or ".hdf5" extensions), and is purely optional.

## PRAS terminology

In the following specification, generators, generator-storage units, storage
devices, demand response devices, and lines are sometimes refered to generically as "resources".
Similarly, regions (a grouping of generators, generator-storage units,
storage, and demand response devices) and interfaces (a grouping of lines) are sometimes referred
to generically as "resource collections".

## HDF5 File Structure

### Root group attributes

The HDF5 file must define seven
[attributes](https://support.hdfgroup.org/documentation/hdf5/latest/_h5_d_m__u_g.html#subsubsec_data_model_abstract_attr)
on the
[root group](https://portal.hdfgroup.org/display/HDF5/HDF5+Glossary#HDF5Glossary-Rootgroup). 
There can also be additional attributes describing the system, including data descriptors used 
in creating the system.

These attributes are mandatory:

 - `pras_dataversion`, signalling that this file is a representation of a PRAS
   `SystemModel` and providing the version of this specification used to
   create the file
 - `start_timestamp`, providing the timestamp of the first period of the
   simulation in ISO-8601 format
 - `timestep_count`, providing the number of timesteps in the simulation
 - `timestep_length`, providing the length (in `timestep_unit`s) of each
   timestep in the simulation
 - `timestep_unit`, providing the time units for `timestep_length`
 - `power_unit`, providing the units for power-related data
 - `energy_unit`, providing the units for energy-related data

There can be any number of optional attributes which need to also be defined as 
key-value pairs and both the key and value are strings of characters.

Each of the required attributes and their contents are explained in more
detail below.

#### `pras_dataversion`

The version of this HDF5 representation specification used to create the 
HDF5 file should be stored in an attribute of the file's root group
labelled `pras_dataversion`. The attribute should provide a single
ASCII string, taking the value of the abridged semantic versioning
representation of the specification version, `vX.Y.Z`, where X, Y, and Z
represent the major, minor, and patch version numbers of the specification,
respectively.

As discussed above, the version of the specification is the same as the version
of the PRASBase.jl package providing the specification, and so should
match the version provided in the package's Project.toml file.

(A given version of PRASBase.jl will check this attribute to determine if it is
capable of reading the provided file, and if so, how to do so. While PRASBase
is usually capable of reading files associated with PRASBase versions older
than itself, it can only write files associated with its own version.)

#### `start_timestamp`

The starting timestamp for the system simulation should be stored in an attribute
of the file's root group labelled `start_timestamp`, as a single
25-character, ISO-8601-compliant ASCII string in a format matching
`2020-12-31T23:59:59-07:00`, providing year, month, day, hour, minute, second,
and timezone offset from UTC (in that order).

#### `timestep_count`

The total number of timesteps in the simulation should be stored in an
attribute of the file's root group labelled `timestep_count`, as a single
integer. The attribute value should match the number of rows
(in C/HDF5 row-major format) in each property dataset in the various resource
and resource collection groups.

#### `timestep_length`

The length of a single timestep (in terms of the units defined by
`timestep_unit`) should be stored in an attribute of the file's root group
labelled `timestep_length`, as a single integer.

#### `timestep_unit`

The units for `timestep_length` should be stored in an attribute of the file's
root group labelled `timestep_unit`, as a single ASCII string. The
following are recognized values for the string to take:

 - `sec` indicates the units are seconds
 - `min` indicates the units are minutes
 - `h` indicates the units are hours
 - `d` indicates the units are days

#### `power_unit`

The units for all parameters quantified in terms of power should be stored in
an attribute of the file's root group labelled `power_unit`, as a single
ASCII string. The following are recognized values for the string to
take:

 - `kW` indicates power data is in units of kilowatts
 - `MW` indicates power data is in units of megawatts
 - `GW` indicates power data is in units of gigawatts
 - `TW` indicates power data is in units of terawatts

#### `energy_unit`

The units for all parameters quantified in terms of energy should be stored in
an attribute of the file's root group labelled `energy_unit`, as a single
ASCII string. The following are recognized values for the string to
take:

 - `kWh` indicates power data is in units of kilowatt-hours
 - `MWh` indicates power data is in units of megawatt-hours
 - `GWh` indicates power data is in units of gigawatt-hours
 - `TWh` indicates power data is in units of terawatt-hours

### Resource / resource collection data

The file may define the following six
[groups](https://support.hdfgroup.org/documentation/hdf5/latest/_h5_g__u_g.html)
as children of the root group. At least two groups are mandatory.

The file must include:

 - `regions`, containing datasets describing regions in the system. This group
   is mandatory as any system must have at least one region

The file must include at least one of:

 - `generators`, containing datasets describing generators in the system
 - `generatorstorages`, containing datasets describing generator-storage units
   in the system

The file may include (optional):

 - `storages`, containing datasets describing storage devices in the system
 - `demandresponses`, containing datasets describing demand response devices in the system
 - `interfaces`, containing datasets describing collections of lines between
   regions in the system. This group **must** be included if `lines` is included
   and **must not** be included if `lines` is omitted.
 - `lines`, containing datasets describing transmission lines between regions
   in the system. This group **must** be included if `interfaces` is included
   and **must not** be included if `interfaces` is omitted.

For simplicity, the class of system resources or resource collections described
by a given group are referred to as "group entities" in the following
paragraphs.

Each group contains one `_core` dataset providing static parameters and/or relations
for the group entities, in the form of a vector / one-dimensional array of
[compound datatype](https://support.hdfgroup.org/documentation/hdf5/latest/_g_l_s.html)
instances. These datasets may use HDF5's automatic compression features to
reduce filesize.

Each group also contains one or more datasets representing (potentially)
time-varying properties of the group entities. These datasets should
be matrices / two-dimensional arrays of unsigned 32-bit integers or 64-bit
floating point numbers, depending on the property in question. These datasets
may also use HDF5's automatic compression features to reduce filesize.

The size of the inner dimension of the array (number of columns in C/HDF5
row-major format, number of rows in Julia/MATLAB/Fortran column-major format)
should match the number of group entities in the system, with entity data
provided in the same order as the entities are defined in the `_core` sibling
dataset.

The size of the outer dimension of the array (number of rows in C/HDF5
row-major format, number of columns in Julia/MATLAB/Fortran column-major
format) should match the number of timesteps to be simulated (as provided by
the `timesteps_count` root attribute). Data should be chronologically
increasing within a single column (row-major) / row (column-major)

Specific details for each of these groups and their required contents are
provided below.

#### `regions` group

Information relating to the regions of the represented system is stored in the
mandatory `regions` group inside the root group. This group should contain two
datasets, one (named `_core`) providing core static data about each region and
one providing (potentially) time-varying data.

The `_core` dataset should be a one-dimensional array storing instances of a
compound datatype with the following fields (in order):

 1. `name`: 128-byte ASCII string. Stores the **unique** name of each region.

Each region in the system corresponds to a single instance of the compound
datatype, so the array should have as many elements as there are regions in
the system.

The `regions` group should contain the following datasets describing
(potentially) time-varying properties of the system regions:

 - `load`, as unsigned 32-bit integers representing aggregated electricity
   demand in each region for each timeperiod, expressed in units given by the
   `power_units` attribute

#### `generators` group

Information relating to the generators of the represented system is stored in
the `generators` group inside the root group. This group should contain four
datasets, one (named `_core`) providing core static data about each generator
and three providing (potentially) time-varying data.

The `_core` dataset should be a vector / one-dimensional array storing
instances of a compound datatype with the following fields (in order):

 1. `name`: 128-byte ASCII string. Stores the **unique** name of each generator.
 2. `category`: 128-byte ASCII string. Stores the category of each generator.
 3. `region`: 128-byte ASCII string. Stores the region of each generator.

Each generator in the system corresponds to a single instance of the compound
datatype, so the vector should have as many elements as there are generators in
the system.

The `generators` group should also contain the following datasets describing
(potentially) time-varying properties of the system generators:

 - `capacity`, as unsigned 32-bit integers representing maximum available
   generation capacity for each generator in each timeperiod, expressed in
   units given by the `power_units` attribute
 - `failureprobability`, as 64-bit floats representing the probability the generator
   transitions from operational to forced outage during a given simulation
   timestep, for each generator in each timeperiod. Unitless.
 - `repairprobability`, as 64-bit floats representing the probability the generator
   transitions from forced outage to operational during a given simulation
   timestep, for each generator in each timeperiod. Unitless.

#### `storages` group

Information relating to the storage-only devices of the represented system is
stored in the `storages` group inside the root group. This group should contain
nine datasets, one (named `_core`) providing core static data about each region
and eight providing (potentially) time-varying data.

The `_core` dataset should be a vector / one-dimensional array storing instances of
a compound datatype with the following fields (in order):

 1. `name`: 128-byte ASCII string. Stores the **unique** name of each storage.
 2. `category`: 128-byte ASCII string. Stores the category of each storage.
 3. `region`: 128-byte ASCII string. Stores the region of each storage.

Each storage in the system corresponds to a single instance of the compound
datatype, so the vector should have as many elements as there are storages in
the system.

The `storages` group should also contain the following datasets describing
(potentially) time-varying properties of the system storage devices:

 - `chargecapacity`, as unsigned 32-bit integers representing maximum available
   charging capacity for each storage unit in each timeperiod, expressed in
   units given by the `power_units` attribute
 - `dischargecapacity`, as unsigned 32-bit integers representing maximum
   available discharging capacity for each storage unit in each timeperiod,
   expressed in units given by the `power_units` attribute
 - `energycapacity`, as unsigned 32-bit integers representing maximum
   available energy storage capacity for each storage unit in each timeperiod,
   expressed in units given by the `energy_units` attribute
 - `chargeefficiency`, as 64-bit floats representing the ratio of power
   injected into the storage device's reservoir to power withdrawn from the
   grid, for each storage unit in each timeperiod. Unitless.
 - `dischargeefficiency`, as 64-bit floats representing the ratio of power
   injected into the grid to power withdrawn from the storage device's
   reservoir, for each storage unit in each timeperiod. Unitless.
 - `carryoverefficiency`, as 64-bit floats representing the ratio of energy
   available in the storage device's reservoir at the beginning of one period
   to energy retained in the storage device's reservoir at the end of the
   previous period, for each storage unit in each timeperiod. Unitless.
 - `failureprobability`, as 64-bit floats representing the probability the unit
   transitions from operational to forced outage during a given simulation
   timestep, for each storage unit in each timeperiod. Unitless.
 - `repairprobability`, as 64-bit floats representing the probability the unit
   transitions from forced outage to operational during a given simulation
   timestep, for each storage unit in each timeperiod. Unitless.

#### `generatorstorages` group

Information relating to the combination generation-storage resources in the
represented system is stored in the `generatorstorages` group inside the root
group. This group should contain twelve datasets, one (named `_core`) providing
core static data about each region and eleven providing (potentially)
time-varying data.

The `_core` dataset should be a vector / one-dimensional array storing instances of
a compound datatype with the following fields (in order):

 1. `name`: 128-byte ASCII string. Stores the **unique** name of each
    generator-storage unit.
 2. `category`: 128-byte ASCII string. Stores the category of each generator-storage
    unit.
 3. `region`: 128-byte ASCII string. Stores the region of each generator-storage
    unit.

Each generator-storage unit in the system corresponds to a single instance of
the compound datatype, so the vector should have as many elements as there are
generator-storages units in the system.

The `generatorstorages` group should also contain the following datasets
describing (potentially) time-varying properties of the system
generator-storage devices:

 - `inflow`, as unsigned 32-bit integers representing exogenous
   power inflow available to each generator-storage unit in each timeperiod,
   expressed in units given by the `power_units` attribute
 - `gridwithdrawalcapacity`, as unsigned 32-bit integers representing maximum
   available capacity to withdraw power from the grid for each
   generator-storage unit in each timeperiod, expressed in units given by the
   `power_units` attribute
 - `gridinjectioncapacity`, as unsigned 32-bit integers representing maximum
   available capacity to inject power to the grid for each generator-storage
   unit in each timeperiod, expressed in units given by the `power_units`
   attribute
 - `chargecapacity`, as unsigned 32-bit integers representing maximum available
   charging capacity for each generator-storage unit in each timeperiod, expressed in
   units given by the `power_units` attribute
 - `dischargecapacity`, as unsigned 32-bit integers representing maximum
   available discharging capacity for each generator-storage unit in each timeperiod,
   expressed in units given by the `power_units` attribute
 - `energycapacity`, as unsigned 32-bit integers representing maximum
   available energy storage capacity for each generator-storage unit in each
   timeperiod, expressed in units given by the `energy_units` attribute
 - `chargeefficiency`, as 64-bit floats representing the ratio of power
   injected into the generator-storage device's reservoir to power withdrawn
   from the grid, for each generator-storage unit in each timeperiod. Unitless.
 - `dischargeefficiency`, as 64-bit floats representing the ratio of power
   injected into the grid to power withdrawn from the generator-storage device's
   reservoir, for each generator-storage unit in each timeperiod. Unitless.
 - `carryoverefficiency`, as 64-bit floats representing the ratio of energy
   available in the generator-storage device's reservoir at the beginning of one period
   to energy retained in the device's reservoir at the end of the
   previous period, for each generator-storage unit in each timeperiod.
   Unitless.
 - `failureprobability`, as 64-bit floats representing the probability the unit
   transitions from operational to forced outage during a given simulation
   timestep, for each generator-storage unit in each timeperiod. Unitless.
 - `repairprobability`, as 64-bit floats representing the probability the unit
   transitions from forced outage to operational during a given simulation
   timestep, for each generator-storage unit in each timeperiod. Unitless.

#### `demandresponses` group

Information relating to the demand response only devices of the represented system is
stored in the `demandresponses` group inside the root group. This group should contain
eight datasets, one (named `_core`) providing core static data about each region
and seven providing (potentially) time-varying data.

The `_core` dataset should be a vector / one-dimensional array storing instances of
a compound datatype with the following fields (in order):

 1. `name`: 128-byte ASCII string. Stores the **unique** name of each demand response.
 2. `category`: 128-byte ASCII string. Stores the category of each demand response.
 3. `region`: 128-byte ASCII string. Stores the region of each demand response.

Each demand response in the system corresponds to a single instance of the compound
datatype, so the vector should have as many elements as there are demand response in
the system.

The `demandresponse` group should also contain the following datasets describing
(potentially) time-varying properties of the system demand resposne devices:

 - `borrowcapacity`, as unsigned 32-bit integers representing maximum available
   borrowing capacity for each demand response unit in each timeperiod, expressed in
   units given by the `power_units` attribute.
 - `paybackcapacity`, as unsigned 32-bit integers representing maximum
   available payback capacity for each demand response unit in each timeperiod,
   expressed in units given by the `power_units` attribute.
 - `energycapacity`, as unsigned 32-bit integers representing maximum
   available borrowed load capacity for each demand response unit in each timeperiod,
   expressed in units given by the `energy_units` attribute.
 - `borrowed_energy_interest`, as 64-bit floats representing the interest borrowed load incurs
   across each timestep for each demand response device. A value greater than zero is growth,
   while a value less than zero is decay. Unitless.
 - `allowablepaybackperiod`, as unsigned 32-bit integers representing the maximum number
   of time steps a demand response device can hold borrowed load. Any energy still
   contained at the end of the period will be counted as unserved load for that hour.
   Expressed in units given by the `timestep_unit` attribute.
 - `failureprobability`, as 64-bit floats representing the probability the unit
   transitions from operational to forced outage during a given simulation
   timestep, for each demand response unit in each timeperiod. Unitless.
 - `repairprobability`, as 64-bit floats representing the probability the unit
   transitions from forced outage to operational during a given simulation
   timestep, for each demand response unit in each timeperiod. Unitless.

#### `interfaces` group

Information relating to transmission interfaces between regions of the
represented system is stored in the `interfaces` group inside the root group.
This group should contain three datasets, one (named `_core`) providing core
static data about each interface and two providing (potentially) time-varying
data.

The `_core` dataset should be a one-dimensional array storing instances of a
compound datatype with the following fields (in order):

 1. `region_from`: 128-byte ASCII string. Stores the name of the first of the two
    regions connected by the interface.
 2. `region_to`: 128-byte ASCII string. Stores the name of the second of the two
    regions connected by the interface.

Each interface in the system corresponds to a single instance of the compound
datatype, so the array should have as many elements as there are interfaces in
the system.

The `interfaces` group should contain the following datasets describing
(potentially) time-varying properties of the system regions:

 - `forwardcapacity`, as unsigned 32-bit integers representing the maximum
   possible total power transfer from `region_from` to `region_to`, for each
   interface in each time period
 - `backwardcapacity`, as unsigned 32-bit integers representing the maximum
   possible total power transfer from `region_to` to `region_from`, for each
   interface in each time period

#### `lines` group

Information relating to individual transmission lines between regions of the
represented system is stored in the `lines` group inside the root group.
This group should contain five datasets, one (named `_core`) providing core
static data about each interface and four providing (potentially) time-varying
data.

The `_core` dataset should be a one-dimensional array storing instances of a
compound datatype with the following fields (in order):

 1. `name`: 128-byte ASCII string. Stores the **unique** name of the line.
 2. `category`: 128-byte ASCII string. Stores the assigned category of the line.
 3. `region_from`: 128-byte ASCII string. Stores the name of the first of the two
    regions connected by the line.
 4. `region_to`: 128-byte ASCII string. Stores the name of the second of the two
    regions connected by the line.

Each line in the system corresponds to a single instance of the compound
datatype, so the array should have as many elements as there are lines in
the system.

The `lines` group should contain the following datasets describing
(potentially) time-varying properties of the system regions:

 - `forwardcapacity`, as unsigned 32-bit integers representing maximum
   available power transfer capacity from `region_from` to `region_to` along
   the line, for each line in each time period
 - `backwardcapacity`, as unsigned 32-bit integers representing maximum
   available power transfer capacity from `region_to` to `region_from` along
   the line, for each line in each time period
 - `failureprobability`, as 64-bit floats representing the probability the line
   transitions from operational to forced outage during a given simulation
   timestep, for each line in each timeperiod. Unitless.
 - `repairprobability`, as 64-bit floats representing the probability the line
   transitions from forced outage to operational during a given simulation
   timestep, for each line in each timeperiod. Unitless.

