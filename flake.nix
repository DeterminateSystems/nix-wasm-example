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
            runWasm = pkgs.writeScriptBin "run-wasm" ''
              ${pkgs.wasmtime}/bin/wasmtime ${self.packages.${system}.default}/lib/wasm/${name}.wasm
            '';
          in
          pkgs.mkShell {
            packages = [ runWasm ] ++ (with pkgs; [
              wabt
              wasmtime
            ]);
          };
      });

      packages = forAllSystems ({ pkgs, system }: {
        default = pkgs.writeScriptBin name ''
          ${pkgs.wasmtime}/bin/wasmtime ${self.packages.${system}.wasm}/${name}.wasm
        '';

        wasm = pkgs.stdenv.mkDerivation {
          inherit name;
          src = ./.;
          buildInputs = with pkgs; [ rustToolchain ];
          buildPhase = ''
            cargo build --release
          '';
          installPhase = ''
            mkdir -p $out
            cp target/${target}/release/${name}.wasm $out
          '';
        };
      });
    };
}
