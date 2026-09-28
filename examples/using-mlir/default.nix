{ stdenv
, lib
, cmake
, ninja
, mlir_pkg
}:

stdenv.mkDerivation {
  pname = "using-mlir-example-${lib.toLower mlir_pkg.cmakeBuildType}";
  version = "0.0.0";

  src = lib.cleanSource ./.;

  buildInputs = [ mlir_pkg ];
  nativeBuildInputs = [ cmake ninja ];

  postInstall = ''
    touch "$out"
    echo ">>> MLIR example ${mlir_pkg.cmakeBuildType} build completed successfully! <<<"
  '';
}
