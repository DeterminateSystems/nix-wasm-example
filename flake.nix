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
      forAllSystems = f: inputs.nixpkgs.lib.genAttrs supportedSystems (system: f {
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

        buildRustWasiWasm = self.lib.buildRustWasiWasm final;
        buildRustWasmPackage = self.lib.buildRustWasmPackage final;
        buildRustWasmScript = self.lib.buildRustWasmScript final;
        buildRustWasmEdgeExec = self.lib.buildRustWasmEdgeExec final;
        buildRustWasmtimeExec = self.lib.buildRustWasmtimeExec final;
      };

      # Development environments
      devShells = forAllSystems ({ pkgs, system }: {
        default =
          let
            helpers = with pkgs; [ direnv jq ];
          in
          pkgs.mkShell {
            packages = helpers ++ (with pkgs; [
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
          default = hello-wasm-pkg;

          hello-wasm-pkg = pkgs.buildRustWasmPackage { };

          hello-wasmtime-exec = pkgs.buildRustWasmtimeExec { };

          hello-wasmedge-exec = pkgs.buildRustWasmEdgeExec { };
        });

      lib = {
        # Helper function for reading TOML files
        fromToml = file: builtins.fromTOML (builtins.readFile file);

        handleArgs =
          { name ? null
          , src ? self
          , cargoToml ? ./Cargo.toml
          }:
          let
            meta = (self.lib.fromToml ./Cargo.toml).package;
            pkgName = if name == null then meta.name else name;
            pkgSrc = builtins.path { path = src; name = "${pkgName}-source"; };
          in
          {
            inherit (meta) name;
            inherit pkgName;
            src = pkgSrc;
            inherit cargoToml;
          };

        buildRustWasiWasm = pkgs: { name, src }:
          let
            naerskLib = pkgs.callPackage inputs.naersk {
              cargo = pkgs.rustToolchain;
              rustc = pkgs.rustToolchain;
            };
          in
          naerskLib.buildPackage {
            inherit name src;
            CARGO_BUILD_TARGET = rustWasmTarget;
            buildInputs = with pkgs; [ wabt ];
            postInstall = ''
              wasm-validate $out/bin/${name}.wasm
            '';
          };

        buildRustWasmtimeExec = pkgs: args:
          let
            finalArgs = self.lib.handleArgs args;
            wasmPkg = self.lib.buildRustWasiWasm pkgs {
              inherit (finalArgs) name src;
            };
          in
          pkgs.stdenv.mkDerivation rec {
            name = finalArgs.name;
            src = finalArgs.src;
            nativeBuildInputs = with pkgs; [ makeWrapper ];
            # TODO: bring in accordance with the new Wasmtime interface (WASMTIME_NEW_CLI=1)
            installPhase = ''
              mkdir -p $out/lib
              cp ${wasmPkg}/bin/${finalArgs.name}.wasm $out/lib/${finalArgs.pkgName}.wasm
              makeWrapper ${pkgs.wasmtime}/bin/wasmtime $out/bin/${finalArgs.pkgName} \
                --set WASMTIME_NEW_CLI 0 \
                --add-flags "$out/lib/${finalArgs.pkgName}.wasm" \
                --add-flags "--"
            '';
          };

        buildRustWasmEdgeExec = pkgs: args:
          let
            finalArgs = self.lib.handleArgs args;
            wasmPkg = self.lib.buildRustWasiWasm pkgs {
              inherit (finalArgs) name src;
            };
          in
          pkgs.stdenv.mkDerivation rec {
            name = finalArgs.name;
            src = finalArgs.src;
            nativeBuildInputs = with pkgs; [ makeWrapper ];
            installPhase = ''
              mkdir -p $out/lib
              cp ${wasmPkg}/bin/${finalArgs.name}.wasm $out/lib/${finalArgs.pkgName}.wasm
              makeWrapper ${pkgs.wasmedge}/bin/wasmedge $out/bin/${finalArgs.pkgName} \
                --add-flags "$out/lib/${finalArgs.pkgName}.wasm"
            '';
          };

        buildRustWasmPackage = pkgs: args:
          let
            finalArgs = self.lib.handleArgs args;
            wasmPkg = self.lib.buildRustWasiWasm pkgs {
              inherit (finalArgs) name src;
            };
          in
          pkgs.stdenv.mkDerivation {
            name = finalArgs.name;
            src = finalArgs.src;
            buildInputs = with pkgs; [
              # includes wasm-strip, wasm2wat, wasm-stats, wasm-objdump, and wasm-validate
              wabt
            ];
            buildPhase = ''
              mkdir -p $out/{lib,share}
              cp ${wasmPkg}/bin/${finalArgs.name}.wasm $out/lib/${finalArgs.pkgName}.wasm
              wasm-strip $out/lib/${finalArgs.pkgName}.wasm -o $out/lib/${finalArgs.pkgName}-stripped.wasm
              wasm2wat $out/lib/${finalArgs.pkgName}.wasm > $out/share/${finalArgs.pkgName}.wat
              wasm-stats $out/lib/${finalArgs.pkgName}.wasm -o $out/share/${finalArgs.pkgName}.dist
              wasm-objdump \
                --details $out/lib/${finalArgs.pkgName}.wasm > $out/share/${finalArgs.pkgName}-dump.txt
            '';
            checkPhase = ''
              wasm-validate $out/lib/${finalArgs.pkgName}.wasm
              wasm-validate $out/lib/${finalArgs.pkgName}-stripped.wasm
            '';
            doCheck = true;
          };
      };
    };
}
