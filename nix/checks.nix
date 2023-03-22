{ pkgName
, pkgs
, stripped
, wasm
}:

let
  wasmValidate = "${pkgs.wabt}/bin/wasm-validate";
  wasmtime = "${pkgs.wasmtime}/bin/wasmtime";
  wasmFile = "${wasm}/lib/${pkgName}.wasm";
  strippedWasmFile = "${stripped}/lib/${pkgName}-stripped.wasm";
  mkBin = name: text: pkgs.writeShellApplication { inherit name text; };
in
[
  # Ensure that the binary can be run
  (mkBin "run-wasm" ''${wasmtime} ${wasmFile} "''${@}"'')

  # Ensure that the stripped version of the binary can be run
  (mkBin "run-wasm-stripped" ''${wasmtime} ${strippedWasmFile} "''${@}"'')

  # Ensure that the binary is valid
  (mkBin "validate-wasm" "${wasmValidate} ${wasmFile}")

  (mkBin "validate-stripped-wasm" "${wasmValidate} ${strippedWasmFile}")

  (mkBin "run-test-suite" ''
    validate-wasm
    validate-stripped-wasm
    run-wasm "Testing"
    run-wasm-stripped "Testing, but stripped"
  '')
]
