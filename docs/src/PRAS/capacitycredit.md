# [Capacity Credit Calculation](@id capacitycredit)

Resource adequacy paradigms premised on adding resource capacities together to
meet a planning reserve margin require the quantification of a "capacity credit" (sometimes called "capacity value")
for individual resources. While the process of assigning capacity credits is
relatively straightforward for thermal generating units with consistent
potential contributions to system adequacy throughout the day and year
(assuming no fuel constraints), the contributions of variable and
energy-limited resources can be much more difficult to represent as a
single capacity rating.

In these cases, an accurate characterization depends on
the broader system context in which the resource operates.
Probabilistically derived capacity credit calculations
provide a technology-agnostic means of expressing the contributions of
different resources (with diverse and potentially complicated operating
characteristics and constraints) in terms of a common, simple measure of
capacity.

PRAS provides two different methods for mapping incremental resource adequacy
contributions to generic capacity: Equivalent Firm Capacity (**EFC**)
and Effective Load Carrying Capability (**ELCC**). In each case, the user
must provide PRAS with two system representations: one that contains the study
resource (the augmented system), and one that does not (the base system). The
difference between the two systems is then quantified in terms of a capacity
credit.

By choosing what is included in the base case relative to the augmented case,
the user can study either the average, portfolio-level capacity credit of a
resource class (by excluding all resources of that class from the base case,
and including them all in the augmented case) or the marginal capacity credit
(by including almost all of the resource type in the base case, and adding a
single incremental unit in the augmented case).

Note that probabilistically derived capacity credit calculations always involve
some kind of measurement of the reduction in system risk associated with moving
from the base system to the augmented system. If the base system's risk cannot
be reduced (perhaps because the base system's shortfall risk is too small to
obtain a non-zero estimate, or because shortfall only occurs in load pockets
elsewhere in the system), adequacy-based capacity credit metrics may not be
meaningful. In these cases, the starting system may need to be modified, or a
different capacity credit calculation method may be required.

