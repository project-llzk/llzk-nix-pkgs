# LLZK Nix Packages

Nix flake containing common packages used by LLZK and in projects using LLZK.

By default, the packages are provided by the `default` overlay of this flake.

The `mlir-with-python` package enables MLIR's nanobind Python bindings. Its
`python` output contains the installed `mlir` package, and `pythonDeps` exposes
the matching Python build dependencies for downstream extensions.

Build and test the installed bindings with:

```sh
nix build -L .#mlir-with-python
nix build -L .#checks.aarch64-darwin.using-mlir-python
```

Replace `aarch64-darwin` with your Nix system, such as `x86_64-linux`.
`nix flake check` also runs this smoke test, which covers dialect registration,
generated operation builders, IR verification, pass execution, and NumPy
attribute conversion. If CI times out while building uncached dependencies,
`scripts/build-and-push-cachix` now includes the Python-enabled MLIR package.
