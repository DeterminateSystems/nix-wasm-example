# Nix + WebAssembly example project

This repo houses an example project that uses [Nix] to build and hack on [WebAssembly][wasm] (Wasm) in [Rust].

## Setup

First, make sure that [Nix] is installed with [flakes] enabled. We recommend using our [Determinate Nix Installer][dni]:

```shell
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
  | sh -s -- install
```

With Nix installed, you can activate the [development environment][dev]:

```shell
nix develop
```

> **Note**: This should happen automatically if you have [direnv] installed and run `direnv allow`.

## Packages

Below are some packages you can build in this project.

### Build Wasm binary

To build a Wasm executable from the [Rust sources](./src/main.rs):

```shell
nix build ".#wasm-rust"
```

This generates a Wasm binary at `result/bin/hello-wasm.wasm`.

### Build a [stripped] binary

```shell
nix build ".#stripped"
```

This generates a [stripped] Wasm binary at `result/bin/hello-wasm-stripped.wasm`.

### Generate [stats]

```shell
nix build ".#stats"
```

This generates a `.dist` file at `result/share/hello-wasm.dist`.

### Build a WebAssembly text format ([WAT]) file

```shell
nix build ".#wat"
```

This generates a human-readable `.wat` file at `result/share/hello-wasm.wat`.

### Generate an [object dump][objdump]

```shell
nix build ".#objdump"
```

This generates `.txt` file at `result/share/hello-wasm-dump-txt`.

### Build everything

```shell
nix build

# shorthand for both of these:
nix build ".#default"
nix build ".#wasm-all"
```

This generates several files in `result`[^1]:

* `bin/hello-wasm.wasm` (the raw binary)
* `bin/hello-wasm-stripped.wasm` (the [stripped] version of the binary)
* `share/hello-wasm-dump.txt` (the )
* `share/hello-wasm.dist` (the [stats] file)
* `share/hello-wasm.wat` (the human-readable [WAT] file)

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

* Many languages can build Wasm but creating multi-language development environments (without Nix, of course) is hard.
* Successful Wasm development environments often a wide range of tools, compilers, runtimes, etc.
* Nix can not only provide arbitrarily complex development environments but it can do so across Unix-based platforms.

[dev]: https://zero-to-nix.com/concepts/dev-env
[direnv]: https://direnv.net
[dni]: https://github.com/DeterminateSystems/nix-installer
[flakes]: https://zero-to-nix.com/concepts/flakes
[nix]: https://zero-to-nix.com
[objdump]: https://webassembly.github.io/wabt/doc/wasm-objdump.1.html
[rust]: https://rust-lang.org
[stats]: https://pengowray.github.io/wasm-ops
[store]: https://zero-to-nix.com/concepts/nix-store
[stripped]: https://webassembly.github.io/wabt/doc/wasm-strip.1.html
[wasm]: https://webassembly.org
[wat]: https://developer.mozilla.org/docs/WebAssembly/Understanding_the_text_format

[^1]: `result` isn't a local directory but rather a symlink to the build result directory in the
  [Nix store][store]. It should have a path of the form `/nix/store/${HASH}-wasm-all`.
