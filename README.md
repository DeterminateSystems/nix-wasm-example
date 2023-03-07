# Nix + WebAssembly example project

This repo houses an example project that uses [Nix] to build [WebAssembly][wasm] (Wasm).

## Setup

First, make sure that Nix is installed. If not, use the [Determinate Nix Installer][dni]:

```shell
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
  | sh -s -- install
```

With Nix installed, you can activatee the [development environment][dev]:

```shell
nix develop
```

> **Note**: This should happen automatically if you have [direnv] installed.

## Build

```shell
nix build
```

## Test

```shell
cargo test
```

## Run

```shell
check-run
```

## Validate

```shell
check-validate
```

[dev]: https://zero-to-nix.com/concepts/dev-env
[direnv]: https://direnv.net
[dni]: https://github.com/DeterminateSystems/nix-installer
[nix]: https://zero-to-nix.com
[wasm]: https://webassembly.org
