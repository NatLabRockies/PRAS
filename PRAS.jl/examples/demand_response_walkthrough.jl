# # [Demand Response Walkthrough](@id demand_response_walkthrough)  

# This is a complete example of adding demand response to a system,
# using the [RTS-GMLC](https://github.com/GridMod/RTS-GMLC) system

# Load the PRAS package and other tools necessary for analysis
using PRAS
using Plots
using DataFrames
using Dates
using Measures

# ## Add Demand Response to the SystemModel

# For the purposes of this example, we'll just use the built-in RTS-GMLC model. For
# further information on loading in systems and exploring please see the [PRAS walkthrough](@ref pras_walkthrough).
rts_gmlc_sys = PRAS.rts_gmlc();

# Lets overview the system information and make sure the demand response we are creating is correct unit wise.
rts_gmlc_sys

# First, we  define our new demand response component. In accordance with the broader system
# the component will have a simulation length of 8784 timesteps, hourly interval, and MW/MWh power/energy units.
# We will then have a single demand response resource of type `"DR_TYPE1"` with a 50 MW borrow and payback capacity,
# 200 MWh energy capacity, 0% borrowed energy interest, 6 hour allowable payback time periods,
# 10% outage probability, and 90% recovery probability. The setup below uses the `fill` function to create matrices
# with the correct dimensions for each of the parameters, which can be extended to multiple demand response resources
# by changing the `number_of_drs` variable and adjusting names and types accordingly.
(timesteps,periodlen,periodunit,powerunit,energyunit) = get_params(rts_gmlc_sys);
number_of_drs = 1;
new_drs = DemandResponses{timesteps,periodlen,periodunit,powerunit,energyunit}(
    ["DR1"],
    ["DR_TYPE1"],
    fill(50, number_of_drs, timesteps),   # borrow power capacity
    fill(50, number_of_drs, timesteps),   # payback power capacity
    fill(200, number_of_drs, timesteps),  # load energy capacity
    fill(0.0, number_of_drs, timesteps),  # 0% borrowed energy interest
    fill(6, number_of_drs, timesteps),    # 6 hour allowable payback time periods
    fill(0.1, number_of_drs, timesteps),  # 10% outage probability
    fill(0.9, number_of_drs, timesteps),  # 90% recovery probability
    );

# We will also assign the demand response to region "2" of the system.
dr_region_indices = [1:0,1:1,2:0];

# We also want to increase the load in the system to see the effect of demand response being utilized.
# We do this by creating a new load matrix that is 25% higher than the original load.
updated_load = Int.(round.(rts_gmlc_sys.regions.load .* 1.25));

# Lets define our new regions with the updated load.

new_regions = Regions{timesteps,powerunit}(["1","2","3"],updated_load);

# Finally, we create two new system models, one with dr and one without.
modified_rts_with_dr  = SystemModel(
    new_regions, rts_gmlc_sys.interfaces,
    rts_gmlc_sys.generators, rts_gmlc_sys.region_gen_idxs,
    rts_gmlc_sys.storages, rts_gmlc_sys.region_stor_idxs,
    rts_gmlc_sys.generatorstorages, rts_gmlc_sys.region_genstor_idxs,
    new_drs, dr_region_indices,
    rts_gmlc_sys.lines, rts_gmlc_sys.interface_line_idxs,
    rts_gmlc_sys.timestamps);

modified_rts_without_dr  = SystemModel(
    new_regions, rts_gmlc_sys.interfaces,
    rts_gmlc_sys.generators, rts_gmlc_sys.region_gen_idxs,
    rts_gmlc_sys.storages, rts_gmlc_sys.region_stor_idxs,
    rts_gmlc_sys.generatorstorages, rts_gmlc_sys.region_genstor_idxs,
    rts_gmlc_sys.lines, rts_gmlc_sys.interface_line_idxs,
    rts_gmlc_sys.timestamps);

# For validation, we can check that one new demand response device is in the system, and the other system has none.
println("System with DR\n ",modified_rts_with_dr.demandresponses)
println("\nSystem without DR\n ",modified_rts_without_dr.demandresponses)

# ## Run a Sequential Monte Carlo Simulation with and without Demand Response
# We can now run a sequential monte carlo simulation with and without the demand response to see the effect it has on the system.
# We will query the shortfall attributable to demand response (load that was borrowed and never able to be paid back) and total system shortfall.
simspec = SequentialMonteCarlo(samples=100, seed=112);
resultspecs =   (Shortfall(),DemandResponseShortfall(),DemandResponseEnergy());


