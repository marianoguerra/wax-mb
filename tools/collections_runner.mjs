import { readFile } from "node:fs/promises";

const path = process.argv[2];
if (!path) {
  console.error("usage: node tools/collections_runner.mjs <properties.wasm>");
  process.exit(2);
}

const bytes = await readFile(path);
const { instance } = await WebAssembly.instantiate(bytes, {});

for (const name of ["collections_boundaries", "collections_properties"]) {
  let result;
  try {
    result = instance.exports[name]();
  } catch (error) {
    const stage = instance.exports.collections_stage?.();
    throw new Error(`${name} trapped at stage ${stage}`, { cause: error });
  }
  if (result !== 1) throw new Error(`${name} returned ${result}`);
}

for (const name of [
  "collections_invalid_map_transient",
  "collections_invalid_vector_transient",
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

console.log("collections Wax runtime checks passed");
