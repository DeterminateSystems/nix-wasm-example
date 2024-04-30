{ pkgName
, pkgs
, stripped
, wasm-rust
}:

let
  wasmValidate = "${pkgs.wabt}/bin/wasm-validate";
  wasmtime = "${pkgs.wasmtime}/bin/wasmtime";
  wasmFile = "${wasm-rust}/bin/${pkgName}.wasm";
  strippedWasmFile = "${stripped}/lib/${pkgName}-stripped.wasm";

  # Make basic script
  mkBin = name: text: pkgs.writeShellApplication { inherit name text; };

  # Make CLI tool (pass in CLI args)
  mkCli = name: text: pkgs.writeShellApplication { inherit name; text = ''${text} "''${@}"''; };
in
[
  # Ensure that the binary can be run
  (mkCli "run-wasm" "${wasmtime} run ${wasmFile}")

  # Ensure that the stripped version of the binary can be run
  (mkCli "run-wasm-stripped" "${wasmtime} ${strippedWasmFile}")

  # Ensure that the binary is valid
  (mkBin "validate-wasm" "${wasmValidate} ${wasmFile}")

  (mkBin "validate-stripped-wasm" "${wasmValidate} ${strippedWasmFile}")
]

