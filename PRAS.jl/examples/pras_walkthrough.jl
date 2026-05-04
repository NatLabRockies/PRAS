# # [PRAS Walkthrough](@id pras_walkthrough)  

# This is a complete example of running a PRAS assessment,
# using the [RTS-GMLC](https://github.com/GridMod/RTS-GMLC) system

# Load the PRAS package and other tools necessary for analyses
using PRAS
using Plots
using DataFrames
using Printf

# ## [Read and Explore a SystemModel](@id explore_systemmodel)

# You can load in a system model from a [.pras file](@ref prasfile) if you have one like so:
# ```julia
# sys = SystemModel("mysystem.pras")
# ```

# For the purposes of this example, we'll just use the built-in RTS-GMLC model.
sys = PRAS.rts_gmlc();

# We see some information about the system by just typing its name
# (or rather the variable that holds it):
sys

# We retrieve the parameters of the system using the `get_params` 
# function and use this for the plots below to ensure we have 
# correct units:
(timesteps,periodlen,periodunit,powerunit,energyunit) = get_params(rts_gmlc())

# This system has 3 regions, with multiple Generators, one GenerationStorage in 
# region "2" and one Storage in region "3". We can see regional information by 
# indexing the system by region name:
sys["2"]

# We can visualize a time series of the regional load in region "2":
region_2_load = sys.regions.load[sys["2"].index,:]
plot(sys.timestamps, region_2_load, 
     xlabel="Time", ylabel="Region 2 load ($(powerunit))", 
     legend=false)

# We can find more information about all the Generators in the system by
# retriving the `generators` in the SystemModel:
system_generators = sys.generators

# This returns an object of the asset type [Generators](@ref PRASCore.Systems.Generators)
# and we can retrieve capacities of all generators in the system, which returns 
# a Matrix with the shape (number of generators) x (number of timesteps):
system_generators.capacity

# We can visualize a time series of the total system capacity 
# (sum over individual generators' capacity at each time step)
plot(sys.timestamps, sum(system_generators.capacity, dims=1)', 
     xlabel="Time", ylabel="Total system capacity (MW)", legend=false)

# Or, by category of generators:
category_indices = Dict([cat => findall(==(cat), system_generators.categories) 
                    for cat in unique(system_generators.categories)]);
capacity_matrix = Vector{Vector{Int}}();
for (category,indices) in category_indices
    push!(capacity_matrix, sum(system_generators.capacity[indices, :], dims=1)[1,:])
end
areaplot(sys.timestamps, hcat(capacity_matrix...),  
        label=permutedims(collect(keys(category_indices))),
        xlabel="Time", ylabel="Total system capacity (MW)")

# Similarly we can also retrieve all the Storages in the system and 
# GenerationStorages in the system using `sys.storages` and `sys.generatorstorages`, 
# respectively.

# To retrieve the assets in a particular region, we can index by the region name
# and asset type (`Generators` here):
region_2_generators = sys["2", Generators]

# We get the storage device in region "3" like so:
region_3_storage = sys["3", Storages]
# and the generation-storage device in region "2" like so:
region_2_genstorage = sys["2", GeneratorStorages]

# ## Run a Sequential Monte Carlo Simulation

# We can run a Sequential Monte Carlo simulation on this system using the
# [assess](@ref PRASCore.Simulations.assess) function. 
# Here we will also use four different [result specifications](@ref results):
shortfall, surplus, utilization, storage = assess(
    sys, SequentialMonteCarlo(samples=100, seed=1),
    Shortfall(), Surplus(), Utilization(), StorageEnergy());

# Start by checking the overall system adequacy:
lole = LOLE(shortfall); # event-hours per year
eue = EUE(shortfall); # unserved energy per year
println("System $(lole), $(eue)")

# Given we use only 100 samples and the RTS-GMLC system is quite reliable,
# we see a system which is reliable, with LOLE and EUE both near zero.
# For the purposes of this example, let's increase the system load homogenously
# by 700MW in every hour and region, and re-run the assessment.

sys.regions.load .+= 700.0
shortfall, surplus, utilization, storage = assess(
    sys, SequentialMonteCarlo(samples=100, seed=1),
    Shortfall(), Surplus(), Utilization(), StorageEnergy());
lole = LOLE(shortfall); # event-hours per year
eue = EUE(shortfall); # unserved energy per year
neue = NEUE(shortfall); # unserved energy per year
println("System $(lole), $(eue), $(neue)")