shortfall_with_dr, dr_shortfall_with_dr,dr_energy_with_dr = assess(modified_rts_with_dr, simspec, resultspecs...);
shortfall_without_dr, dr_shortfall_without_dr,dr_energy_without_dr = assess(modified_rts_without_dr, simspec, resultspecs...);

# Querying the results, we can see that total system shortfall is lower with demand response, across EUE and LOLE metrics.
println("LOLE Shortfall with DR: ", LOLE(shortfall_with_dr))
println("LOLE Shortfall without DR: ", LOLE(shortfall_without_dr))

println("\nEUE Shortfall with DR: ", EUE(shortfall_with_dr))
println("EUE Shortfall without DR: ", EUE(shortfall_without_dr))

# We can also collect the same reliability metrics with the demand response shortfall, which is the amount of load that was borrowed and never able to be paid back.
println("EUE Demand Response Shortfall: ", EUE(dr_shortfall_with_dr))
println("LOLE Demand Response Shortfall: ", LOLE(dr_shortfall_with_dr))

# This means over the simulation, load borrowed and unable to be paid back was 250MWh plus or minus 30 MWh.
# Similarly, we have a loss of load expectation from demand response of 2.1 event hours per year.

# Lets plot the borrowed load of the demand response device over the simulation.
borrowed_load = [x[1] for x in dr_energy_with_dr["DR1",:]];
plot(rts_gmlc_sys.timestamps, borrowed_load, xlabel="Timestamp", ylabel="DR1 Borrowed Load", title="DR1 Borrowed Load vs Time", label="")

# We can see that the demand response device was utilized during the summer months, however never borrowing up to its full 200MWh capacity.

# Lets plot the demand response borrowed load across the month and hour of day for greater granularity on when load is being borrowed.
months = month.(rts_gmlc_sys.timestamps);
hours = hour.(rts_gmlc_sys.timestamps) .+ 1;

heatmap_matrix = zeros(Float64, 24, 12);
for (val, m, h) in zip(borrowed_load, months, hours)
    heatmap_matrix[h, m] += val;
end

heatmap(
    1:12, 0:23, heatmap_matrix;
    xlabel="Month", ylabel="Hour of Day", title="Total DR1 Borrowed Load (MWh)",
    xticks=(1:12, ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]),
    colorbar_title="Borrowed Load", color=cgrad([:white, :red], scale = :linear),
    left_margin = 5mm, right_margin = 5mm
)

# Maximum borrowed load occurs in the late afternoon July month, with a different peaking pattern as greater surplus exists in August, with reduced load constraints.

# We can also back calculate the borrow power and payback power, by calculating timestep to timestep differences. 
# Note, payback power here will not capture any dr attributable shortfall or the impact of `borrowed_energy_interest`.

borrow_power = zeros(Float64, timesteps);
payback_power= zeros(Float64, timesteps);
borrow_power = max.(0.0, borrowed_load[2:end] .- borrowed_load[1:end-1]);
payback_power = max.(0.0, borrowed_load[1:end-1] .- borrowed_load[2:end]);


# And then plotting the two heatmaps to identify when key borrowing and payback periods are occuring.
borrow_heatmap = zeros(Float64, 24, 12)
payback_heatmap = zeros(Float64, 24, 12)

for (b, p, m, h) in zip(borrow_power, payback_power, months[2:end], hours[2:end])
    borrow_heatmap[h, m] += b
    payback_heatmap[h, m] += p
end

p1 = heatmap(1:12, 0:23, borrow_heatmap; ylabel = "Hour of Day", title="DR1 Borrow",
    xticks=(1:12, ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]),
    xtickfont=font(7),
    colorbar_title="Borrow (MW)", color=cgrad([:white, :red]),
    left_margin = 5mm, right_margin = 3mm);
p2 = heatmap(1:12, 0:23, payback_heatmap; ylabel = "Hour of Day", title="DR1 Payback",
    xticks=(1:12, ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]),
    xtickfont=font(7),
    colorbar_title="Payback (MW)", color=cgrad([:white, :blue]),
    left_margin = 3mm, right_margin = 5mm);

plot(p1, p2; layout=(1,2), size=(1000, 500), link = :all)

# We can see peak borrowing occurs around 4-6pm, shifting earlier in the following month, with payback,
# occurring almost immediately after borrowing, peaking around 7-9pm in July.