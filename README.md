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
nix build ".#wasm"
```

This generates a Wasm binary in `result/nix-wasm-example.wasm`.

### Build a [stripped] binary

```shell
nix build ".#stripped"
```

This generates a [stripped] Wasm binary in `result/nix-wasm-example-stripped.wasm`.

### Generate opcode usage

```shell
nix build ".#opcode"
```

This generates a `.dist` file in `result/nix-wasm-example.dist`.

### Build a WebAssembly text format (WAT) file

```shell
nix build ".#wat"
```

This generates a [WAT] file in `result/nix-wasm-example.wat`.

### Build everything

```shell
nix build

# shorthand for:
nix build ".#all"
```

This generates several files in `result`[^1]:

* `nix-wasm-example.wasm`
* `nix-wasm-example.dist`
* `nix-wasm-example.wat`
* `nix-wasm-example-stripped.wasm`

### Test

```shell
cargo test
```

### Run

```shell
run-wasm

# Run the stripped version
run-wasm-stripped
```

### Validate

```shell
validate-wasm
```

## Advantages of Nix for Wasm development

Building Wasm tends to be tricky because:

* Many languages can build Wasm
* Successful development environments often involve multiple tools, compilers, runtimes, etc.
* Tying everything together with scripts can get kludgey
* Nix development environments can support many platforms

[dev]: https://zero-to-nix.com/concepts/dev-env
[direnv]: https://direnv.net
[dni]: https://github.com/DeterminateSystems/nix-installer
[nix]: https://zero-to-nix.com
[store]: https://zero-to-nix.com/concepts/nix-store
[stripped]: https://webassembly.github.io/wabt/doc/wasm-strip.1.html
[wasm]: https://webassembly.org
[wat]: https://developer.mozilla.org/docs/WebAssembly/Understanding_the_text_format

[^1]: `result` isn't a directory but rather a symlink to the build result in the [Nix store][store].
