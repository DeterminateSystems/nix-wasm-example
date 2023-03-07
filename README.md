# Nix + WebAssembly example project

This repo houses an example project that uses [Nix] to build [WebAssembly][wasm] (Wasm).

## Setup

First, make sure that Nix is installed. If not, use the [Determinate Nix Installer][dni]:

```shell
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
  | sh -s -- install
```

With Nix installed, you can activate the [development environment][dev]:

```shell
nix develop
```

> **Note**: This should happen automatically if you have [direnv] installed.

## Actions

### Build Wasm binary

```shell
nix build

# shorthand for:
nix build .#wasm
```

This generates a Wasm binary in `result/nix-wasm-example.wasm`.

### Build a WebAssembly text format (WAT) file

```shell
nix build .#wat
```

This generates a [WAT] file in `result/nix-wasm-example.wat`.

### Test

```shell
cargo test
```

### Run

```shell
check-run
```

### Validate

```shell
check-validate
```

## Advantages of Nix for Wasm development

Building Wasm tends to be tricky because:

* Many languages can build Wasm
* Successful development environments often involve multiple tools, compilers, runtimes, etc.
* Tying everything together with scripts can get kludgey

[dev]: https://zero-to-nix.com/concepts/dev-env
[direnv]: https://direnv.net
[dni]: https://github.com/DeterminateSystems/nix-installer
[nix]: https://zero-to-nix.com
[wasm]: https://webassembly.org
[wat]: https://developer.mozilla.org/docs/WebAssembly/Understanding_the_text_format
