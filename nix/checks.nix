{ pkgName
, pkgs
, wasm-pkg
}:

let
  wasmtime = "${pkgs.wasmtime}/bin/wasmtime";
  wasmFile = "${wasm-pkg}/bin/${pkgName}.wasm";
  strippedWasmFile = "${wasm-pkg}/lib/${pkgName}-stripped.wasm";

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
]
