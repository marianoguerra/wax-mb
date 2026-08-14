import { readFile } from "node:fs/promises";
import { performance } from "node:perf_hooks";

const path = process.argv[2];
const size = Number(process.argv[3] ?? 4096);
const rounds = Number(process.argv[4] ?? 2000);
if (!path || !Number.isSafeInteger(size) || !Number.isSafeInteger(rounds) ||
    size < 1 || rounds < 1) {
  console.error("usage: node tools/hashing_bench.mjs <hashing.wasm> [size] [rounds]");
  process.exit(2);
}

const bytes = await readFile(path);
const { instance } = await WebAssembly.instantiate(bytes, {});
const fn = instance.exports.hashing_bench;
fn(Math.min(size, 256), Math.min(rounds, 100));
const samples = [];
let checksum;
for (let run = 0; run < 7; run += 1) {
  const start = performance.now();
  const nextChecksum = fn(size, rounds);
  if (checksum !== undefined && nextChecksum !== checksum) {
    throw new Error("benchmark checksum changed between identical runs");
  }
  checksum = nextChecksum;
  samples.push(performance.now() - start);
}
samples.sort((a, b) => a - b);
console.log(JSON.stringify({
  algorithm: "MurmurHash3_x86_32",
  bytes_per_hash: size,
  hashes_per_run: rounds,
  runs: samples.length,
  median_ms: Number(samples[3].toFixed(3)),
  min_ms: Number(samples[0].toFixed(3)),
  mib_per_second: Number(
    ((size * rounds) / (samples[3] / 1000) / (1024 * 1024)).toFixed(2),
  ),
  checksum,
}, null, 2));
