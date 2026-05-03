# [Extending PRAS](@id extending)

PRAS provides opportunties for users to non-invasively build on its general
simulation framework by redefining how simulations are executed, augmenting
how results are reported, or both. This allows for customized analyses
without requiring the user to modify code in the main PRAS package or
implement their own model from scratch.

To implement custom functionality, a user needs to define specific Julia data
structures as well as implement function methods that operate on those
structures. Julia's multiple dispatch functionality can then identify and use
these newly defined capabilities when the `assess` function is invoked
appropriately.

## [Custom Simulation Specifications](@id customsimspec)

Custom simulation specifications allow for redefining how PRAS models system
operations. In addition to the data structures and methods listed here,
defining a new simulation specification also requires defining the appropriate
simulation-result interactions (see [Simulation-Result Interfaces](#simulation-result-interfaces)).

### New Data Structure Requirements

The following new data structure (struct / type) should be defined in Julia:

#### Simulation Specification

The main type representing the new simulation specification. It should be a
subtype of the `SimulationSpec` abstract type and can contain
fields that store simulation parameters (such as the number of Monte Carlo
samples to run or the random number generation seed to use). For example:

```julia
struct MyCustomSimSpec <: SimulationSpec
    nsamples::UInt64
    seed::UInt64
end
```

### New Method Requirements

The following new function method should be defined in Julia:

#### assess

The method to be invoked when the `assess` function is called with the
previously defined simulation specification. By convention, the method should
take a `SystemModel` as the first argument, followed by a specific subtype of
`SimulationSpec`, followed by one or more unspecified subtypes of
`ResultSpec`. For example (using the `MyCustomSimSpec` type
defined above):

```julia
function PRAS.assess(
    sys::SystemModel, simspec::MyCustomSimSpec, resultspecs::ResultSpec...)

    # Implement the simulation logic for MyCustomSimSpec here

    # This will include simulation-result interaction calls to result
    # recording methods, which will need to be implemented by any result 
    # specification wanting to be compatible with MyCustomSimSpec

end
```

## Custom Result Specifications

Custom result specifications allow for saving out additional information that
may be generated during simulations of system operations. In addition to the
data structures and methods listed here, defining a new result specification
also requires defining the appropriate simulation-result interactions (see
[Simulation-Result Interfaces](#simulation-result-interfaces)).

### New Data Structure Requirements
The following new data structures (structs / types) should be defined in Julia:

#### Result Specification

The main type representing the result specification. It should be a subtype of
the `ResultSpec` abstract type and can contain fields that store result
parameters (although this is usually not necessary). For example:

```julia
struct MyCustomResultSpec <: ResultSpec
end
```

#### Result

The type of the data that is returned at the end of an assessment and stores
any information to be reported to the end-user. It should be a subtype of the
`Result` abstract type and should contain fields that store the desired
results. For example:

```julia
struct MyCustomResult <: Result
    myoutput1::Float64
    myoutput2::Vector{Bool}
end
```

### New Method Requirements

#### Indexing

Result data should support index lookups to report overall results or values
for specific time periods, regions, interfaces, units, etc.
The specifics of how the result data is indexed will depend on the nature of
the result type, but will likely involve implementing one of more of the
following methods (here we assume the new result type is
`MyCustomResult`):

```julia
Base.getindex(result::MyCustomResult)
Base.getindex(result::MyCustomResult, region_or_unit::String)
Base.getindex(result::MyCustomResult, interface::Pair{String,String})
Base.getindex(result::MyCustomResult, period::ZonedDateTime)
Base.getindex(result::MyCustomResult,
              region_or_unit::String, period::ZonedDateTime)
Base.getindex(result::MyCustomResult,
              interface::Pair{String,String}, period::ZonedDateTime)
```

#### Risk Metrics

If the result includes information that can be used to calculate resource
adequacy metrics, some or all of following new function methods should be
defined (here we assume the new result type is `MyCustomResult`):

```julia
PRAS.LOLE(result::MyCustomResult)
PRAS.LOLE(result::MyCustomResult, region::String)
PRAS.LOLE(result::MyCustomResult, period::ZonedDateTime)
PRAS.LOLE(result::MyCustomResult, region::String, period::ZonedDateTime)

PRAS.EUE(result::MyCustomResult)
PRAS.EUE(result::MyCustomResult, region::String)
PRAS.EUE(result::MyCustomResult, period::ZonedDateTime)
PRAS.EUE(result::MyCustomResult, region::String, period::ZonedDateTime)
```

If desired, new result specifications may define additional result-specific
accessor methods as well.

## Simulation-Result Interfaces

Result specifications need a way to map information produced by a simulation
to outcomes of interest. The specifics of how this is implemented will vary
between simulation specifications, but in general, a specific `assess`
method will invoke another method that records abstract results. This
recording method will then be implemented by all of the concrete result
specifications wishing to support that simulation specification. A very
simplified example of this pattern is:

```julia
function assess(
    sys::SystemModel, simspec::MyCustomSimSpec, resultspecs::ResultSpec...)

    # Implement the simulation logic for MyCustomSimSpec here,
    # and collect full results
    simulationdata = ...

    # Store requested results
    results = ()
    for resultspec in resultspecs
        results = (results..., record(simspec, resultspec, simulationdata))
    end

    return results

end

function record(
    simspec::MyCustomSimSpec, resultspec::Shortfall, simulationdata)
    # Map simulationdata to shortfall results here
    return ShortfallResult(...)
end

function record(
    simspec::MyCustomSimSpec, resultspec::Surplus, simulationdata)
    # Map simulationdata to surplus results here
    return SurplusResult(...)
end

function record(
    simspec::MyCustomSimSpec, resultspec::MyCustomResultSpec, simulationdata)
    # Map simulationdata to my custom results here
    return MyCustomResult(...)
end
```

By implementing the types and methods described here, a new result
specification can be made compatible with these existing simulation types. In
each case, we assume the `MyResultSpec <: ResultSpec` and
`MyResult <: Result` types have been previously defined.

### Result Accumulator

A sequential Monte Carlo result accumulator incrementally collects relevant
intermediate outcomes as chronological simulations under different random
samples are performed.

```julia
# Define the accumulator structure
struct SMCMyResultAccumulator <: ResultAccumulator{SequentialMonteCarlo,MyResultSpec}
    # fields for holding intermediate data go here
end

# Help PRAS know which accumulator type to expect before one's created
PRAS.ResourceAdequacy.accumulatortype(::SequentialMonteCarlo, ::MyResultSpec) =
    SMCMyResultAccumulator

# Initialize a new accumulator
function PRAS.ResourceAdequacy.accumulator(
    sys::SystemModel, simspec::SequentialMonteCarlo, resultspec::MyResultSpec)
    return SMCMyResultAccumulator(...)
end
```

#### record!

Once system operations in a given time period `t` have been simulated
within a given chronological sample sequence `s`, the `record!`
method extracts outcomes of interest from one or both of the system's
current `state` and the solution to the period's dispatch problem
`prob`. These results are used to update the accumulator `acc`
in-place.

```julia
PRAS.ResourceAdequacy.record!(
    acc::SMCMyResultAccumulator, sys::SystemModel, state::SystemState,
    prob::DispatchProblem, s::Int, t::Int)
```

#### reset!

At the end of each chronological sequence of time periods `s`, the
`reset!` method updates the accumulator `acc` in-place to
finalize recording of any results requiring information from multiple periods,
and prepare the accumulator to start receiving values from a new chronological
simulation sequence.

```julia
PRAS.ResourceAdequacy.reset!(acc::SMCMyResultAccumulator, s::Int)

# Often no action is required here,
# so a simple one-line implementation is possible
PRAS.ResourceAdequacy.reset!(acc::SMCMyResultAccumulator, s::Int) = nothing
```

#### merge!

For multithreaded assessments PRAS creates one accumulator per worker thread (parallel task) and merges each thread's accumulator information togther once work is completed. `merge!` defines how an accumulator `a` should be updated in-place to incorporate the results obtained by another accumulator `b`.

```julia
PRAS.ResourceAdequacy.merge!(
    a::SMCMyResultAccumulator, b::SMCMyResultAccumulator)
```

#### finalize!

Once all of the thread accumulators have been merged down to a single accumulator reflecting results from all of the threads, this final accumulator `acc` is mapped to the final result output through a `finalize` method.

```julia
function PRAS.ResourceAdequacy.finalize(
    acc::SMCMyResultAccumulator, sys::SystemModel)

    return MyResult(...)

end
```
