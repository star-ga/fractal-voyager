#!/usr/bin/env bash
# Builds src/main.mind with the public mindc release and runs its known-answer
# checks, without the licensed MIND CPU runtime.
#
# `mindc run` links the compiled kernel against the MIND CPU runtime, which the
# public mindc release does not ship ("MIND runtime not found for backend
# 'cpu'"). The kernel itself only needs two output helpers from that runtime
# (printI64, printNewline), so this script takes the compiler's own MLIR
# output, lowers it with the stock LLVM toolchain, links it against a tiny
# shim for those two helpers and runs it.
#
# Requires mindc, mlir-opt, mlir-translate and clang on PATH (CI uses LLVM 20).
#
# Usage: scripts/run-checks.sh [out-dir]   (default: build/kernel)
# Exit status: 0 when every check passes, non-zero otherwise.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="${1:-$root/build/kernel}"
mkdir -p "$out"

for tool in mindc mlir-opt mlir-translate clang; do
  command -v "$tool" >/dev/null || { echo "error: $tool not found on PATH" >&2; exit 2; }
done

mindc "$root/src/main.mind" --emit-mlir > "$out/main.mlir"

mlir-opt "$out/main.mlir" \
  --convert-arith-to-llvm \
  --convert-cf-to-llvm \
  --convert-func-to-llvm \
  --reconcile-unrealized-casts \
  -o "$out/main.llvm.mlir"

mlir-translate --mlir-to-llvmir "$out/main.llvm.mlir" -o "$out/main.ll"

clang -O2 -Wno-override-module "$out/main.ll" "$root/scripts/print-shim.c" -o "$out/fractal-voyager"

# main() prints the number of failed checks on its last line and returns it.
# Require both a zero exit status and a printed count of exactly 0, so a count
# that wraps modulo 256 in the exit status cannot pass.
set +e
"$out/fractal-voyager" > "$out/output.txt"
status=$?
set -e
cat "$out/output.txt"

failed="$(tail -n 1 "$out/output.txt")"
if [[ "$status" -ne 0 || "$failed" != "0" ]]; then
  echo "error: known-answer checks failed (exit $status, failed count '$failed')" >&2
  exit 1
fi
echo "all known-answer checks passed"