# Now we see a system which is slightly unreliable with a normalized 
# expected unserved energy (NEUE) of close to 470 parts per million of total load.

# We can now look at the hourly loss-of-load expectation (LOLE) to see when
# when shortfalls are occurring.
# `LOLE.(shortfall, many_hours)` is Julia shorthand for calling LOLE
#  on every timestep in the collection many_hours
lolps = LOLE.(shortfall, sys.timestamps)

# Here results are in terms of event-hours per hour, which is equivalent 
# to the loss-of-load probability (LOLP) for each hour. The LOLE object is
# shown as mean ± standard error. We are mostly interested in the mean here,
# we can retrieve this using `val.(lolps)` and visualize this:
plot(sys.timestamps, val.(lolps), 
     xlabel="Time", ylabel="Hourly LOLE (event-hours/hour)", legend=false)

# We see the shortfall is concentrated in a few hours and there are many 
# hours with LOLE = 1, which means that hour had a shortfall in every 
# Monte Carlo sample.

# We can find the regional NEUE for the entire simulation period, 
# and obtain it in as a DataFrame for easier viewing:
regional_eue = DataFrame([(Region=reg_name, NEUE=val(NEUE(shortfall, reg_name))) 
                          for reg_name in sys.regions.names],
                         )
# So, region "1" has the highest overall NEUE, and has a higher 
# load normalized shortfall

# We may be interested in the EUE in the hour with highest LOLE
max_lole_ts = sys.timestamps[findfirst(val.(lolps).==1)];
println("Hour with first LOLE of 1.0: ", max_lole_ts)

# And we can find the unserved energy by region in that hour:
unserved_by_region = EUE.(shortfall, sys.regions.names, max_lole_ts)
# which returns a Vector of EUE values for each region.

# Region 2 has highest EUE in that hour, and we can look at the 
# utilization of interfaces into that region in that period:
utilization_str = join([@sprintf("Interface between regions 1 and 2 utilization: %0.2f",
                            utilization["1" => "2", max_lole_ts][1]),
                    @sprintf("Interface between regions 3 and 2 utilization: %0.2f", 
                            utilization["3" => "2", max_lole_ts][1]),
                    @sprintf("Interface between regions 1 and 3 utilization: %0.2f", 
                            utilization["1" => "3", max_lole_ts][1])], "\n");
println(utilization_str)                            

# We see that the interfaces are not fully utilized, which means there is 
# no excess generation in the system that could be transferred into region "2"
# and we can confirm this by looking at the surplus generation in each region
println("Surplus in")
@printf("  region 1: %0.2f\n",surplus["1",max_lole_ts][1])
@printf("  region 2: %0.2f\n",surplus["2",max_lole_ts][1])
@printf("  region 3: %0.2f\n",surplus["3",max_lole_ts][1])

# Is local storage another alternative for region 3? One can check on the average 
# state-of-charge of the existing battery in region "3", both in the 
# hour before and during the problematic period:

@printf("Storage energy T-1: %0.2f\n",storage["313_STORAGE_1", max_lole_ts-Hour(1)][1])
@printf("Storage energy T: %0.2f\n",storage["313_STORAGE_1", max_lole_ts][1])

# It may be that the battery is on average charged going in to the event,
# and perhaps retains some energy during the event, even as load is being
# dropped. The device's ability to mitigate the shortfall must then be limited
# only by its discharge capacity, so increasing the regions storage
# capacity by adding more storage devices may help mitigate some shortfall.

# Note that if the event was less consistent, this analysis could also have been
# performed on the subset of samples in which the event was observed, using the
# `ShortfallSamples`, `UtilizationSamples`, and
# `StorageEnergySamples` result specifications instead.


# ## Export Aggregate Results

# After exploring the simulation outputs, we may want to save the
# aggregate results for reporting or further post-processing.

# Rather than querying individual metrics (e.g., LOLE, EUE, NEUE)
# one by one, PRAS provides a utility to export all aggregate
# system-level and region-level results in a single step.

using PRASFiles

output_path = saveshortfall(shortfall, sys, "pras_output");
println("Results exported to: ", output_path)

# This creates a timestamped directory containing a `pras_results.json`
# file with:
# - system-level metrics (LOLE, EUE, NEUE)
# - region-level metrics
# - load and capacity summaries
# - horizon timestamps

# Note that only aggregate results are exported. Sample-level data
# from the Monte Carlo simulation are not included.