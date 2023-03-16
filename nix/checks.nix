{ name
, pkgs
, rustToolchain
, stripped
, wasm
}:

let
  wasmFile = "${wasm}/bin/${name}.wasm";
  strippedWasmFile = "${stripped}/bin/${name}-stripped.wasm";
  app = pkgs.writeShellApplication;
in
[
  # Ensure that the binary can be run
  (app {
    name = "run-wasm";
    text = "${pkgs.wasmtime}/bin/wasmtime ${wasm}/bin/${name}.wasm";
  })

  # Ensure that the stripped version of the binary can be run
  (app {
    name = "run-wasm-stripped";
    text = "${pkgs.wasmtime}/bin/wasmtime ${strippedWasmFile}";
  })

  # Ensure that the binary is valid
  (app {
    name = "validate-wasm";
    text = ''
      ${pkgs.wabt}/bin/wasm-validate ${wasmFile}
    '';
  })

  (app {
    name = "run-test-suite";
    text = ''
      ${rustToolchain}/bin/cargo test
      validate-wasm
      run-wasm
      run-wasm-stripped
    '';
  })
]
