#!/usr/bin/env bash
#
# Vercel build entrypoint for the openDAW studio app.
#
# Vercel's build image ships neither Rust nor a WASM target, and it exports
# CI=true, which openDAW's vite config interprets as "this is the official
# release pipeline". Both need handling before `npm run build` produces
# something a static host can actually serve.
#
set -euo pipefail

# ---------------------------------------------------------------------------
# 1. Rust toolchain for the WASM audio engine (@opendaw/studio-core-wasm).
#    Without it, vite fails to resolve that package because
#    packages/studio/core-wasm/dist is never produced.
# ---------------------------------------------------------------------------
if ! command -v cargo >/dev/null 2>&1; then
  echo "--- installing rustup (not present in the Vercel build image)"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --default-toolchain stable --profile minimal --no-modify-path
fi
export PATH="$HOME/.cargo/bin:$PATH"

echo "--- adding wasm32 target and nightly toolchain"
rustup target add wasm32-unknown-unknown
# The device crates build with -Zbuild-std=core, which requires nightly + rust-src.
rustup toolchain install nightly --profile minimal
rustup component add rust-src --toolchain nightly

rustc --version
cargo --version

# ---------------------------------------------------------------------------
# 2. Neutralise CI=true.
#
#    packages/app/studio/vite.config.ts contains:
#
#        const isCI = process.env.CI === "true"
#        const base = (command === "build" && isCI)
#            ? `/${envFolder}/releases/${uuid}/`
#            : "/"
#
#    That path layout is correct for openDAW's own release CDN, where builds
#    are published under /main/releases/<uuid>/. On Vercel the output is served
#    from the domain root, so leaving CI=true makes every asset URL point at a
#    directory that does not exist and the app 404s on first script load.
# ---------------------------------------------------------------------------
export CI=false

echo "--- building (base=/)"
npm run build
