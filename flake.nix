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
      fromToml = file: builtins.fromTOML (builtins.readFile file);
      name = (fromToml ./Cargo.toml).package.name;

      overlays = [
        rust-overlay.overlays.default
        (self: super: {
          rustToolchain = super.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
        })
      ];
      supportedSystems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f {
        pkgs = import nixpkgs { inherit overlays system; };
        inherit system;
      });
    in
    {
      devShells = forAllSystems ({ pkgs, system }: {
        default =
          let
            checks = import ./nix/checks.nix {
              inherit name pkgs;
              wasm = self.packages.${system}.wasm;
            };

            helpers = with pkgs; [ direnv jq ];
          in
          pkgs.mkShell {
            packages = helpers ++ checks ++ (with pkgs; [
              cachix # Binary caching
              wabt # WebAssembly Binary Toolit
              wasmtime # Wasm runtime
            ]);
          };
      });

      packages = forAllSystems ({ pkgs, system }: rec {
        default = wasm;

        # Generate Wasm binary
        wasm = self.lib.mkRustWasmPackage {
          inherit pkgs name;
          target = "wasm32-wasi";
        };

        # Generate WAT file (WebAssembly Text Format)
        wat = pkgs.stdenv.mkDerivation {
          name = "wasm-into-wat";
          src = ./.;
          buildInputs = with pkgs; [ wabt ];
          buildPhase = ''
            wasm2wat ${self.packages.${system}.wasm}/${name}.wasm > ${name}.wat
          '';
          installPhase = ''
            mkdir $out
            cp ${name}.wat $out
          '';
        };
      });

      lib = {
        # Helper function for generating Wasm using Rust
        mkRustWasmPackage = { pkgs, name, target }:
          pkgs.stdenv.mkDerivation {
            inherit name;
            src = ./.;
            buildInputs = with pkgs; [ rustToolchain ];
            buildPhase = ''
              cargo build --target ${target} --release
            '';
            installPhase = ''
              mkdir $out
              cp target/${target}/release/${name}.wasm $out
            '';
          };
      };
    };
}
