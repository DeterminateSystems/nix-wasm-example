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
              wasm = self.packages.${system}.default;
            };

            helpers = with pkgs; [ direnv jq ];
          in
          pkgs.mkShell {
            packages = checks ++ helpers ++ (with pkgs; [
              cachix # Binary caching
              wabt # WebAssembly Binary Toolit
              wasmtime # Wasm runtime
            ]);
          };
      });

      packages = forAllSystems ({ pkgs, system }: rec {
        default = wasi;

        wasi = self.lib.mkRustWasmPackage {
          inherit pkgs name;
          target = "wasm32-wasi";
        };
      });

      lib = {
        mkRustWasmPackage = { pkgs, name, target }: pkgs.stdenv.mkDerivation {
          inherit name;
          src = ./.;
          buildInputs = with pkgs; [ rustToolchain ];
          buildPhase = ''
            cargo build --target ${target} --release
          '';
          installPhase = ''
            mkdir -p $out/lib/wasm
            cp target/${target}/release/${name}.wasm $out/lib/wasm
          '';
        };
      };
    };
}
