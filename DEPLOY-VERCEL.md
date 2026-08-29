# Deploying this fork to Vercel

`vercel.json` and `scripts/vercel-build.sh` in this repo configure a static
deployment of the studio app (`packages/app/studio`). They exist because a
default Vercel import of openDAW fails in three separate ways.

## What the config solves

### 1. Rust is not in the Vercel build image

`@opendaw/studio-core-wasm` compiles the WASM audio engine from `crates/`. It
needs `rustup`, the `wasm32-unknown-unknown` target, and a **nightly**
toolchain with `rust-src` (the device crates build with `-Zbuild-std=core`).
Without them, vite cannot resolve the package and the build dies with a
pre-transform error, because `packages/studio/core-wasm/dist` is never created.

`scripts/vercel-build.sh` installs all of it before running `npm run build`.

### 2. Vercel sets `CI=true`, which breaks every asset URL

`packages/app/studio/vite.config.ts` contains:

```ts
const isCI = process.env.CI === "true"
const base = (command === "build" && isCI) ? `/${envFolder}/releases/${uuid}/` : "/"
```

That is correct for openDAW's own release CDN, which publishes builds under
`/main/releases/<uuid>/`. Vercel serves from the domain root, so leaving
`CI=true` produces an `index.html` whose every `<script>` and `<link>` points at
a directory that does not exist — a blank page and a 404 on first script load.

The build script exports `CI=false` to keep `base` at `/`.

### 3. Cross-origin isolation headers

openDAW uses `SharedArrayBuffer` for WASM threads, AudioWorklets and
onnxruntime. Browsers only expose it on a cross-origin-isolated page, which
requires two **real HTTP response headers**:

```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

Vite sets these on its dev and preview servers, and `index.html` carries
`<meta http-equiv="...">` fallbacks — but **browsers ignore COOP and COEP as
meta tags**. They must come from the server, so `vercel.json` sets them for all
routes. Without this the build succeeds and the app then fails at runtime with
the audio engine dead.

## Deploying

The project is a static build; no Vercel Functions are involved.

```bash
vercel link
vercel --prod
```

Or import the repo in the Vercel dashboard — `vercel.json` is picked up
automatically. Leave the framework preset as **Other**; the build command,
output directory and install command all come from `vercel.json`.

**Node version:** the root `package.json` declares `engines.node: ">=23"`, which
Vercel resolves to its 24.x line. If a deployment reports an unsupported engine,
set Node.js 24.x explicitly in Project Settings → General.

**Build time:** expect a slow first build. Installing the Rust toolchain adds
several minutes on top of `npm install` and the turbo build. Subsequent builds
reuse Vercel's cache for `node_modules` but not for `~/.cargo`, so the Rust
install cost repeats on every cold build.

## Licence

openDAW is AGPL v3. The licence is triggered by **network use**, not just
distribution: anyone interacting with your deployed instance is entitled to the
corresponding source. Keeping this repository public satisfies that.
