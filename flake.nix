{
  description = "Nix + WebAssembly example project";

  inputs = {
    nixpkgs.url = "nixpkgs";
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
      pkgName = (self.lib.fromToml ./Cargo.toml).package.name;

      overlays = [
        # Provides a `rust-bin` attribute I can use to build a custom Rust toolchain
        rust-overlay.overlays.default
        (self: super: rec {
          rustToolchain = super.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;

          buildRustWasiWasm = { name, src, cargoLock }:
            let
              rustPlatform = super.makeRustPlatform {
                cargo = rustToolchain;
                rustc = rustToolchain;
              };
              target = "wasm32-wasi";
            in
            rustPlatform.buildRustPackage {
              inherit cargoLock name src;
              buildPhase = ''
                cargo build --release --target ${target}
              '';
              installPhase = ''
                mkdir -p $out/lib
                cp target/${target}/release/${pkgName}.wasm $out/lib
              '';
            };
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
              inherit pkgName pkgs;
              inherit (self.packages.${system}) stripped wasm;
            };
            helpers = with pkgs; [ direnv jq ];
          in
          pkgs.mkShell {
            packages = helpers ++ checks ++ (with pkgs; [
              rustToolchain # cargo, etc.
              cachix # Binary caching
              wabt # WebAssembly Binary Toolkit
              wasmedge # Wasm runtime
              wasmtime # Wasm runtime
              cargo-edit # cargo add, cargo rm, etc.
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
                mkdir -p $out/lib $out/share
                cp ${wasmPkgs.wasm}/lib/${pkgName}.wasm $out/lib
                cp ${wasmPkgs.stripped}/lib/${pkgName}-stripped.wasm $out/lib
                cp ${wasmPkgs.wat}/share/${pkgName}.wat $out/share
                cp ${wasmPkgs.opcode}/share/${pkgName}.dist $out/share
              '';
            };

          hello-wasm = pkgs.stdenv.mkDerivation rec {
            name = "hello-wasm";
            nativeBuildInputs = with pkgs; [ makeWrapper ];
            src = ./.;
            installPhase = ''
              mkdir -p $out/bin $out/lib
              cp ${wasmPkgs.wasm}/lib/${pkgName}.wasm $out/lib
              makeWrapper ${pkgs.wasmtime}/bin/wasmtime $out/bin/${name} \
                --add-flags "$out/lib/${pkgName}.wasm" \
                --add-flags "--"
            '';
          };

          hello-wasm-edge = pkgs.stdenv.mkDerivation rec {
            name = "hello-wasm";
            nativeBuildInputs = with pkgs; [ makeWrapper ];
            src = ./.;
            installPhase = ''
              mkdir -p $out/bin $out/lib
              cp ${wasmPkgs.wasm}/lib/${pkgName}.wasm $out/lib
              makeWrapper ${pkgs.wasmedge}/bin/wasmedge $out/bin/${name} \
                --add-flags "$out/lib/${pkgName}.wasm"
            '';
          };

          # Generate Wasm binary using Rust
          wasm = pkgs.buildRustWasiWasm {
            name = pkgName;
            src = ./.;
            cargoLock.lockFile = ./Cargo.lock;
          };

          # Generate WAT file (WebAssembly Text Format)
          wat = pkgs.stdenv.mkDerivation {
            name = "wasm-into-wat";
            src = ./.;
            buildInputs = with pkgs; [ wabt ];
            buildPhase = ''
              wasm2wat ${wasmPkgs.wasm}/lib/${pkgName}.wasm > ${pkgName}.wat
            '';
            installPhase = ''
              mkdir -p $out/share
              cp ${pkgName}.wat $out/share
            '';
          };

          opcode = pkgs.stdenv.mkDerivation {
            name = "wasm-into-opcode-count";
            src = ./.;
            buildInputs = with pkgs; [ wabt ];
            buildPhase = ''
              wasm-opcodecnt ${wasmPkgs.wasm}/lib/${pkgName}.wasm -o ${pkgName}.dist
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
              wasm-strip ${wasmPkgs.wasm}/lib/${pkgName}.wasm -o ${pkgName}-stripped.wasm
            '';
            installPhase = ''
              mkdir -p $out/lib
              cp ${pkgName}-stripped.wasm $out/lib
            '';
          };
        });

      lib = {
        # Helper function for reading TOML files
        fromToml = file: builtins.fromTOML (builtins.readFile file);
      };
    };
}
