{ name
, pkgs
, wasm
}:

let
  wasmFile = "${wasm}/${name}.wasm";
  inherit (pkgs) writeShellApplication;
in
[
  # Ensure that the binary can be run
  (writeShellApplication {
    name = "run-wasm";
    runtimeInputs = with pkgs; [ wasmtime ];
    text = "wasmtime ${wasmFile}";
  })

  # Ensure that the binary is valid
  (writeShellApplication {
    name = "validate-wasm";
    runtimeInputs = with pkgs; [ wabt ];
    text = ''
      wasm-validate ${wasmFile}
    '';
  })
]
