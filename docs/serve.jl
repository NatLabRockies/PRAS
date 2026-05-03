using LiveServer
using Pkg

# Develop all packages
Pkg.develop([
    (path="../PRASCore.jl",),
    (path="../PRASFiles.jl",),
    (path="../PRASCapacityCredits.jl",),
    (path="../PRAS.jl",)
])

# Build docs
include("make.jl")

# Serve documentation
serve(dir="build")