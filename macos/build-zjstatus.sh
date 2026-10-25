#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source_revision=7e6dbfd43a1c7431f3969d9a565bcd6d5bbdce45
rust_toolchain=1.95.0
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/myconf-zjstatus.XXXXXX")"
trap 'rm -rf -- "$build_dir"' EXIT

rustup toolchain install "$rust_toolchain" --profile minimal --target wasm32-wasip1
git clone --quiet --no-checkout https://github.com/dj95/zjstatus.git "$build_dir/source"
git -C "$build_dir/source" checkout --quiet --detach "$source_revision"
git -C "$build_dir/source" apply "$repo_dir/.config/zellij/plugins/zjstatus-powerline.patch"
(
    cd -- "$build_dir/source"
    cargo +"$rust_toolchain" build --locked --release --target wasm32-wasip1 --bin zjstatus
)
install -m 644 "$build_dir/source/target/wasm32-wasip1/release/zjstatus.wasm" \
    "$repo_dir/.config/zellij/plugins/zjstatus.wasm"
