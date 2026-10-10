// Extracts the shaders embedded in web/index.html into standalone files so
// they can be validated offline:
//   <out>/fractal.wgsl  WebGPU vertex + fragment shader (wgslShader)
//   <out>/fractal.vert  WebGL2 vertex shader (glslVS)
//   <out>/fractal.frag  WebGL2 fragment shader (glslFS)
//
// Usage: node scripts/extract-shaders.mjs [out-dir]   (default: build/shaders)

import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const outDir = resolve(process.argv[2] ?? join(root, 'build', 'shaders'));
const html = readFileSync(join(root, 'web', 'index.html'), 'utf8');

const shaders = [
  ['wgslShader', 'fractal.wgsl'],
  ['glslVS', 'fractal.vert'],
  ['glslFS', 'fractal.frag'],
];

mkdirSync(outDir, { recursive: true });
for (const [name, file] of shaders) {
  const match = html.match(new RegExp(`const ${name} = \`([\\s\\S]*?)\`;`));
  if (!match) {
    console.error(`error: template literal "${name}" not found in web/index.html`);
    process.exit(1);
  }
  if (match[1].includes('${')) {
    console.error(`error: "${name}" contains a template substitution; extract it at runtime instead`);
    process.exit(1);
  }
  // GLSL requires #version on the first line, so drop only leading blank lines.
  const source = match[1].replace(/^\s*\n/, '');
  writeFileSync(join(outDir, file), source);
  console.log(`wrote ${join(outDir, file)} (${source.split('\n').length} lines)`);
}
