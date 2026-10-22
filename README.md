# LLZK Nix Packages

Nix flake containing common packages used by LLZK and in projects using LLZK.

By default, the packages are provided by the `default` overlay of this flake.

## LLVM update builder

LLVM update candidates are built only by the `Build LLVM update candidate`
workflow.  It runs on the dedicated EC2 runner with all of these labels:
`self-hosted`, `linux`, `x64`, and `llzk-llvm-builder`.  The runner must be
available only to this repository and have `bash`, `git`, `gh`, Nix compatible
with this flake, the Cachix client, and sufficient CPU, memory, and disk for
the LLVM builds.  Treat its workspace as sensitive: clean it between jobs or
use an ephemeral/reimaged runner.

Before enabling the workflow, repository administrators must:

- Protect `bot/bump-llvm` with a ruleset that permits updates only from the
  `nix-pkgs-llvm-update-bot` GitHub App.  Do not allow human or other workflow
  bypasses.  The App needs only repository `Contents`, `Pull requests`, and
  `Issues` read/write access, and must be installed only on this repository.
- Create the protected `llvm-update-automation` environment with
  `NIX_PKGS_LLVM_UPDATE_APP_PRIVATE_KEY` and the
  `NIX_PKGS_LLVM_UPDATE_APP_ID` configuration variable.  The private
  key is used only to mint short-lived installation tokens for the update bot.
- Create the protected `llvm-cache-publisher` environment and store the Cachix
  write token there as `CACHIX_PUBLIC_TOKEN`; only the privileged builder job
  may use that environment.

The privileged workflow is defined on `main` and accepts only an in-repository
`bot/bump-llvm` PR created by `nix-pkgs-llvm-update-bot[bot]`.  It rechecks the
PR head before checkout and rejects candidates whose merge-base diff is not
exactly `flake.lock`.  Public and fork PRs therefore cannot schedule work on
the EC2 runner or access Cachix publishing credentials.
