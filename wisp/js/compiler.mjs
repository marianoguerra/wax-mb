// Pass the generated MoonBit bridge as an argument so apps control bundling.
import {standardSchemas} from './protocols.mjs';
export function createCompiler(bridge) {
  return function compile(source, modules = {}, protocolSchemas = {}) {
    protocolSchemas = {...standardSchemas, ...protocolSchemas};
    const protocols = Object.fromEntries(Object.entries(protocolSchemas).map(([id, schema]) => [id, Object.keys(schema.operations)]));
    const result = JSON.parse(bridge.compile_json(JSON.stringify({source, modules, protocols})));
    if (result.error) throw new Error(result.error);
    return Object.freeze({wasm: Uint8Array.from(result.wasm), manifest: {...result.manifest, protocolSchemas: structuredClone(protocolSchemas)}, wat: result.wat});
  };
}
