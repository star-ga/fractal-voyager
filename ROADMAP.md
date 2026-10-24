# Roadmap

The explorer's WGSL and GLSL shaders are today written by hand and checked against
the MIND kernel by known-answer tests. The roadmap makes the MIND kernel their
source.

1. **Shaders generated from `src/main.mind`.** The WGSL and GLSL ES 3.00 fragment
   shaders embedded in `web/index.html` are emitted by the MIND toolchain from the
   kernel, checked in with the generating command and the generator's hash.
   `scripts/extract-shaders.mjs` becomes the drift check: CI regenerates the
   shaders and fails if the embedded text differs. The known-answer checks keep
   running against the same kernel. Done when CI regenerates, `naga` and
   `glslangValidator` accept the output, the page renders from the generated
   shaders, and the README's provenance sentence is rewritten from the CI run.
   Status: blocked on a WGSL/GLSL emission target in the compiler.
2. **Port the remaining shader paths to the kernel.** Smooth iteration count and
   the Neon, Psychedelic, Plasma and Galaxy palettes need `log`/`sin`; port them
   once f64 crosses a module boundary in the compiler, so item 1 covers the whole
   shader, not a subset.
3. **Native build of the reference.** Replace the MLIR + clang shim in
   `scripts/run-checks.sh` with the compiler's native backend once f64 is admitted
   there; same known-answer checks.
