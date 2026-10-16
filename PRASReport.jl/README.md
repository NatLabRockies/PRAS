# PRASReport.jl

## Usage
```julia
using PRASReport

create_pras_report(system_path="path_to_sys.pras", # Path to your .pras file
                   samples=100,seed=1, # Number of samples and random seed for analysis
                   report_name="report", # Name of the output HTML file
                   report_path=pwd(), # Path for HTML file output
                   threshold=0, # hourly EUE threshold to be considered part of event
                   title="Resource Adequacy Report") # Report title
```
