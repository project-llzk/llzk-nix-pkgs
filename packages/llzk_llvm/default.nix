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
        # Skip tests since they take a long time to build and run
        doCheck = false;

        postInstall = pkgs.lib.optionalString (!releaseBuild) ''
          ln -s $dev/lib/cmake/llvm/LLVMExports-${pkgs.lib.toLower cmakeBuildType}.cmake $dev/lib/cmake/llvm/LLVMExports-release.cmake
        '' + attrs.postInstall;
      });

      # Downstream users accessing devtools like `llzk-llvmPackages.clang-tools` end up requiring this derivation
      # as well and a test currently fails on Darwin systems due to a `codesign` setup issue in upstream nixpkgs.
      llvm = tpkgsOld.llvm.overrideAttrs (attrs: {
        cmakeFlags = attrs.cmakeFlags ++ [
          "-DLLVM_INCLUDE_TESTS=OFF"
        ];
        doCheck = false;
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
