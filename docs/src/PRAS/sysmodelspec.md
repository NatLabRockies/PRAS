# [System Model Specification](@id system_specification)


Assessing the resource adequacy of a power system requires a description
of the various resources available to that system, as well as its requirements
for serving load. In PRAS, this involves representing the
system's supply, storage, transmission, and demand characteristics in a specific
data format. This information is stored in memory as a `SystemModel`
Julia data structure, and on disk as an HDF5-formatted file with a
`.pras` file extension. Loading the system data from disk to memory is
accomplished via the following Julia code:

```julia
using PRAS
sys = SystemModel("filepath/to/mysystem.pras")
```

A full technical specification of the `.pras` storage format is
available in the PRAS source code repository.
Storing system data in this format ensures that it will remain
readable in the future, even if PRAS' in-memory data representation changes.
Newer versions of the PRAS package are always able to read
`.pras` files created for older versions.

An in-memory `SystemModel` data structure can also be written back to
disk:

```julia
savemodel(sys, "filepath/to/mynewsystem.pras")
```

PRAS simulates simplified power system operations over one or
more consecutive time periods. The number of time periods to model and the
temporal duration of a single time period are specified on a per-system basis,
and must be consistent with provided starting and ending timestamps (defined
with respect to a specific time zone).

When working with multiple years of
weather data, a user may wish to create separate system models and perform runs
for each year independently, or create a single system model containing the
full multi-year dataset. The first approach can be useful for studying
inter-annual variability of annual risk metrics using only the built-in
methods -- while this is also possible with a single multi-year run, it
requires some additional post-processing work.

PRAS represents a power system as one or more **regions**, each containing
zero or more **generators**, **storages**,**generator-storages**, and 
**demand responses**. **Interfaces** contain **lines** and
allow power transfer between two regions. The table below summarizes
the characteristics of the different resource types (generators, storages,
generator-storages, and lines), and the
remainder of this section provides more details about each resource type
and their associated resource collections (regions or interfaces).

| Parameter | Generator | Storage | Generator-Storage | Demand Response | Line |
|-----------|-----------|---------|-------------------|-----------------|------|
| *Associated with a(n)...* | *Region* | *Region* | *Region* | *Region* | *Interface* |
| *Name* | • | • | • | • | • |
| *Category* | • | • | • | • | • |
| Generation Capacity | • | | | |
| Inflow Capacity | | | • | |
| Charge Capacity | | • | • | |
| Discharge Capacity | | • | • | |
| Load Borrow Capacity | | | | • | |
| Load Payback Capacity | | | | • | |
| Energy Capacity | | • | • | |
| Borrowed Load Capacity | | | | • | |
| Charge Efficiency | | • | • | |
| Discharge Efficiency | | • | • | |
| Carryover Efficiency | | • | • | |
| Borrowed Energy Interest | | | | • | |
| Grid Injection Capacity | | | • | |
| Grid Withdrawal Capacity | | | • | |
| Forward Transfer Capacity | | | | | • |
| Backward Transfer Capacity | | | | | • |
| Available→Unavailable Transition Probability | • | • | • | • | • |
| Unavailable→Available Transition Probability | • | • | • | • | • |

*Table: PRAS resource parameters. Parameters in italic are fixed values; all others are provided as a time series.*

The [system model exploration](@ref explore_systemmodel) section in the PRAS walkthrough 
example shows different ways to retrieve and visualize information from these assets.

## Regions
PRAS does not represent the power system's individual electrical buses. Intead,
PRAS **regions** are used to represent a collection of electrical buses
that are grouped together for resource adequacy assessment purposes. Power
transfer between buses within a single PRAS region is assumed to take place on
a "copper sheet" with no intraregional transfer limits or line reliability
limitations considered.

In a PRAS system representation, each region is associated with a descriptive
name and an aggregate load time series, representing the total real power
demand across all buses in the region, for every simulation period defined
by the model.

## Generators

Electrical supply resources with no modeled energy constraints (e.g., a thermal
generator that can never exhaust its fuel supply) are represented in PRAS as
**generators**. Generators are the simplest supply resource modeled in
PRAS. In addition to a descriptive name and category, each generator unit is
associated with a time series of maximum generating capacity. This
time series can be a simple constant value (e.g., for a thermal plant) or can
change in any arbitrary manner (e.g., for a solar PV array). Each generator is
associated with a single PRAS region.

