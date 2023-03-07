{ name, pkgs, wasm }:

let
  wasmFile = "${wasm}/lib/wasm/${name}.wasm";
  inherit (pkgs) writeShellApplication;
in
[
  # Ensure that the binary can be run
  (writeShellApplication {
    name = "check-run";
    runtimeInputs = with pkgs; [ wasmtime ];
    text = "wasmtime ${wasmFile}";
  })

  # Ensure that the binary is valid
  (writeShellApplication {
    name = "check-validate";
    runtimeInputs = with pkgs; [ wabt ];
    text = ''
      wasm-validate ${wasmFile}
    '';
  })
]
