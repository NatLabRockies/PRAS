# # Interpreting Resource Adequacy Metrics
#
# In practice, no single metric fully captures system adequacy. Instead,
# multiple complementary metrics should be considered together to understand
# the frequency, distribution and severity of shortfall events.
# ([NERC (2018)](https://www.nerc.com/globalassets/who-we-are/standing-committees/rstc/pawg/probabilistic_adequacy_and_measures_report.pdf),
# [EPRI](https://www.epri.com/research/products/3002027833), 
# [Stephen et al. 2022](https://doi.org/10.1109/PMAPS53380.2022.9810615)).
#
# For this reason, PRAS provides multiple result specifications and derived
# metrics that allow different aspects of system risk to be evaluated
# consistently.

# ## Event-Based Interpretation
#
# A useful way to interpret adequacy metrics is through the concept of
# **event-periods**.
#
# - An **event-period** occurs when shortfall exists in a given simulation time step
# - An **event-day** occurs when at least one event-period occurs within a day
#
# An **adequacy event** is a set of event-periods that are contiguous at the
# highest available temporal resolution
# ([Stephen et al. 2022](https://doi.org/10.1109/PMAPS53380.2022.9810615)).
#
# This distinction is important because different metrics count different
# quantities:
#
# - **LOLE** counts event-periods
# - **LOLD** counts event-days
# - **LOLEv** counts adequacy events
#
# These metrics are related, but they are not interchangeable.
#
#md # !!! note
#md #     In PRAS the time resolution of LOLE is determined by the
#md #     simulation timestamps of the system and is not assumed to always be hourly.

# Another important reason to use multiple metrics, as described in
# ([Stephen et al. 2022](https://doi.org/10.1109/PMAPS53380.2022.9810615)), 
# is that systems with similar shortfall magnitudes or counts of event-periods
# can exhibit very different temporal patterns.
#
# We can consider a simple example of two cases next:
#
# **Case A**: One day with 10 hours of shortfall
#
# **Case B**: Ten days with 1 hour of shortfall each
#
# | Metric | Case A | Case B |
# |------|--------|--------|
# | LOLE | same | same |
# | EUE | same | same |
# | LOLD | 1 | 10 |
#
# As we can see in the table above, even though LOLE and EUE are identical in this case, 
# LOLD reveals that shortfall events are more dispersed in Case B.
#

# Because event-periods may be distributed across many days, a system with the
# same number of shortfall periods can have very different numbers of event-days. 
# As a result, exact conversions between hourly and daily adequacy
# criteria are not generally possible
# ([Stephen et al. 2022](https://doi.org/10.1109/PMAPS53380.2022.9810615)).

# This behavior is reflected in PRAS results, where LOLE and LOLD provide
# complementary views of how shortfall events are distributed in time.

# ## Mathematical Interpretation
#
# In PRAS, adequacy metrics can be interpreted from Monte Carlo shortfall
# samples.
#
# Using the following notation:
#
# - ``r`` indexes regions
# - ``t`` indexes timestamps
# - ``d`` indexes calendar days
# - ``s`` indexes Monte Carlo samples
# - ``e`` indexes adequacy events
# - ``S_{r,t,s}`` denotes the shortfall in region ``r``, at timestamp ``t``,
#   in Monte Carlo sample ``s``
# - ``T(d)`` is the set of timestamps in day ``d``
#
# the adequacy metrics can be expressed as expectations over Monte Carlo samples:
#
# ### LOLE
#
# LOLE counts the expected number of event-periods with shortfall:

# ```math
# \mathrm{LOLE} =
# \mathbb{E}\left[\sum_t
# \mathbf{1}\left(\sum_r S_{r,t,s} > 0\right)\right]
# ```
#
#
# ### LOLD
#
# LOLD counts the expected number of days containing at least one shortfall:

# ```math
# \mathrm{LOLD} = \mathbb{E}\left[\sum_d I_{d,s}\right]
# ```
#
# where:

# ```math
# I_{d,s} =
# \begin{cases}
# 1 & \text{if } \exists t \in T(d) \text{ such that } \sum_r S_{r,t,s} > 0 \\
# 0 & \text{otherwise}
# \end{cases}
# ```
#
#
# ### LOLEv
#
# LOLEv counts the expected number of adequacy events:

# ```math
# \mathrm{LOLEv} = \mathbb{E}\left[\sum_e J_{e,s}\right]
# ```
#
# where:

# ```math
# J_{e,s} =
# \begin{cases}
# 1 & \text{if adequacy event } e \text{ occurs in sample } s \\
# 0 & \text{otherwise}
# \end{cases}
# ```

# ## Analysis with PRAS
#
# We revisit the RTS-GMLC with increased system load to induce shortfall
# which was described in ref(@id pras_walkthrough)

using PRAS
sys = PRAS.rts_gmlc()
sys.regions.load .+= 700.0

shortfall_samples, = assess(
    sys,
    SequentialMonteCarlo(samples=100, seed=1),
    ShortfallSamples(),
)

# And print the metrics we discussed above: 
println(LOLE(shortfall_samples))
println(LOLD(shortfall_samples))

# LOLE describes how many simulation periods experience shortfall, while LOLD
# describes how many days contain at least one such period.
#
# In the RTS example above, the system has approximately 85 shortfall hours
# but only 25.8 shortfall days. This indicates that shortfall events are
# temporally clustered, meaning that multiple shortfall hours tend to occur within the
# same day rather than being evenly distributed across the year.


# ## References
#
# - [NERC (2018), *Probabilistic Adequacy and Measures Technical Reference Report*](https://www.nerc.com/globalassets/who-we-are/standing-committees/rstc/pawg/probabilistic_adequacy_and_measures_report.pdf)
# - [EPRI, *Resource Adequacy Gap Assessment: Resource Adequacy Assessment Framework*](https://www.epri.com/research/products/3002027833)
# - [Stephen et al. (2022), *Clarifying the Interpretation and Use of the LOLE Resource Adequacy Metric*](https://doi.org/10.1109/PMAPS53380.2022.9810615)