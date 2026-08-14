import { readFile } from "node:fs/promises";
import { performance } from "node:perf_hooks";

const path = process.argv[2];
const size = Number(process.argv[3] ?? 10_000);
if (!path || !Number.isSafeInteger(size) || size < 1) {
  console.error("usage: node tools/collections_bench.mjs <collections.wasm> [size]");
  process.exit(2);
}

const bytes = await readFile(path);
const { instance } = await WebAssembly.instantiate(bytes, {});
const names = [
  "collections_bench_map_persistent",
  "collections_bench_map_transient",
  "collections_bench_vector_persistent",
  "collections_bench_vector_transient",
];

function median(values) {
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.floor(sorted.length / 2)];
}

const results = {};
for (const name of names) {
  const fn = instance.exports[name];
  fn(Math.min(size, 512));
  const samples = [];
  let checksum;
  for (let run = 0; run < 7; run += 1) {
    const start = performance.now();
    checksum = fn(size);
    samples.push(performance.now() - start);
  }
  results[name] = {
    median_ms: Number(median(samples).toFixed(3)),
    min_ms: Number(Math.min(...samples).toFixed(3)),
    checksum,
  };
}

if (results.collections_bench_map_persistent.checksum !==
    results.collections_bench_map_transient.checksum) {
  throw new Error("map benchmark variants produced different checksums");
}
if (results.collections_bench_vector_persistent.checksum !==
    results.collections_bench_vector_transient.checksum) {
  throw new Error("vector benchmark variants produced different checksums");
}

console.log(JSON.stringify({ size, runs: 7, results }, null, 2));
