using Documenter
using PRASCore
using PRASFiles
using PRASCapacityCredits
using Literate

# Building examples was inspired by COSMO.jl repo
@info "Building example problems..."

fix_suffix(filename) = replace(filename, ".jl" => ".md")

example_path = joinpath(@__DIR__, "..","PRAS.jl","examples/")
build_path =  joinpath(@__DIR__, "src", "examples/")
files = readdir(example_path)
filter!(x -> endswith(x, ".jl"), files)
for file in files
      Literate.markdown(example_path * file, build_path;
      documenter = true, credit = true)
end


# Generate the unified documentation
makedocs(
    sitename = "PRAS",
    format = Documenter.HTML(
        prettyurls = true,
        canonical = "https://natlabrockies.github.io/PRAS/stable"
    ),
    modules = [PRASCore, PRASFiles, PRASCapacityCredits],
    pages = [
        "Home" => "index.md",
        "Resource Adequacy" => "resourceadequacy.md",
        "Getting Started" => [
            "Installation" => "installation.md",
            "Quick Start" => "quickstart.md",
        ],        
        "PRAS Components " => [
            "System Model Specification" => "PRAS/sysmodelspec.md",
            "Simulation Specifications" => "PRAS/simulations.md",
            "Result Specifications" => "PRAS/results.md",
            "Capacity Credit Calculation" => "PRAS/capacitycredit.md",            
        ],
        ".pras File Format" => "SystemModel_HDF5_spec.md",
        "Tutorials" => [
            "PRAS 101 Walkthrough" => "examples/pras_walkthrough.md",
            "Demand Response Walkthrough" => "examples/demand_response_walkthrough.md",
        ],
        "Extending PRAS" => "extending.md",
#        "Contributing" => "contributing.md",
        "Changelog" => "changelog.md",
        "API Reference" => [
            "PRASCore" => "PRASCore/api.md",
            "PRASFiles" => "PRASFiles/api.md",
            "PRASCapacityCredits" => "PRASCapacityCredits/api.md"
        ]
    ],
    checkdocs = :exports,
)

deploydocs(
    repo = "github.com/NatLabRockies/PRAS.git",
    push_preview = true,
)