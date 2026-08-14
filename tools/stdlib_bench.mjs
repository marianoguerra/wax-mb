import { readFile } from "node:fs/promises";

const [wasmPath, sizeText = "10000", roundsText = "5"] = process.argv.slice(2);
if (!wasmPath) {
  console.error("usage: node tools/stdlib_bench.mjs <stdlib.wasm> [size] [rounds]");
  process.exit(2);
}

const size = Number.parseInt(sizeText, 10);
const rounds = Number.parseInt(roundsText, 10);
if (!Number.isInteger(size) || size < 1 || size > 400000) {
  throw new Error("size must be an integer between 1 and 400000");
}
if (!Number.isInteger(rounds) || rounds < 1 || rounds > 1000) {
  throw new Error("rounds must be an integer between 1 and 1000");
}

const bytes = await readFile(wasmPath);
const { instance } = await WebAssembly.instantiate(bytes, {});

function measure(name, args, samples = 7) {
  instance.exports[name](...args);
  const times = [];
  let checksum = 0;
  for (let sample = 0; sample < samples; sample += 1) {
    const start = process.hrtime.bigint();
    checksum ^= instance.exports[name](...args);
    const elapsed = Number(process.hrtime.bigint() - start) / 1e6;
    times.push(elapsed);
  }
  times.sort((a, b) => a - b);
  return {
    median: times[Math.floor(times.length / 2)],
    minimum: times[0],
    checksum,
  };
}

for (const [label, name, args] of [
  ["UTF-8 validate/hash", "stdlib_bench_utf8", [size, rounds]],
  ["persistent value build", "stdlib_bench_persistent", [size, rounds]],
  ["transient value build", "stdlib_bench_transient", [size, rounds]],
]) {
  const result = measure(name, args);
  console.log(
    `${label.padEnd(24)} median=${result.median.toFixed(2)}ms min=${result.minimum.toFixed(2)}ms checksum=${result.checksum}`,
  );
}
