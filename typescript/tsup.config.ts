import { defineConfig } from 'tsup';

export default defineConfig([
  // Main bundle (browser + universal)
  {
    entry: ['src/index.ts'],
    format: ['esm', 'cjs'],
    dts: true,
    clean: true,
    sourcemap: true,
    minify: false,
    target: 'es2022',
    outDir: 'dist',
  },
  // Node.js specific bundle
  {
    entry: ['src/node.ts'],
    format: ['esm', 'cjs'],
    dts: true,
    sourcemap: true,
    minify: false,
    target: 'node18',
    outDir: 'dist',
    external: ['fs', 'fs/promises', 'path'],
  },
]);
