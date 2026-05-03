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