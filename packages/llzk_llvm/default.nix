{ llvmPackages
, cmakeBuildType ? "Release"
}:

let
  releaseBuild = cmakeBuildType == "Release" || cmakeBuildType == "RelWithDebInfo";

  mkPackageBase = pkgs: (
    llvmPackages.overrideScope (tpkgs: tpkgsOld: {
      libllvm = tpkgsOld.libllvm.overrideAttrs (attrs: {
        inherit cmakeBuildType;
        pname = "${attrs.pname or "libllvm"}-${pkgs.lib.toLower cmakeBuildType}";
        cmakeFlags = attrs.cmakeFlags ++ [
          # Skip irrelevant targets
          "-DLLVM_TARGETS_TO_BUILD=host"
          "-DLLVM_INCLUDE_BENCHMARKS=OFF"
          "-DLLVM_INCLUDE_EXAMPLES=OFF"
          "-DLLVM_INCLUDE_TESTS=OFF"
          # Need the following to enable exceptions
          "-DLLVM_ENABLE_EH=ON"
          # Assertions are very useful for debugging
          "-DLLVM_ENABLE_ASSERTIONS=${if releaseBuild then "OFF" else "ON"}"
          # Enable Z3 Solver for SMTSolver usage
          "-DLLVM_ENABLE_Z3_SOLVER=ON"
        ];
        propagatedBuildInputs = attrs.propagatedBuildInputs ++ [pkgs.z3];
        patches = attrs.patches ++ [
          # Pending https://github.com/llvm/llvm-project/commit/1d3ea0f50c4bcfababe7929c913df500723dcf2f
          ./initialize-hashing-buffer.patch
        ];
        # Skip tests since they take a long time to build and run
        doCheck = false;

        postInstall = pkgs.lib.optionalString (!releaseBuild) ''
          ln -s $dev/lib/cmake/llvm/LLVMExports-${pkgs.lib.toLower cmakeBuildType}.cmake $dev/lib/cmake/llvm/LLVMExports-release.cmake
        '' + attrs.postInstall;
      });

      clang-tools = (tpkgsOld.clang-tools.override (
        {
          # clangd, clang-tidy, clang-format, etc. from the LLZK-scoped libclang.
          clang-unwrapped = tpkgs.clang-unwrapped;
        }
      )).overrideAttrs (old: {
        # The upstream wrappers use Bash syntax but declare /bin/sh, which is
        # dash on Linux. Nixpkgs generates a separate wrapper for each tool.
        postInstall = (old.postInstall or "") + ''
          for tool in "$out"/bin/clang-* "$out"/bin/clangd; do
            if [ -f "$tool" ] && grep -qx '#!/bin/sh' "$tool"; then
              substituteInPlace "$tool" \
                --replace-fail '#!/bin/sh' '#!${pkgs.bash}/bin/bash'
            fi
          done
        '';
      });

      mlir = pkgs.callPackage ./mlir/default.nix {
        inherit cmakeBuildType;
        inherit (tpkgs.libllvm) monorepoSrc version;
        buildLlvmPackages = tpkgs;
        llvm_meta = llvmPackages.libllvm.meta;
        inherit (tpkgs) libllvm;
      };
    })
  );
in
mkPackageBase