The remainder of this chapter provides details on the theoretical and practical
aspects of using EFC and ELCC for capacity credit analysis in PRAS. Further
mathematical details regarding capacity credit are available in
[Zachary and Dent (2011)](#references).

## Equivalent Firm Capacity (EFC)

### Theory

EFC calculates the amount of idealized "firm" capacity (uniformly available
across all periods, without ever going on outage) that is required to
reproduce the observed resource adequacy benefit (reduction of a specific risk
metric) associated with some study resource of interest. It requires both a base case system (without the study
resource added) and an augmented system (with the study resource added). The
analysis then proceeds as follows:

1. Assess the shortfall risk of the base system according to the
   chosen metric (EUE or LOLE).
2. Assess the (lower) shortfall risk of the augmented system according
   to the chosen metric.
3. Reassess the shortfall risk of the base system after adding some
   amount of "firm" capacity. If the risk matches that of the augmented
   system, stop. The amount of firm capacity added is the
   Equivalent Firm Capacity of the study resource.
4. If the base+firm and augmented system risks do not match, change the
   amount of firm capacity added to the base system, repeating until
   the chosen shortfall risk metrics for each system match.

Typically, the counterfactual firm capacity is added
to the system as a direct replacement for the study resource, and so is located
in the same region (or distributed across multiple regions in corresponding
proportions) as the study resource. PRAS uses a bisection method to
find the appropriate total firm capacity to add to the base system.

### Usage

Performing an EFC assessment in PRAS requires specifying two different
`SystemModel`s: one representing the base system, and a second
representing the augmented system. It also requires specifying the probabilistic risk metric to
use when comparing system risks, an upper bound on the EFC (usually,
the nameplate capacity of the study resource) and to which region(s) the
counterfactual firm capacity should be added. Finally, the simulation
specification should be provided (any simulation method can be used).

For example, to calculate EFC based on EUE for a resource in region A, with an
upper EFC bound of 1000 MW (assuming the `SystemModel`s are represented
in MW), using the sequential Monte Carlo simulation specification:

```julia
assess(base_system, augmented_system,
       EFC{EUE}(1000, "A"), SequentialMonteCarlo())
```

If the study resources are spread over multiple regions (for example, 600 MW
of wind in region A and 400 MW of wind in region B), the fraction of total firm
capacity added to each region can be specified as:

```julia
assess(base_system, augmented_system,
       EFC{EUE}(1000, ["A"=>0.6, "B"=>0.4]), SequentialMonteCarlo())
```

The `EFC()` specification accepts multiple optional keyword
arguments, which can be provided in any order:

**p_value**: A floating point value giving the maximum allowable p-value
from a one-sided hypothesis test. The test considers whether the lower risk
metric used during bisection is in fact less than the upper risk metric. If the p-value exceeds this level, the
assessment will terminate early due to a lack of statistical power. Note that this only matters for simulation
specifications returning estimates with non-zero standard errors, i.e.
Monte Carlo-based methods. Defaults to `0.05`.

**capacity_gap**: An integer giving the maximum desired difference between
reported upper and lower bounds on capacity credit. Once the gap between upper
and lower bounds is less than or equal to this value, the assessment will
terminate. Defaults to `1`.

**verbose**: A boolean value defaulting to `false`. If `true`,
PRAS will output informative text describing the progress of the assessment.

## Effective Load Carrying Capability (ELCC)

### Theory

ELCC quantifies the capacity credit of a study resource according to the
amount of additional constant load the system can serve while
maintaining the same shortfall risk. Like EFC, it requires both a base case
system (without the study resource added) and an augmented system (with the
study resource added). The analysis then proceeds as follows:

1. Assess the shortfall risk of the base system according to the
   chosen metric (EUE or LOLE).
2. Assess the (lower) shortfall risk of the augmented system according
   to the chosen metric.
3. Reassess the shortfall risk of the augmented system after adding some
   amount of constant load. If the risk matches that of the base
   system, stop. The amount of constant load added is the
   Effective Load Carrying Capability of the study resource.
4. If the base and augmented+load system risks do not match, change the
   amount of load added to the augmented system, repeating until
   the chosen shortfall risk metrics for each system match.

ELCC calculations in a multi-region system require choosing where load should
be increased. There are many possible options, including uniformly distributing
new load across each region, distributing load proportional to
total energy demand in each region, and adding load only in the region with
the study resource. The "correct" choice will depend on the goals of the
specific analysis. Once the regional load distribution is specified, PRAS uses
a bisection method to find the appropriate amount of total load to add to the
system.

### Usage
Performing an ELCC assessment in PRAS requires specifying two different
`SystemModel`s: one representing the base system, and a second
representing the augmented system. It also requires specifying the probabilistic risk metric to
use when comparing system risks, an upper bound on the ELCC (usually,
the nameplate capacity of the study resource) and to which region(s) the
additional load should be added. Finally, the simulation
specification should be provided.

For example, to calculate ELCC based on EUE for a resource intending to serve
load in region A, with an upper ELCC bound of 1000 MW (assuming the `SystemModel`s are represented
in MW):

```julia
assess(base_system, augmented_system,
       ELCC{EUE}(1000, "A"), SequentialMonteCarlo())
```

If the load serving assessment is to be spread over multiple regions
(for example, 50% of load in region A and 50% in region B), the fraction of additional load added
to each region can be specified as:

```julia
assess(base_system, augmented_system,
       ELCC{EUE}(1000, ["A"=>0.5, "B"=>0.5]), SequentialMonteCarlo())
```

The `ELCC()` specification accepts multiple optional keyword
arguments, which can be provided in any order:

**p_value**: A floating point value giving the maximum allowable p-value
from a one-sided hypothesis test. The test considers whether the lower risk
metric used during bisection is in fact less than the upper risk metric. If the p-value exceeds this level, the
assessment will terminate early due to a lack of statistical power. Note that this only matters for simulation
specifications returning estimates with non-zero standard errors, i.e.
Monte Carlo-based methods. Defaults to `0.05`.

**capacity_gap**: An integer giving the maximum desired difference between
reported upper and lower bounds on capacity credit. Once the gap between upper
and lower bounds is less than or equal to this value, the assessment will
terminate. Defaults to `1`.

**verbose**: A boolean value defaulting to `false`. If `true`,
PRAS will output informative text describing the progress of the assessment.

## Capacity Credit Results

Both EFC and ELCC assessments return `CapacityCreditResult` objects.
These objects contain information on estimated lower and upper bounds of the
capacity credit, as well as additional details about the process through
which the capacity credit was calculated. Results can be retrieved as follows:

```julia
cc_result = assess(base_system, augmented_system, EFC{EUE}(1000, "A"),
                   SequentialMonteCarlo())

# Get lower and upper bounds on CC estimate
cc_lower = minimum(cc_result)
cc_upper = maximum(cc_result)

# Get both bounds at once
cc_lower, cc_upper = extrema(cc_result)
```

## References

Zachary, S., & Dent, C. J. (2011). Probability theory of capacity value of additional generation. Proc. IMechE Part O: J. Risk and Reliability, 226, 33-43.
