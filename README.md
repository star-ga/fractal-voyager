<p align="center">
  <img src="assets/logo.svg" alt="Fractal Voyager logo" width="96" height="96">
</p>

<h1 align="center">Fractal Voyager</h1>

<p align="center">
  Real-time fractal explorer for the browser: WebGPU with a WebGL2 fallback, plus a MIND reference kernel with known-answer checks.
</p>

<p align="center">
  <a href="https://mindlang.dev/demo/fractal/"><img alt="Live demo" src="https://img.shields.io/badge/Demo-Live-brightgreen"></a>
  <a href="https://github.com/star-ga/fractal-voyager/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/star-ga/fractal-voyager/actions/workflows/ci.yml/badge.svg"></a>
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/License-MIT-yellow"></a>
</p>

**[Open the live demo](https://mindlang.dev/demo/fractal/)** (part of the [mindlang.dev](https://mindlang.dev) showcase).

## What it is

Fractal Voyager renders the Mandelbrot set, a Julia set, the Burning Ship and the Tricorn in real time, with smooth zoom and pan, eight colour palettes and optional audio-reactive colour (microphone or a music file).

It has two parts:

- **`web/`** is the explorer: a single self-contained page. It draws a full-screen triangle pair and runs the fractal per pixel in a fragment shader, written in WGSL for WebGPU and in GLSL ES 3.00 for WebGL2.
- **`src/main.mind`** is a reference of the same per-pixel kernel in [MIND](https://github.com/star-ga/mind). Running it executes known-answer checks that pin down the escape-time maths the shaders implement.

## Status

- The web explorer runs from this repository as-is; no build step.
- The MIND reference builds and passes its checks with the released `mindc` v0.10.2 (CPU target).
- The shaders are written by hand. The public `mindc` release does not generate WGSL or GLSL; the MIND kernel is a checked reference for the shader maths, not their source.
- CI compiles and runs the MIND checks and validates every shader (WGSL with naga, GLSL with glslang).

## Quick start

### Run the explorer locally

```bash
git clone https://github.com/star-ga/fractal-voyager.git
cd fractal-voyager/web
python3 -m http.server 8080
# open http://localhost:8080
```

WebGPU is used by default in Chromium-based browsers; every other browser starts on WebGL2. Force a renderer with `?renderer=webgpu` or `?renderer=webgl2`.

| Browser | WebGPU |
|---------|--------|
| Chrome / Edge 113+ (Windows, macOS, ChromeOS) | on by default |
| Firefox 141+ (Windows), 147+ (Apple silicon macOS) | on by default |
| Safari 26+ (macOS Tahoe, iOS/iPadOS 26) | on by default |
| Linux | varies by browser and GPU; the page falls back to WebGL2 when WebGPU is unavailable |

### Build and check the MIND reference

Requires `mindc` and an LLVM toolchain with `mlir-opt`, `mlir-translate` and `clang` on `PATH` (CI uses LLVM 20 on Ubuntu 24.04).

```bash
curl -sSL https://mindlang.dev/install.sh | sh   # installs mindc
mindc check src/main.mind                        # format, lint and type check
mindc run                                        # build, run the checks
echo $?                                          # 0 = all checks passed
```

The exit code is the number of failed checks.

### Validate the shaders

```bash
node scripts/extract-shaders.mjs build/shaders   # pull the shaders out of web/index.html
naga build/shaders/fractal.wgsl                  # cargo install naga-cli
naga web/dist/fractal.wgsl
glslangValidator build/shaders/fractal.vert      # apt install glslang-tools
glslangValidator build/shaders/fractal.frag
```

## How it uses MIND

`src/main.mind` mirrors the fragment shaders term for term:

- **View mapping:** pixel centre to a point on the complex plane, with a visible height of `3.5 / zoom` and the aspect ratio applied horizontally.
- **Escape-time iteration** for all four fractals with escape radius 256, including the O(1) main-cardioid and period-2-bulb test that skips interior Mandelbrot points.
- **Palettes** Electric, Fire, Ocean and Grayscale, packed to 8-bit RGB.

`mindc run` checks single points, the cardioid test, palette colours and whole 48 × 27 frames for each fractal. Each frame is checked at zoom 1 with 100 iterations and at zoom 2 with 130 iterations, which is the demo's own iteration budget at that zoom. The expected values come from an independent double-precision implementation of the same definitions.

The reference computes in `f64` and the shaders in `f32`, so escape counts agree away from the set boundary and may differ for boundary pixels. The smooth (fractional) iteration count and the Neon, Psychedelic, Plasma and Galaxy palettes need `log`/`sin` and are not ported yet; the reasons are noted in the source.

## Controls

| Input | Action |
|-------|--------|
| Scroll / pinch | Zoom |
| Drag | Pan |
| `1` `2` `3` `4` | Mandelbrot, Julia, Burning Ship, Tricorn |
| `C` | Next colour palette |
| `A` | Toggle microphone audio |
| `M` | Load a music file |
| `Z` | Toggle auto-zoom |
| `R` | Reset view |

Palettes: Electric, Fire, Ocean, Neon, Grayscale, Psychedelic, Plasma, Galaxy.

## Repository layout

| Path | Contents |
|------|----------|
| `web/index.html` | The explorer, with its WGSL and GLSL shaders inline |
| `web/dist/fractal.wgsl` | A standalone compute-shader variant of the kernel (not used by the page) |
| `web/mindlang.mp3` | Default soundtrack for audio-reactive mode |
| `src/main.mind` | MIND reference kernel and known-answer checks |
| `Mind.toml` | MIND project manifest |
| `scripts/extract-shaders.mjs` | Extracts the inline shaders for validation |
| `.github/workflows/ci.yml` | CI: MIND checks and shader validation |

## License

MIT. See [LICENSE](LICENSE).

Copyright (c) 2026 STARGA Inc.

## Links

- Live demo: <https://mindlang.dev/demo/fractal/>
- MIND language: <https://mindlang.dev>
- MIND compiler: <https://github.com/star-ga/mind>
