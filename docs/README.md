# Updating and pushing documentation

These are some steps to follow when making changes to documentation.
1. Checkout a new branch from `main` (e.g. `git checkout -b docupdate`).
2. Instantiate the environment in the `docs` folder by running `] instantiate` in the Julia REPL.
3. Make changes to the documentation files in the `docs` folder and/or the example scripts in the `examples` folder.
4. You can iteratively make changes and build documentation to serve locally by running the `serve.jl` script from the `docs` folder using this command
    ```bash
    julia --project=. -e "using Pkg; Pkg.add(\"LiveServer\"); include(\"serve.jl\")" --threads auto
    ```
5. Once you push to origin (github.com/NatLabRockies/PRAS) and create a pull request, the documentation will be built and served at https://NatLabRockies.github.io/PRAS/previews/PR{#}. Once the changes are merged to `main`, the documentation will be available at https://NatLabRockies.github.io/PRAS/dev. On tagging a PRAS version for release, the documentation will be available at https://NatLabRockies.github.io/PRAS/stable and https://NatLabRockies.github.io/PRAS/vX.Y.Z (where X.Y.Z is the version number).
6. More instructions on version tagging and release can be found in the [Documenter.jl](https://documenter.juliadocs.org/stable/man/hosting/#Documentation-Versions) instructions.