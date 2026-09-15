{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils/v1.0.0";
  };

  outputs = { self, nixpkgs, flake-utils }: {
    overlays.default = final: prev: {

      llzk-llvmPackages = (import ./packages/llzk_llvm/default.nix {
        llvmPackages = final.llvmPackages_23;
      }) final;

      llzk-llvmPackages-debug = (import ./packages/llzk_llvm/default.nix {
        llvmPackages = final.llvmPackages_23;
        cmakeBuildType = "Debug";
      }) final;

      mlir = final.llzk-llvmPackages.mlir;
      mlir-debug = final.llzk-llvmPackages-debug.mlir;
    };
  } // (flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ self.overlays.default ];
      };

      mkLlvmConfigCheck =
        llvm_pkg:
        pkgs.runCommand "llvm-config-${pkgs.lib.toLower llvm_pkg.cmakeBuildType}" {
          nativeBuildInputs = [ llvm_pkg.dev ];
        } ''
          llvm-config --version
          touch "$out"
        '';

      mkClangToolsClosureCheck =
        let
          clangTools = pkgs.llzk-llvmPackages.clang-tools;
          outerLlvm = pkgs.llvmPackages_23.llvm;
          discardContext = builtins.unsafeDiscardStringContext;

          expectedLibllvm =
            discardContext (toString pkgs.llzk-llvmPackages.libllvm.lib);

          forbiddenPaths =
            map
              (output: discardContext (toString outerLlvm.${output}))
              outerLlvm.outputs;
        in
        pkgs.runCommand "llzk-clang-tools-uses-llzk-llvm"
          {
            nativeBuildInputs = [
              pkgs.gnugrep
              clangTools
            ];
            closure = pkgs.closureInfo {
              rootPaths = [ clangTools ];
            };
          }
          ''
            closure="$closure/store-paths"

            if ! grep -Fxq ${pkgs.lib.escapeShellArg expectedLibllvm} "$closure"; then
              echo "clang-tools does not depend on expected LLZK LLVM:"
              echo "  ${expectedLibllvm}"
              exit 1
            fi

            for forbidden in ${pkgs.lib.concatMapStringsSep " " pkgs.lib.escapeShellArg forbiddenPaths}; do
              if grep -Fxq "$forbidden" "$closure"; then
                echo "clang-tools unexpectedly depends on outer Nixpkgs LLVM:"
                echo "  $forbidden"
                exit 1
              fi
            done

            for tool in clang-format clang-tidy clangd; do
              stderr="$TMPDIR/$tool.stderr"

              if ! "$tool" --version 2>"$stderr"; then
                echo "$tool --version failed:"
                cat "$stderr"
                exit 1
              fi

              if [ -s "$stderr" ]; then
                echo "$tool --version unexpectedly wrote to stderr:"
                cat "$stderr"
                exit 1
              fi
            done

            touch "$out"
          '';
    in
    {
      packages = flake-utils.lib.flattenTree {
        inherit (pkgs) mlir mlir-debug;
        # Prevent use of libllvm and llvm from nixpkgs, which will have
        # different versions than mlir/llvm built here.
        inherit (pkgs.llzk-llvmPackages) libllvm llvm;
      };

      formatter = pkgs.nixpkgs-fmt;

      checks = {
        llvm-config-release = mkLlvmConfigCheck pkgs.llzk-llvmPackages.libllvm;
        llvm-config-debug = mkLlvmConfigCheck pkgs.llzk-llvmPackages-debug.libllvm;

        using-mlir-release = pkgs.callPackage ./examples/using-mlir {
          mlir_pkg = pkgs.mlir;
        };
        using-mlir-debug = pkgs.callPackage ./examples/using-mlir {
          mlir_pkg = pkgs.mlir-debug;
        };

        clang-tools-uses-llzk-llvm = mkClangToolsClosureCheck;
      };
    }
  ));
}
