{ lib
, stdenv
, llvm_meta
, monorepoSrc
, runCommand
, cmake
, ninja
, python3
, libffi
, fixDarwinDylibNames
, version
, enableShared ? !stdenv.hostPlatform.isStatic
, cmakeBuildType ? "Release"
, enablePythonBindings ? false
, buildLlvmPackages
, libxml2
, libllvm
}:

let
  pythonDeps = with python3.pkgs; [
    numpy
    pybind11
    pyyaml
  ];
in
stdenv.mkDerivation rec {
  pname = "mlir-${lib.toLower cmakeBuildType}";
  inherit version;

  src = runCommand "${pname}-src-${version}" { } ''
    mkdir -p "$out"
    cp -r ${monorepoSrc}/cmake "$out"
    cp -r ${monorepoSrc}/mlir "$out"
    cp -r ${monorepoSrc}/third-party "$out/third-party"

    mkdir -p "$out"/llvm
  '';

  sourceRoot = "${src.name}/mlir";

  nativeBuildInputs = [
    cmake
    ninja
    python3
    libffi
  ] ++ lib.optionals enablePythonBindings pythonDeps # todo: this should be propagated
  ++ lib.optional stdenv.hostPlatform.isDarwin fixDarwinDylibNames;

  buildInputs = [ libxml2 ];
  propagatedBuildInputs = [ libllvm ];

  cmakeFlags = [
    "-DCMAKE_CXX_STANDARD=17"
    "-DCMAKE_BUILD_TYPE=${cmakeBuildType}"
    # See mlir/cmake/modules/CMakeLists.txt
    "-DLLVM_INSTALL_TOOLCHAIN_ONLY=OFF"
    "-DLLVM_INSTALL_PACKAGE_DIR=${placeholder "dev"}/lib/cmake/llvm"
    "-DMLIR_INSTALL_PACKAGE_DIR=${placeholder "dev"}/lib/cmake/mlir"
    "-DMLIR_INSTALL_CMAKE_DIR=${placeholder "dev"}/lib/cmake/mlir"
    "-DMLIR_TOOLS_INSTALL_DIR=${placeholder "out"}/bin/"

    # Since we exclude the llvm/CMakeLists.txt file, we need to manually set
    # some of the default options to ensure everything is built.
    # See: https://github.com/llvm/llvm-project/blob/ffcff4af59712792712b33648f8ea148b299c364/llvm/CMakeLists.txt#L788-L789
    "-DLLVM_BUILD_TOOLS=ON"
    "-DLLVM_BUILD_UTILS=ON"  # needed for mlir-tblgen

    # Build settings
    "-DLLVM_ENABLE_IDE=OFF"
    "-DLLVM_ENABLE_RTTI=ON"
    "-DLLVM_ENABLE_EH=ON"
    "-DLLVM_ENABLE_ASSERTIONS=ON"
    "-DLLVM_INCLUDE_EXAMPLES=OFF"
    "-DMLIR_INCLUDE_DOCS=ON"
    "-DMLIR_STANDALONE_BUILD=TRUE"
    "-DLLVM_TARGETS_TO_BUILD=host"
    "-DMLIR_ENABLE_EXECUTION_ENGINE=ON"
    "-DLLVM_BUILD_LLVM_DYLIB=OFF"
    "-DLLVM_LINK_LLVM_DYLIB=OFF"
    "-DMLIR_BUILD_MLIR_DYLIB=OFF"
    "-DMLIR_LINK_MLIR_DYLIB=OFF"
    "-DLLVM_ENABLE_DUMP=ON"
    "-DMLIR_TABLEGEN_EXE=${buildLlvmPackages.tblgen}/bin/mlir-tblgen"
    "-DLLVM_TABLEGEN_EXE=${buildLlvmPackages.tblgen}/bin/llvm-tblgen"

  ] ++ lib.optionals enablePythonBindings [
    # Enable Python bindings
    "-DMLIR_ENABLE_BINDINGS_PYTHON=ON"
    "-DMLIR_BUILD_MLIR_C_DYLIB=ON"
    "-DPython3_EXECUTABLE=${python3}/bin/python"
    "-DPython3_NumPy_INCLUDE_DIR=${python3.pkgs.numpy}/${python3.sitePackages}/numpy/core/include"
    # ] ++ lib.optionals enableManpages [
    #   "-DCLANG_INCLUDE_DOCS=ON"
    #   "-DLLVM_ENABLE_SPHINX=ON"
    #   "-DSPHINX_OUTPUT_MAN=ON"
    #   "-DSPHINX_OUTPUT_HTML=OFF"
    #   "-DSPHINX_WARNINGS_AS_ERRORS=OFF"
  ];

  patches = [
    # MLIR's custom install rules otherwise hard-code `lib`, bypassing the CMake
    # hook's CMAKE_INSTALL_LIBDIR and leaving the declared `lib` output empty.
    ./gnu-install-dirs.patch
  ];

  outputs = [ "out" "lib" "dev" ] ++ lib.optionals enablePythonBindings [ "python" ];

  postInstall = ''
    # The generated MLIRConfig.cmake assumes the dev binaries are on PATH,
    # so rewrite them to be in the nix store.
    substituteInPlace "$dev"/lib/cmake/mlir/MLIRConfig.cmake \
      --replace-fail '"mlir-tblgen"' \""$out"/bin/mlir-tblgen\" \
      --replace-fail '"mlir-src-sharder"' \""$out"/bin/mlir-src-sharder\" \
      --replace-fail '"mlir-pdll"' \""$out"/bin/mlir-pdll\"

    ${lib.strings.optionalString enablePythonBindings ''
    # move mlir source code
    mkdir -p $python
    mv $out/src $python/src

    # move mlir package code
    mkdir -p $python/${python3.sitePackages}
    mv $out/python_packages/mlir_core/mlir $python/${python3.sitePackages}/mlir
    echo 'mlir' > $python/${python3.sitePackages}/mlir_core.pth

    # move Python bindings DSO to lib output, since they are searched for in there
    mv $python/${python3.sitePackages}/mlir/_mlir_libs/libMLIRPythonCAPI${stdenv.hostPlatform.extensions.sharedLibrary} $lib/lib/
    ''}
  '';

  passthru = {
    hasPythonBindings = enablePythonBindings;
    inherit pythonDeps;
    inherit cmakeBuildType;
  };
}
