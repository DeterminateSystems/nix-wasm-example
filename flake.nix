{
  description = "Nix + WebAssembly example project";

  inputs = {
    nixpkgs.url = "nixpkgs/release-22.11";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self
    , nixpkgs
    , rust-overlay
    }:
    let
      name = (builtins.fromTOML (builtins.readFile ./Cargo.toml)).package.name;
      overlays = [
        rust-overlay.overlays.default
        (self: super: {
          rustToolchain = super.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
        })
      ];
      systems = [ "aarch64-darwin" ]; # TODO: add other systems
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f {
        pkgs = import nixpkgs { inherit overlays system; };
        inherit system;
      });
    in
    {
      devShells = forAllSystems ({ pkgs, system }: {
        default =
          let
            runWasm = pkgs.writeScriptBin "run-wasm" ''
              ${pkgs.wasmtime}/bin/wasmtime ${self.packages.${system}.default}/lib/wasm/${name}.wasm
            '';
          in
          pkgs.mkShell {
            packages = [ runWasm ] ++ (with pkgs; [ cargo-wasi wasmtime ]);
          };
      });

      packages = forAllSystems ({ pkgs, ... }: {
        default =
          let
            target = "wasm32-wasi";
            output = "lib/wasm";
          in
          pkgs.stdenv.mkDerivation {
            inherit name;
            src = ./.;
            buildInputs = with pkgs; [ rustToolchain wasmtime ];
            buildPhase = ''
              cargo build --release --target ${target}
            '';
            installPhase = ''
              mkdir -p $out/${output}
              cp target/${target}/release/${name}.wasm $out/${output}
            '';
          };
      });
    };
}
