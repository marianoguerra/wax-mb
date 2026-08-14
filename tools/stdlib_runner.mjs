import { readFile } from "node:fs/promises";

const [wasmPath, casesPath] = process.argv.slice(2);
if (!wasmPath || !casesPath) {
  console.error("usage: node tools/stdlib_runner.mjs <stdlib.wasm> <utf8-cases.txt>");
  process.exit(2);
}

const bytes = await readFile(wasmPath);
const { instance } = await WebAssembly.instantiate(bytes, {});

for (const name of ["stdlib_boundaries", "stdlib_properties"]) {
  let result;
  try {
    result = instance.exports[name]();
  } catch (error) {
    const stage = instance.exports.stdlib_stage?.();
    throw new Error(`${name} trapped at stage ${stage}`, { cause: error });
  }
  if (result !== 1) throw new Error(`${name} returned ${result}`);
}

const lines = (await readFile(casesPath, "utf8"))
  .split("\n")
  .slice(0, -1);
const decoder = new TextDecoder("utf-8", { fatal: true });
for (const [index, line] of lines.entries()) {
  const input = line === "" ? [] : line.split(",").map(Number);
  let expected = 1;
  try {
    decoder.decode(Uint8Array.from(input));
  } catch (error) {
    if (error instanceof TypeError) expected = 0;
    else throw error;
  }
  const actual = instance.exports[`stdlib_utf8_case_${index}`]();
  if (actual !== expected) {
    throw new Error(
      `UTF-8 oracle mismatch in case ${index}: expected ${expected}, got ${actual}; bytes=${line}`,
    );
  }
}

for (const name of [
  "stdlib_invalid_set_transient",
  "stdlib_invalid_jv_vector_transient",
  "stdlib_invalid_jv_map_transient",
  "stdlib_invalid_jv_set_transient",
]) {
  let trapped = false;
  try {
    instance.exports[name]();
  } catch (error) {
    if (error instanceof WebAssembly.RuntimeError) trapped = true;
    else throw error;
  }
  if (!trapped) throw new Error(`${name} did not trap after persistent()`);
}

console.log(
  `immutable stdlib runtime checks passed (${lines.length} TextDecoder UTF-8 oracle cases)`,
);
