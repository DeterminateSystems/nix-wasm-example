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
              stripped = self.packages.${system}.stripped;
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

      packages = forAllSystems ({ pkgs, system }:
        let
          wasmPkgs = self.packages.${system};
        in
        rec {
          default = all;

          all =
            pkgs.stdenv.mkDerivation {
              name = "wasm-all";
              src = ./.;
              installPhase = ''
                mkdir $out
                cp ${wasmPkgs.wasm}/${name}.wasm $out
                cp ${wasmPkgs.wat}/${name}.wat $out
                cp ${wasmPkgs.opcode}/${name}.dist $out
                cp ${wasmPkgs.stripped}/${name}-stripped.wasm $out
              '';
            };

          # Generate Wasm binary using Rust
          wasm =
            let
              target = "wasm32-wasi";
            in
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

          # Generate WAT file (WebAssembly Text Format)
          wat = pkgs.stdenv.mkDerivation {
            name = "wasm-into-wat";
            src = ./.;
            buildInputs = with pkgs; [ wabt ];
            buildPhase = ''
              wasm2wat ${wasmPkgs.wasm}/${name}.wasm > ${name}.wat
            '';
            installPhase = ''
              mkdir $out
              cp ${name}.wat $out
            '';
          };

          opcode = pkgs.stdenv.mkDerivation {
            name = "wasm-into-opcode-count";
            src = ./.;
            buildInputs = with pkgs; [ wabt ];
            buildPhase = ''
              wasm-opcodecnt ${wasmPkgs.wasm}/${name}.wasm -o ${name}.dist
            '';
            installPhase = ''
              mkdir $out
              cp ${name}.dist $out
            '';
          };

          stripped = pkgs.stdenv.mkDerivation {
            name = "wasm-stripped";
            src = ./.;
            buildInputs = with pkgs; [ wabt ];
            buildPhase = ''
              wasm-strip ${wasmPkgs.wasm}/${name}.wasm -o ${name}-stripped.wasm
            '';
            installPhase = ''
              mkdir $out
              cp ${name}-stripped.wasm $out
            '';
          };
        });
    };
}
