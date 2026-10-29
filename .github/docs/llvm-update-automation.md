
# LLVM update builder

LLVM update candidates are built only by the `Build LLVM update candidate`
workflow. It runs on the self-hosted runner labeled `dev-llzk`. The runner
must be available only to this repository. Treat its workspace as sensitive:
clean it between jobs or use an ephemeral/reimaged runner.

Before enabling the workflow, repository administrators must:

- Protect `bot/bump-llvm` with a ruleset that permits updates only from the
  `nix-pkgs-llvm-update-bot` GitHub App.  Do not allow human or other workflow
  bypasses.  The App needs only repository `Contents`, `Pull requests`, and
  `Issues` read/write access, and must be installed only on this repository.
- Create the protected `llvm-update-automation` environment with
  `NIX_PKGS_LLVM_UPDATE_APP_PRIVATE_KEY` and the
  `NIX_PKGS_LLVM_UPDATE_APP_CLIENT_ID` configuration variable.  The variable
  must contain the GitHub App's client ID, not its numeric App ID. The private
  key must be the matching, unaltered PEM key; it is used only to mint
  short-lived installation tokens for the update bot. Use
  `scripts/verify-github-app-auth` to validate these credentials locally.

  ```sh
  GITHUB_APP_CLIENT_ID='Iv…' \
  GITHUB_APP_PRIVATE_KEY="$(< /secure/path/to/github-app-private-key.pem)" \
    scripts/verify-github-app-auth
  ```
- Create the protected `llvm-cache-publisher` environment and store the Cachix
  write token there as `CACHIX_PUBLIC_TOKEN`; only the privileged builder job
  may use that environment.
- Create the protected `llzk-lib-update-automation` environment for the
  merge-triggered downstream update.  Create a dedicated GitHub App and put
  its private key in the `LLZK_LIB_UPDATE_APP_PRIVATE_KEY` environment secret
  and its client ID in the `LLZK_LIB_UPDATE_APP_CLIENT_ID` environment
  variable.  Install it only on `project-llzk/llzk-lib` with `Contents` and
  `Pull requests` read/write access.  The workflow mints a short-lived token
  explicitly limited to that repository; it does not receive Cachix or
  LLVM-update credentials.

The privileged workflow is defined on `main` and accepts only an in-repository
`bot/bump-llvm` PR created by `nix-pkgs-llvm-update-bot[bot]`.  It rechecks the
PR head before checkout and rejects candidates whose merge-base diff contains
anything other than `flake.lock` and, for a major LLVM update, `flake.nix`.
Same-major updates change only the lock file; major updates also select the
corresponding `llvmPackages_N` attribute in `flake.nix`. Public and fork PRs
therefore cannot schedule work on the self-hosted runner or access Cachix publishing
credentials.

When that trusted LLVM PR is merged, `Bump llzk-lib flake input` creates or
updates the `bot/bump-llzk-pkgs` PR in `project-llzk/llzk-lib`.  It updates only
the downstream lock file and never enables auto-merge; the normal downstream
pull-request workflows and a human reviewer decide whether to merge it.
