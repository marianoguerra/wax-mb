// The name section.
//
// Ported from the `name` custom section of wax/src/lib-wasm/wasm_output.ml.
//
// Names are the one part of a module the runtime ignores entirely, and the one
// part a reader depends on. Every index space gets its own subsection, and a
// name is emitted only where the SOURCE wrote one: a synthetic name -- the
// `<string>` array, a generated block label -- exists so the checker has
// something to resolve, and putting it in the output would name a thing the
// author never named.

///|
/// Whether a name was generated rather than written.
///
/// Synthetic names are spelled with a leading `<`, which the grammar cannot
/// produce -- that is why the spelling was chosen.
pub fn is_synthetic(name : String) -> Bool {
  name.has_prefix("<")
}

///|
/// Record a name for an index, unless it was generated.
pub fn note_name(into : Map[Int, Bytes], index : Int, name : String) -> Unit {
  if !is_synthetic(name) {
    into[index] = utf8_of(name)
  }
}

///|
/// The names of every TYPE, and of every struct field.
///
/// Read off the checker's own table, which is where a source name and the index
/// it interned to are joined. A type that several names reach keeps the first,
/// because that is the one the reference emits.
pub fn Lowering::type_names(self : Lowering, m : @wasm_bin.Module) -> Unit {
  // A NAME names its own emitted entry, not the store entry it shares with a
  // like-shaped sibling -- which is the whole reason the two indices are
  // different numbers. `by_name` holds exactly the names that reached the
  // section: the declarations, and the synthesized types something referred to.
  // A synthesized name is emitted precisely because it was materialised: the
  // entry exists only for it, so nothing else can carry the name.
  for name, i in self.layout.by_name {
    if !m.names.types.contains(i) {
      m.names.types[i] = utf8_of(name)
    }
  }
  for entry in self.ctx.type_context.types.iter_entries() {
    let (name, (idx, sub)) = entry
    guard idx is Def(id) else { continue }
    let i = match self.layout.by_name.get(name) {
      Some(emitted) => emitted
      None => emitted_type_index(id.to_int_for_tests_only())
    }
    // A struct's fields are named per TYPE, so they hang off the same index.
    if sub.typ is Struct(fields) && !m.names.fields.contains(i) {
      let per_field : Map[Int, Bytes] = Map([])
      for k, f in fields {
        note_name(per_field, k, f.desc.0.name)
      }
      if !per_field.is_empty() {
        m.names.fields[i] = per_field
      }
    }
  }
}

///|
/// The module's own name, if it declared one.
pub fn Lowering::module_name(
  self : Lowering,
  m : @wasm_bin.Module,
  fields : @ast.Module[@basic.Location],
) -> Unit {
  ignore(self)
  for field in fields {
    guard field.desc is ModuleAnnotation(attrs) else { continue }
    for a in attrs {
      if a.attr_name == "module" &&
        a.attr_value is Some(v) &&
        v.desc is Str(_, b) {
        m.names.module_ = Some(b)
      }
    }
  }
}

///|
/// The `target_features` custom section: one `+name` entry per declared
/// feature.
///
/// A `#![feature = "..."]` is a fact about the module that the binary format
/// has no other place for, so it survives as tool-conventions metadata. `+`
/// means "used"; the reference emits nothing else, and a repeated declaration
/// is idempotent rather than duplicated.
pub fn Lowering::target_features(
  self : Lowering,
  m : @wasm_bin.Module,
  fields : @ast.Module[@basic.Location],
) -> Unit {
  ignore(self)
  for field in fields {
    guard field.desc is ModuleAnnotation(attrs) else { continue }
    for a in attrs {
      guard a.attr_name == "feature" else { continue }
      guard a.attr_value is Some(v) else { continue }
      guard v.desc is Str(_, name) else { continue }
      let entry = (43, name)
      if !m.target_features.contains(entry) {
        m.target_features.push(entry)
      }
    }
  }
}

///|
/// The optimization level `#[run_once]` names.
pub let run_once_level : Int = 127

///|
/// A function's compilation priority, if it declared one.
///
/// `#[priority]` orders compilation and `#[optimization]` sets the effort; the
/// second is meaningless without the first, which is why they are one record
/// rather than two.
pub fn function_priority(
  attributes : Array[@ast.Attribute],
) -> @wasm_bin.Priority? {
  let mut compilation : Int? = None
  let mut optimization : Int? = None
  for a in attributes {
    // `#[run_once]` carries no value: it is the spelling of one particular
    // optimization level, the highest, and the section stores it as that
    // number rather than as a flag of its own.
    if a.attr_name == "run_once" {
      optimization = Some(run_once_level)
      continue
    }
    guard a.attr_value is Some(v) else { continue }
    guard v.desc is Int(s) else { continue }
    let n = @string.parse_int(s.split("_").join("")) catch { _ => continue }
    match a.attr_name {
      "priority" => compilation = Some(n)
      "optimization" => optimization = Some(n)
      _ => ()
    }
  }
  compilation.map(c => ({ compilation: c, optimization } : @wasm_bin.Priority))
}
