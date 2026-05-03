# [Simulation Specifications](@id simulations)

There are many different simplifying assumptions that can be made when
simulating power system operations for the purpose of studying resource
adequacy. The level of simplification a modeller is willing to accept
will depend on the goals of the study and the computational resources
available to carry out the modelling exercise.

PRAS is referred to as a "suite" because of its inclusion of multiple power
system operations models of varying fidelity and computational complexity.
Each PRAS analysis (a single invocation of PRAS' `assess` function) is associated with exactly one of these
operational models, or "simulation specifications". A simulation specification
encodes a particular set of assumptions and simplifications that will be used
when simulating operations in order to assess the resource adequacy of the
study system.

The current version of PRAS defines the **Sequential Monte Carlo** specification,
with additional user-defined specifications possible (see [Custom Simulation Specifications](@ref customsimspec)). The remainder of this
section describes the methods and underlying assumptions of each of these
built-in simulation specifications.

## Sequential Monte Carlo

The Sequential Monte Carlo method simulates the chronological evolution of the system, tracking individual unit-level outage states and the state of charge of energy-limited resources. While it is the most computationally intensive simulation method provided in PRAS, it remains much simpler (and therefore runs much faster) than a production cost model.

### Theory and Assumptions

The Sequential Monte Carlo method simulates unit-level outages using a two-state Markov model. In each time period, the availability state of each generator, storage, generator-storage, and line either changes or remains the same, at random, based on the unit's provided state transition probabilities. The capacities from each available generator (or line) in a given time period are then added together to determine the total available generating (transfer) capacity for a region (interface). Storage and generator-storage units are similarly enabled or disabled based on their availability states.

Each set of sampled parameters is used to formulate the "pipe-and-bubble" network flow problem shown below, in which local demand in each region is satisfied (or not) using a combination of local generation, imported power, and unserved energy. Regions with surplus capacity can export that power to their neighbours if transmission limits allow, with a small transfer penalty applied to prevent loop flows. Any demand that cannot be supplied under the randomly drawn generation and transmission limits is considered unserved.

```@raw html
<figure>
<img src="../../images/networkflow.svg" alt="Example three-region network flow problem to be solved
        by the Non-Sequential Monte Carlo simulation specification. Any
        load that cannot be served within the sampled generation
        and transmission constraints goes unserved." style="max-width:2000px;  width:50%;"/>
<figcaption> Example three-region network flow problem to be solved
        by the Non-Sequential Monte Carlo simulation specification. Any
        load that cannot be served within the sampled generation
        and transmission constraints goes unserved </figcaption>
</figure>
```

The Sequential Monte Carlo method is unique in its ability to represent energy-limited resources (storages and generator-storages). These resources are dispatched conservatively so as to approximately minimize unserved energy over the full simulation horizon, charging from the grid whenever surplus generating capacity is available, and discharging only when needed to avoid or mitigate unserved energy. Charging and discharging is coordinated between resources using the time-to-go priority described in [Evans et al. (2019)](#references): resources that would be able to discharge the longest at their maximum rate are discharged first, and resources that would take the longest time to charge at their maximum charge rate are charged first. Cross-charging (discharging one resource in order to charge another) is not permitted.

In Sequential Monte Carlo simulations, one "sample" involves chronological simulation of the system over the full operating horizon. Unserved energy results for each hour and the overall horizon are recorded before restarting the simulation and repeating the process with new random outage draws. Once all samples have been completed, hourly and overall system risk metrics can be calculated.

### Usage

A sequential Monte Carlo resource adequacy assessment is invoked by calling PRAS' `assess` method in Julia, with `SequentialMonteCarlo()` as the simulation specification argument:

```julia
assess(sys, SequentialMonteCarlo(), Shortfall())
```

The `SequentialMonteCarlo()` specification accepts several optional keyword arguments, which can be provided in any order:

**samples**: A positive integer value defaulting to `10000`. It defines the number of samples (replications) to be used in the Monte Carlo simulation process.

**seed**: An integer defaulting to a random value. It defines the seed to beused for random number generation when sampling generator and line outage state transitions.

**threaded**: A boolean value defaulting to `true`. If `true`, PRAS will parallelize simulations across the number of threads available to Julia. Setting this to `false` can help with debugging if an assessment is hanging.

**verbose**: A boolean value defaulting to `false`. If `true`,
PRAS will output informative text describing the progress of the assessment.

## References

Billinton, R. (1970). Power System Reliability Evaluation. Gordon and Breach.

Evans, M. P., Tindemans, S. H., & Angeli, D. (2019). Minimizing Unserved Energy Using Heterogeneous Storage Units. IEEE Transactions on Power Systems, 34(5), 3647-3656.

Haringa, G. E., Jordan, G. A., & Garver, L. L. (1991). Application of Monte Carlo simulation to multi-area reliability evaluations. IEEE Computer Applications in Power, 4(1), 21-25.
