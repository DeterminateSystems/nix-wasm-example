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
      target = (fromToml ./.cargo/config.toml).build.target;

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
            checks = import ./nix/checks.nix {
              inherit name pkgs;
              wasm = self.packages.${system}.default;
            };
          in
          pkgs.mkShell {
            packages = checks ++ (with pkgs; [
              wabt
              wasmtime
            ]);
          };
      });

      packages = forAllSystems ({ pkgs, system }: rec {
        default = wasi;

        wasi = self.lib.mkRustWasmPackage {
          inherit pkgs name;
          rustToolchain = pkgs.rustToolchain;
          target = "wasm32-wasi";
        };
      });

      lib = {
        mkRustWasmPackage = { pkgs, name, rustToolchain, target }: pkgs.stdenv.mkDerivation {
          inherit name;
          src = ./.;
          buildInputs = [ rustToolchain ];
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
