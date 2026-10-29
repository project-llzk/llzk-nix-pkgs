# LLZK Nix Packages

Nix flake containing common packages used by LLZK and in projects using LLZK.

By default, the packages are provided by the `default` overlay of this flake.

The `mlir-with-python` package enables MLIR's nanobind Python bindings. Its
`python` output contains the installed `mlir` package, and `pythonDeps` exposes
the matching Python build dependencies for downstream extensions.

Build and test the installed bindings with:

```sh
nix build -L .#mlir-with-python
nix build -L .#checks.[system].using-mlir-python
```

`nix flake check` also runs this smoke test, which covers dialect registration,
generated operation builders, IR verification, pass execution, and NumPy
attribute conversion.

## LLVM update automation

Scheduled or manual checks for a newer LLVM version create an update PR.
After the dedicated builder validates it and publishes its artifacts to Cachix,
merging the PR starts a reviewable update of `llzk-lib`'s `llzk-pkgs` input.

```mermaid
---
config:
  themeCSS: |
    .edgeLabel p {
      background-color: #f4f8fc;
      border: 1px solid #57606a;
      border-radius: 4px;
      color: #24292f;
      padding: 3px 6px;
    }
---
flowchart TD
  trigger([GitHub])

    llvm_pr[/llzk-nix-pkgs</br>⎇ bot/bump-llvm/]

  detect[⚙️ Detect LLVM update]
  downstream_job[⚙️ Bump llzk-lib flake input]



    builder[⚙️ Build LLVM update candidate]

    downstream_pr[/llzk-lib</br>⎇ bot/bump-llzk-pkgs/]

  publish[(Cachix)]
  reviewer([👤 Human reviewer])

  trigger -->|1. Run daily| detect
  detect -->|2. If new version,</br> create a PR| llvm_pr
  llvm_pr -->|3. PR opened| builder
  builder -->|4. Publish LLVM artifacts| publish
  reviewer -->|6. Merges PR| llvm_pr
  llvm_pr -->|7. After merge| downstream_job
  downstream_job -->|8. Updates llzk-pkgs and creates a PR| downstream_pr
  reviewer -->|9. Merges PR| downstream_pr
  llvm_pr -->|5. CI pulls the cached artifacts| publish

  classDef ci fill:#fff1e5,stroke:#bc4c00,color:#24292f,rx:6px,ry:6px;
  classDef pullrequest fill:#dafbe1,stroke:#1a7f37,color:#24292f;
  classDef human fill:#f3e8fd,stroke:#8250df,color:#24292f;
  classDef default fill:#ececff,stroke:#9370db,color:#24292f;
  class detect,downstream_job ci;
  class builder ci;
  class llvm_pr,downstream_pr pullrequest;
  class reviewer human;
```

