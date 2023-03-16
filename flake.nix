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
              inherit (self.packages.${system}) stripped wasm;
            };
            helpers = with pkgs; [ direnv jq ];
          in
          pkgs.mkShell {
            packages = helpers ++ checks ++ (with pkgs; [
              cachix # Binary caching
              wabt # WebAssembly Binary Toolkit
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
                mkdir -p $out/bin $out/share
                cp ${wasmPkgs.wasm}/bin/${name}.wasm $out/bin
                cp ${wasmPkgs.wat}/share/${name}.wat $out/share
                cp ${wasmPkgs.opcode}/share/${name}.dist $out/share
                cp ${wasmPkgs.stripped}/bin/${name}-stripped.wasm $out/bin
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
                mkdir -p $out/bin
                cp target/${target}/release/${name}.wasm $out/bin
              '';
            };

          # Generate WAT file (WebAssembly Text Format)
          wat = pkgs.stdenv.mkDerivation {
            name = "wasm-into-wat";
            src = ./.;
            buildInputs = with pkgs; [ wabt ];
            buildPhase = ''
              wasm2wat ${wasmPkgs.wasm}/bin/${name}.wasm > ${name}.wat
            '';
            installPhase = ''
              mkdir -p $out/share
              cp ${name}.wat $out/share
            '';
          };

          opcode = pkgs.stdenv.mkDerivation {
            name = "wasm-into-opcode-count";
            src = ./.;
            buildInputs = with pkgs; [ wabt ];
            buildPhase = ''
              wasm-opcodecnt ${wasmPkgs.wasm}/bin/${name}.wasm -o ${name}.dist
            '';
            installPhase = ''
              mkdir -p $out/share
              cp ${name}.dist $out/share
            '';
          };

          stripped = pkgs.stdenv.mkDerivation {
            name = "wasm-stripped";
            src = ./.;
            buildInputs = with pkgs; [ wabt ];
            buildPhase = ''
              wasm-strip ${wasmPkgs.wasm}/bin/${name}.wasm -o ${name}-stripped.wasm
            '';
            installPhase = ''
              mkdir -p $out/bin
              cp ${name}-stripped.wasm $out/bin
            '';
          };
        });
    };
}
