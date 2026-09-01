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
        using-mlir-release = pkgs.callPackage ./examples/using-mlir {
          mlir_pkg = pkgs.mlir;
        };
        using-mlir-debug = pkgs.callPackage ./examples/using-mlir {
          mlir_pkg = pkgs.mlir-debug;
        };
      };
    }
  ));
}
