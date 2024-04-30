{
  description = "Nix + WebAssembly example project";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.2311.*.tar.gz";
    fenix = {
      url = "https://flakehub.com/f/nix-community/fenix/0.1.*.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    naersk = {
      url = "https://flakehub.com/f/nix-community/naersk/0.1.*.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-compat.url = "https://flakehub.com/f/edolstra/flake-compat/*.tar.gz";
    flake-schemas.url = "https://flakehub.com/f/DeterminateSystems/flake-schemas/*.tar.gz";
  };

  outputs = { self, ... }@inputs:
    let
      pkgName = (self.lib.fromToml ./Cargo.toml).package.name;
      supportedSystems = [ "aarch64-darwin" "aarch64-linux" "x86_64-darwin" "x86_64-linux" ];
      forAllSystems = f: self.lib.genAttrs supportedSystems (system: f {
        pkgs = import inputs.nixpkgs { inherit system; overlays = [ self.overlays.default ]; };
        inherit system;
      });
      rustWasmTarget = "wasm32-wasi";
    in
    {
      overlays.default = final: prev: rec {
        system = final.stdenv.hostPlatform.system;

        # Builds a Rust toolchain from rust-toolchain.toml
        rustToolchain = with inputs.fenix.packages.${system};
          combine [
            latest.rustc
            latest.cargo
            targets.${rustWasmTarget}.latest.rust-std
          ];

        # Uses the Rust toolchain above to construct a special build function
        buildRustWasiWasm = self.lib.buildRustWasiWasm final;
      };

      # Development environments
      devShells = forAllSystems ({ pkgs, system }: {
        default =
          let
            checks = import ./nix/checks.nix {
              inherit pkgName pkgs;
              inherit (self.packages.${system}) stripped wasm-rust;
            };
            helpers = with pkgs; [ direnv jq ];
          in
          pkgs.mkShell {
            packages = helpers ++ checks ++ (with pkgs; [
              rustToolchain # cargo, etc.
              wabt # WebAssembly Binary Toolkit
              wasmedge # Wasm runtime
              wasmtime # Wasm runtime
              cargo-edit # cargo add, cargo rm, etc.
              tree # for visualizing results
            ]);
          };
      });

      packages = forAllSystems ({ pkgs, system }:
        let
          wasmPkgs = self.packages.${system};
        in
        rec {
          default = wasm-all;

          wasm-all =
            pkgs.stdenv.mkDerivation {
              name = "wasm-all";
              src = self;
              installPhase = ''
                mkdir -p $out/lib $out/share
                cp ${wasmPkgs.wasm-rust}/bin/${pkgName}.wasm $out/lib
                cp ${wasmPkgs.stripped}/lib/${pkgName}-stripped.wasm $out/lib
                cp ${wasmPkgs.wat}/share/${pkgName}.wat $out/share
                cp ${wasmPkgs.stats}/share/${pkgName}.dist $out/share
                cp ${wasmPkgs.objdump}/share/${pkgName}-dump.txt $out/share
              '';
            };

          hello-wasm = pkgs.stdenv.mkDerivation rec {
            name = "hello-wasm";
            nativeBuildInputs = with pkgs; [ makeWrapper ];
            src = self;
            installPhase = ''
              mkdir -p $out/bin $out/lib
              cp ${wasmPkgs.wasm-rust}/bin/${pkgName}.wasm $out/lib
              makeWrapper ${pkgs.wasmtime}/bin/wasmtime $out/bin/${name} \
                --add-flags "$out/lib/${pkgName}.wasm" \
                --add-flags "--"
            '';
          };

          hello-wasm-edge = pkgs.stdenv.mkDerivation rec {
            name = "hello-wasm-edge";
            nativeBuildInputs = with pkgs; [ makeWrapper ];
            src = self;
            installPhase = ''
              mkdir -p $out/bin $out/lib
              cp ${wasmPkgs.wasm-rust}/bin/${pkgName}.wasm $out/lib
              makeWrapper ${pkgs.wasmedge}/bin/wasmedge $out/bin/${name} \
                --add-flags "$out/lib/${pkgName}.wasm"
            '';
          };

          # Generate Wasm binary using Rust
          wasm-rust = pkgs.buildRustWasiWasm {
            name = pkgName;
            src = ./.;
            cargoLock.lockFile = ./Cargo.lock;
          };

          # Generate WAT file (WebAssembly Text Format)
          objdump = pkgs.stdenv.mkDerivation {
            name = "wasm-into-objdump";
            src = ./.;
            buildInputs = with pkgs; [ wabt ];
            buildPhase = ''
              wasm-objdump \
                --details ${wasmPkgs.wasm-rust}/bin/${pkgName}.wasm > ${pkgName}-dump.txt
            '';
            installPhase = ''
              mkdir -p $out/share
              cp ${pkgName}-dump.txt $out/share
            '';
          };

          wat = pkgs.stdenv.mkDerivation {
            name = "wasm-into-wat";
            src = ./.;
            buildInputs = with pkgs; [ wabt ];
            buildPhase = ''
              wasm2wat ${wasmPkgs.wasm-rust}/bin/${pkgName}.wasm > ${pkgName}.wat
            '';
            installPhase = ''
              mkdir -p $out/share
              cp ${pkgName}.wat $out/share
            '';
          };

          stats = pkgs.stdenv.mkDerivation {
            name = "wasm-stats";
            src = ./.;
            buildInputs = with pkgs; [
              wabt # includes wasm-stats
            ];
            buildPhase = ''
              wasm-stats ${wasmPkgs.wasm-rust}/bin/${pkgName}.wasm -o ${pkgName}.dist
            '';
            installPhase = ''
              mkdir -p $out/share
              cp ${pkgName}.dist $out/share
            '';
          };

          stripped = pkgs.stdenv.mkDerivation {
            name = "wasm-stripped";
            src = ./.;
            buildInputs = with pkgs; [ wabt ];
            buildPhase = ''
              wasm-strip ${wasmPkgs.wasm-rust}/bin/${pkgName}.wasm -o ${pkgName}-stripped.wasm
            '';
            installPhase = ''
              mkdir -p $out/lib
              cp ${pkgName}-stripped.wasm $out/lib
            '';
          };
        });

      lib = inputs.nixpkgs.lib // {
        # Helper function for reading TOML files
        fromToml = file: builtins.fromTOML (builtins.readFile file);

        buildRustWasiWasm = pkgs: { name, src, cargoLock }:
          let
            naerskLib = pkgs.callPackage inputs.naersk {
              cargo = pkgs.rustToolchain;
              rustc = pkgs.rustToolchain;
            };
          in
          naerskLib.buildPackage {
            inherit name src;
            CARGO_BUILD_TARGET = rustWasmTarget;
          };
      };
    };
}





