# Probabilistic Resource Adequacy Suite

[![PRAS.jl Tests](https://github.com/NatLabRockies/PRAS/actions/workflows/PRAS.jl.yml/badge.svg?branch=main)](https://github.com/NatLabRockies/PRAS/actions/workflows/PRAS.jl.yml)
[![PRASCore.jl Tests](https://github.com/NatLabRockies/PRAS/actions/workflows/PRASCore.jl.yml/badge.svg?branch=main)](https://github.com/NatLabRockies/PRAS/actions/workflows/PRASCore.jl.yml)
[![PRASFiles.jl Tests](https://github.com/NatLabRockies/PRAS/actions/workflows/PRASFiles.jl.yml/badge.svg?branch=main)](https://github.com/NatLabRockies/PRAS/actions/workflows/PRASFiles.jl.yml)
[![PRASCapacityCredits.jl Tests](https://github.com/NatLabRockies/PRAS/actions/workflows/PRASCapacityCredits.jl.yml/badge.svg?branch=main)](https://github.com/NatLabRockies/PRAS/actions/workflows/PRASCapacityCredits.jl.yml)

[![codecov](https://codecov.io/gh/NatLabRockies/PRAS/branch/main/graph/badge.svg?token=WiP3quRaIA)](https://codecov.io/gh/NatLabRockies/PRAS)
[![docsstable](https://img.shields.io/badge/docs-stable-blue.svg)](https://NatLabRockies.github.io/PRAS/)
[![docsdev](https://img.shields.io/badge/docs-dev-blue.svg)](https://NatLabRockies.github.io/PRAS/dev)
[![DOI](https://img.shields.io/badge/DOI-10.11578/dc.20190814.1-blue.svg)](https://www.osti.gov/biblio/1557438)

The Probabilistic Resource Adequacy Suite (PRAS) is a collection of tools for
bulk power system resource adequacy analysis and capacity credit calculation. Latest
documentation is available [here](https://NatLabRockies.github.io/PRAS/).
The citable documentation report for v0.6 is available
[here](https://www.nlr.gov/docs/fy21osti/79698.pdf).

# Installation

PRAS is written in the [Julia](https://julialang.org/) numerical programming
language. If you haven't already, your first step should be to install Julia.
Instructions are available at
[julialang.org/downloads](https://julialang.org/downloads/).

Once you have Julia installed, PRAS can be installed from the Julia [General registry](https://pkgdocs.julialang.org/v1/registries/) which is installed by default if you have no other registries installed.

From the main Julia prompt, type `]` to enter the package management REPL.
The prompt should change from `julia>` to something like `(v1.10) pkg>`
(your version number may be slightly different).
Type (or paste) the following (minus the `pkg>` prompt) 
```
pkg> add PRAS
```

This will automatically install the PRAS Julia module and all of its
related dependencies. At this point you can hit Backspace to switch back to the
main `julia>` prompt.

# Basic usage

With PRAS installed, you can load it into Julia as follows:

```Julia
using PRAS
```

This will make the core PRAS functions (most importantly, the `SystemModel`
and `assess` functions) available for use in your Julia script or
interactive REPL session.

The following snippet shows expected unserved energy (EUE) assessment for the [RTS-GMLC](https://github.com/GridMod/RTS-GMLC) system, which is packaged with PRAS. 

```Julia
rts_gmlc_sys = rts_gmlc();
shortfall, = assess(rts_gmlc_sys,
                    SequentialMonteCarlo(samples=10,seed=1),
                    Shortfall()
                    );
println("Total system $(EUE(shortfall))")
# Total system EUE = 0.00000 MWh/8784h
```

The [Getting Started](https://natlabrockies.github.io/PRAS/dev/quickstart/) page provides more information
on using PRAS.