For each period of an operations simulation, each generator takes on one of
two possible availability states. If the unit is available, it is capable of
injecting power up to its maximum generation capacity (for that time period) in
its associated region. If the unit is unavailable (representing some kind of
unplanned or forced outage), it is incapable of injecting any power into the
system. Between time periods, the unit may randomly transition to the
opposite state according to unit-specific state transition probabilities. Like
maximum available capacity, these transition probabilities are represented as
time series, and so may be different during different time periods.

```@raw html
<figure>
<img src="../../images/resourceparameters.png" alt="Relations between power and energy parameters for generator, storage, and generator-storage resources." style="max-width:2000px;  width:100%;"/>
<figcaption> Relations between power and energy parameters for generator, storage, generator-storage, and demand response resources</figcaption>
</figure>
```

## Storages

Resources that can shift electrical power availability forward in time but do
not provide an overall net addition of energy into the system (e.g., a battery)
are referred to as **storages** in PRAS. Like generators, storages are
associated with descriptive name and category metadata.
Each storage unit has both a charge and discharge capacity time series, representing the
device's maximum ability to withdraw power from or inject power into the grid
at a given point in time (as with generator capacity, these values may remain
constant over the simulation or may vary to reflect external constraints).

Storage units also have a maximum energy capacity time series, reflecting the
maximum amount of dischargeable energy the device can hold at a given point in
time (increasing or decreasing this value will change the duration of time for
which the device could charge or discharge at maximum power). The storage's
state of charge increases with charging and decreases with
discharging, and must always remain between zero and the maximum energy
capacity in that time period. The energy flow relationships between
these capacities are depicted visually in the figure above.

If a storage device is charged and the maximum
energy capacity decreases such that the state of charge exceeds the energy
limit, the additional energy is automatically "spilled" (the surplus energy
is not injected into the grid, but simply vanishes from the system).

Storage units may incur losses when moving energy into or out of the device
(charge and discharge efficiency), or forward in time (carryover efficiency).
When charging the unit, the effective increase to the state
of charge is determined by multiplying the charging power by the charge
efficiency. Similarly, when discharging the unit, the effective decrease to the
state of charge is calculated by dividing the discharge power by the discharge
efficiency. The available state of charge in the next time
period is determined by multiplying the state of charge in the current time
period by the carryover efficiency.

Just as with generators, storages may be in available or unavailable states, and
move between these states randomly over time, according to provided state
transition probabilities. Unavailable storages cannot inject power into or
withdraw power from the grid, but they do maintain their energy state of charge
during an outage (minus any carryover losses occurring over time).

## Generator-Storages

Resources that add net new energy into the system but can also move that
energy forward in time instead of injecting it immediately (see figure below for examples) are referred to as
**generator-storages** in PRAS. As the name suggests, they combine the
characteristics of both generator and storage devices into a single unit.

