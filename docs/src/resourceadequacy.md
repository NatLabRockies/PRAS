# [Resource Adequacy Background](@id resourceadequacy)

An electrical power system is considered resource adequate if it has procured
sufficient resources (including supply, transmission, and responsive demand)
such that it runs a sufficiently low risk of invoking emergency measures (such
as involuntary load shedding) due to resource unavailability or deliverability
constraints. Resource adequacy
is a necessary (but not sufficient) condition for overall power system
reliability, which considers a broader set of system constraints including
operational flexibility and the stability of system voltages and frequency.

Probabilistic resource adequacy assessment is the process by which resource
shortfall risk is quantified. It involves mapping quantified uncertainties in
system operating conditions (primarily forced outages of generators and lines) into
probability distributions for operating outcomes of interest by simulating
system operations under different probabilistically weighted
scenarios. The nature of those simulations varies between models, and can range
from simple snapshot comparisons of peak demand versus available supply,
through to chronological simulations of system dispatch and power flow over
the full operating horizon.

The resulting outcomes can then be used to calculate industry-standard
[probabilistic risk metrics [1]](#references).

**Expected Unserved Energy (EUE)** is the expected (average) total energy
shortfall over the study period. It may be expressed in energy units
(e.g. GWh per year) or normalized against the system's total energy demand and
expressed as a fraction (normalized EUE, or NEUE, expressed as a percentage or
in parts-per-million, ppm).

**Loss-of-Load Expectation (LOLE)** is the expected (average) count of
periods experiencing shortfall over the study period. It is expressed in terms
of event-periods (e.g. event-hours per year, event-days per year). When
reported in terms of event-hours, LOLE is sometimes referred to as LOLH
(loss-of-load hours).

While a system's shortfall risk can never be eliminated entirely, if these
risk metrics are assessed to be lower than some predetermined threshold, the
system is considered resource adequate.

It can sometimes also be useful to express the average and/or incremental
contribution of a particular resource to overall system adequacy in terms of
capacity. This quantity (either in units of power, or as a fraction of the
unit's nameplate capacity) is known as the capacity credit (sometimes called
capacity value) of the resource. While many different methods are used to
estimate the capacity credit of a resource, the most rigorous approaches
generally involve assessing the change in probabilistic system adequacy
associated with adding or removing the resource from the system. As a result,
capacity credit calculation is often closely associated with probabilistic
resource adequacy assessment.

## References

1. de Mijolla, G., Bello, M., Danti Lopez, I., Entriken, R., Hytowitz, R., 
    Lannoye, E., Ranola, J.A., Roark, J., Tuohy, A., & Wang, Q. (2022). 
    [Resource adequacy for a decarbonized future: A summary of existing and 
    proposed resource adequacy metrics]
    (https://www.epri.com/research/products/000000003002023230). 
    Tech. Rep. 3002023230, Electric Power Research Institute (EPRI).