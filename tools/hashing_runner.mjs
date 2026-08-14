import { readFile } from "node:fs/promises";

const [wasmPath, referenceOutputPath] = process.argv.slice(2);
if (!wasmPath || !referenceOutputPath) {
  console.error("usage: node tools/hashing_runner.mjs <hashing.wasm> <reference-output>");
  process.exit(2);
}

const bytes = await readFile(wasmPath);
const { instance } = await WebAssembly.instantiate(bytes, {});
const exports = instance.exports;

for (const name of ["hashing_boundaries", "hashing_properties"]) {
  const result = exports[name]();
  if (result !== 1) throw new Error(`${name} returned ${result}`);
}

const reference = (await readFile(referenceOutputPath, "utf8"))
  .trim()
  .split("\n")
  .map((line) => Number.parseInt(line, 16) >>> 0);
if (reference.length !== 512) {
  throw new Error(`reference emitted ${reference.length} cases, expected 512`);
}
for (let index = 0; index < reference.length; index += 1) {
  const actual = exports.hashing_reference_case(index) >>> 0;
  if (actual !== reference[index]) {
    throw new Error(
      `Murmur3 reference mismatch at case ${index}: ` +
      `Wax=${actual.toString(16)}, C=${reference[index].toString(16)}`,
    );
  }
}

function popcnt32(value) {
  value -= (value >>> 1) & 0x55555555;
  value = (value & 0x33333333) + ((value >>> 2) & 0x33333333);
  return (((value + (value >>> 4)) & 0x0f0f0f0f) * 0x01010101) >>> 24;
}

const buckets = new Uint32Array(1024);
const hashes = new Set();
let collisions = 0;
for (let value = 0; value < 32768; value += 1) {
  const hash = exports.hashing_i31_case(value) >>> 0;
  buckets[hash & 1023] += 1;
  if (hashes.has(hash)) collisions += 1;
  hashes.add(hash);
}
const minBucket = Math.min(...buckets);
const maxBucket = Math.max(...buckets);
if (minBucket < 12 || maxBucket > 56 || collisions > 3) {
  throw new Error(
    `distribution gate failed: buckets=${minBucket}..${maxBucket}, ` +
    `collisions=${collisions}`,
  );
}

let changedBits = 0;
let comparisons = 0;
for (const base of [0, 1, 0x1234567, 0x3fffffff]) {
  const original = exports.hashing_i31_case(base) >>> 0;
  for (let bit = 0; bit < 30; bit += 1) {
    const changed = exports.hashing_i31_case(base ^ (1 << bit)) >>> 0;
    changedBits += popcnt32(original ^ changed);
    comparisons += 1;
  }
}
const avalanche = changedBits / comparisons;
if (avalanche < 13 || avalanche > 19) {
  throw new Error(`avalanche gate failed: ${avalanche} changed bits on average`);
}

console.log(
  `hashing checks passed: 512 C cases, buckets=${minBucket}..${maxBucket}, ` +
  `collisions=${collisions}, avalanche=${avalanche.toFixed(2)}`,
);