As with generator and storage units, generator-storages have associated
name and category metadata, and two availability states with random
transition probabilities. They have a potentially time-varying maximum inflow
capacity (representing potential new energy being added to the system and
analogous to the generator's maximum generating capacity) as well as
all the power and energy capacity and efficiency parameters associated with
storages. They also have separate maximum grid injection and withdrawal capacity time series,
reflecting the fact that (for example) they may not be able to discharge their
internal storage at full capacity while simultaneously injecting their full
exogenous energy inflow to the grid. The energy flow relationships between
these capacities are depicted visually in the figure above.

A generator-storage in the unavailable state can neither charge nor discharge
its storage, nor send energy inflow to the grid. Like storage, it does retain
its state of charge during outages (subject to carryover losses).


```@raw html
<figure>
<img src="../../images/genstorexamples.svg" alt="Example applications of the generator-storage resource type" style="max-width:2000px;  width:100%;"/>
<figcaption> Example applications of the generator-storage resource type </figcaption>
</figure>
```

## Demand Responses

Resources that can shift or shed electrical load forward in time but do
not provide an overall net addition of energy into the system (e.g., dr event programs)
are referred to as **demand responses** in PRAS. Like storages, demand response components are
associated with descriptive name and category metadata.
Each demand response unit has both a load borrow and load payback capacity time series, representing the
device's maximum ability to borrow load from or payback load into the grid
at a given point in time (as with storage capacity, these values may remain
constant over the simulation or may vary to reflect external constraints).

Demand response units also have a maximum load capacity time series, reflecting the
maximum amount of borrowed load the device can hold at a given point in
time (increasing or decreasing this value will change the duration of time for
which the device could borrow or payback at maximum power). The demand response's
state of load increases with borrowing and decreases with
payback, and must always remain between zero and the maximum load
capacity in that time period. The energy flow relationships between
these capacities are depicted visually in the energy relation diagram.
If the maximum load capacity is less than the previous hour's state, the load borrowed will
be counted as unserved energy.


| **Demand Response Type**   | **Description** | **Relevance to PRAS?** |
|:----------|:---------------|:----------------------|
| **Shift**  | Demand response that encourages the movement of energy consumption from times of high demand to times of day when there is a surplus of generation.​   | Yes: can be dispatched as part of the PRAS optimization, to move load out of (net) peak periods.​           |
| **Shed**   | Loads that can be curtailed to provide peak capacity reduction and support the system in emergency or contingency events with a range in advance notice times.​ | Yes: but caution must be used to avoid too frequent load shed and to capture only load that can truly be shed (i.e., not able to be paid back at a later time). Setting the `borrowed_energy_interest` to -0.99 will drop all effective borrowed load.​ |
| **Shape**  | Demand response that reshapes customer load profiles through price response or behavioral campaigns — ‘load-modifying DR’ — with advance notice of months to days.​ | Only through pre-processing to load; no original implementation option within the PRAS optimization.|
| **Shimmy** | Loads that dynamically adjust to alleviate short-run ramps and disturbances on the system at timescales ranging from seconds up to an hour.​ | No: the system conditions and ramping are more granular than what is possible in PRAS. |
*Table: Common demand response categories and what is possible to model in PRAS. Demand Response type categories are taken from Piette, Mary Ann, et al. "2025 California Demand Response Potential Study.".*


Demand response units may incur losses or gains forward in time (borrowed energy interest).
The available load borrowed in the next time period is calculated by multiplying the borrowed energy interest 
by the current load borrowed and adding to the current load borrowed. 
The borrowed energy interest may be positive or negative,
indicating a growing or shrinking respectively borrowed load hour to hour. Borrowed energy interest
may lead to cases where the maximum load capacity of the demand response device is passed. If this occurs,
any load above the maximum capacity will be tracked as unserved energy.


Just as with storage, demand responses may be in available or unavailable states, and
move between these states randomly over time, according to provided state
transition probabilities. Unavailable demand responses cannot pay back load into or
withdraw load from the grid, but they do maintain their current borrowed load
during an outage (plus or minus any borrowed energy interest occurring over time).

Demand response devices also have a maximum amount of time that they can hold borrowed energy. 
This cutoff, where borrowed load is unable to be repaid and transitions over to unserved_energy,
is refereed to as the allowable payback period. This parameter can be time varying, and therefore
enable unique tailoring to the real world device being modeled. The allowable payback window is a integer
and follows the timestep units set for the system. If any surplus exists in the region, the demand response
device will attempt to payback any borrowed load, before charging storage. If the demand response device
pays back all borrowed load before the end of the period, the counter is reset upon further use.

## Interfaces

**Interfaces** define a potential capability to directly exchange power
between two regions. Any set of two regions can have at most one interface
connecting them. Each interface has both a "forward" and "backward"
time-varying maximum transfer capability: the maximum "forward" transfer
capability refers to the largest amount of total net power that can be moved
from the first region to the second at a given point of time. Similarly, the
maximum "backward" transfer capability refers to the largest amount of total
net power that can be moved from the second region to the first.

## Lines

Individual **lines** are assigned to a single specific interface and
enable moving power between the two regions defined by that interface. Like
other resources, a line is associated with name and category metadata, and
transitions randomly between two availability states according to potentially
time-varying transition probabilities. Like interfaces, lines have a
potentially time-varying "forward" and "backward" transfer capability, where the forward and backward directions
match those associated with the line's interface.

The total interregional transfer
capability of an interface in a given direction is the lower of either the
sum of transfer limits of available lines in that interface, or the
interface-level transfer limit. A line in the unavailable state cannot move
power between regions, and so does not contribute to the corresponding
interface's sum of line-level transfer limits.
