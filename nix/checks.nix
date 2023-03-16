{ name
, pkgs
, wasm
, stripped
}:

let
  wasmFile = "${wasm}/${name}.wasm";
  strippedWasmFile = "${stripped}/${name}-stripped.wasm";
  app = pkgs.writeShellApplication;
in
[
  # Ensure that the binary can be run
  (app {
    name = "run-wasm";
    runtimeInputs = with pkgs; [ wasmtime ];
    text = "wasmtime ${wasmFile}";
  })

  # Ensure that the stripped version of the binary can be run
  (app {
    name = "run-wasm-stripped";
    runtimeInputs = with pkgs; [ wasmtime ];
    text = "wasmtime ${strippedWasmFile}";
  })

  # Ensure that the binary is valid
  (app {
    name = "validate-wasm";
    runtimeInputs = with pkgs; [ wabt ];
    text = ''
      wasm-validate ${wasmFile}
    '';
  })
]
