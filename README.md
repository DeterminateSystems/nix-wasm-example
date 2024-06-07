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

To build a Wasm binary from the [Rust sources](./src/main.rs):

```shell
nix build ".#hello-wasm"
```

This generates a [stripped] Wasm binary at `result/lib/hello-wasm.wasm` (where `result` is a symlink to a [Nix store][store] path).

### Build a full Wasm package

To build a Wasm binary from the Rust sources plus some other goodies:

```shell
nix build ".#hello-wasm-pkg"

# Inspect the package
tree result
```

Inside the package you should see:

* `lib/hello-wasm.wasm` (the same [stripped] binary from [above](#build-wasm-binary))
* `share/hello-wasm-dump.txt` (an [object dump][objdump])
* `share/hello-wasm.dist` (a [stats] file)
* `share/hello-wasm.wat` (a human-readable [WAT] file)

### Run the binary

You can also run the compiled binary using two different Wasm runtimes.

To run it using [WasmEdge]:

```shell
nix run ".#hello-wasmedge-exec"
```

To run it using [Wasmtime]:

```shell
nix run ".#hello-wasmtime-exec"
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
[stats]: https://webassembly.github.io/wabt/doc/wasm-stats.1.html
[store]: https://zero-to-nix.com/concepts/nix-store
[stripped]: https://webassembly.github.io/wabt/doc/wasm-strip.1.html
[wasm]: https://webassembly.org
[wasmedge]: https://wasmedge.org
[wasmtime]: https://docs.wasmtime.dev
[wat]: https://developer.mozilla.org/docs/WebAssembly/Understanding_the_text_format

[^1]: `result` isn't a local directory but rather a symlink to the build result directory in the
  [Nix store][store]. It should have a path of the form `/nix/store/${HASH}-wasm-all`.
